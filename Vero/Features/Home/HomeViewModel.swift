//
//  HomeViewModel.swift
//  WellPattern Health
//
//  ViewModel for the Home screen that manages HealthKit data fetching,
//  interpretation generation, and persistence.
//
//  DATA FLOW:
//  1. On appear, ViewModel loads cached data from PersistenceService
//  2. Then checks HealthKit authorization status
//  3. If authorized, fetches fresh data from HealthKit
//  4. Saves fetched data to PersistenceService for offline access
//  5. InterpretationEngine generates insights (considers check-in data if available)
//  6. Interpretation is saved to persistence with the workout
//  7. UI shows empty states when no real data is available
//
//  ANALYTICS REFRESH:
//  - Call refreshAnalytics() after adding manual workouts to update dashboard
//  - All analytics computed from local persisted data (local-first)
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The latest workout to display (nil if no workouts exist)
    @Published private(set) var latestWorkout: Workout?

    /// Today's daily context (nil if no context data)
    @Published private(set) var dailyContext: DailyContext?

    /// Today's water intake in liters
    @Published private(set) var waterIntake: Double = 0

    /// Today's recovery data (nil if not computed)
    @Published private(set) var recovery: NextDayRecovery?

    /// Generated interpretation for the latest workout
    @Published private(set) var workoutInterpretation: WorkoutInterpretation?

    /// Recent workouts for pattern analysis
    @Published private(set) var recentWorkouts: [Workout] = []

    /// Whether data is currently being loaded
    @Published private(set) var isLoading = false

    /// Whether we have any real data (used for empty state detection)
    @Published private(set) var hasRealData = false

    /// Error message if something went wrong
    @Published private(set) var errorMessage: String?

    // MARK: - Empty State Detection

    /// Whether to show empty state (no workouts exist)
    var showEmptyState: Bool {
        !hasRealData && !isLoading
    }

    /// Whether to show the workout hero card
    var showWorkoutAsHero: Bool {
        guard let workout = latestWorkout else { return false }
        let hoursSinceWorkout = -workout.endDate.timeIntervalSinceNow / 3600
        return hoursSinceWorkout < 18
    }

    // MARK: - Analytics Properties (@Published — updated only on explicit refresh, never queried in body)

    /// Number of workouts this calendar week (Mon 00:00 → now).
    @Published private(set) var workoutsThisWeek: Int = 0

    /// Current workout streak from persistence.
    @Published private(set) var currentStreak: Int = 0

    /// Weekly weight change (for weight loss tracking).
    @Published private(set) var weeklyWeightDelta: Double? = nil

    /// Set of weekday indices (0=Mon…6=Sun) that had at least one workout this calendar week.
    /// Used by WeeklyTracker to show actual workout days instead of a sequential fill.
    @Published private(set) var workoutDaysThisWeek: Set<Int> = []

    /// AI-generated daily tip for Plus/Pro users. nil for free tier or when AI is unavailable.
    @Published private(set) var dailyGuidance: String? = nil

    /// Whether a post-workout check-in has been completed for the latest workout
    var hasCompletedCheckIn: Bool {
        guard let workout = latestWorkout else { return false }
        return persistenceService.hasCheckedIn(for: workout.id)
    }

    // MARK: - Services

    private let healthKitService = HealthKitService.shared
    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Subscribe to home-relevant data changes.
        // Debounced: rapid saves (e.g. multiple fields in one daily context) coalesce into one refresh.
        DataBroadcaster.shared.homeDataChanged
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAnalytics()
            }
            .store(in: &cancellables)
    }

    // MARK: - Cached Data Loading

    /// Load data from local persistence (for immediate display before HealthKit fetch)
    private func loadCachedData() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Load recent workouts first
        let cachedRecent = persistenceService.fetchRecentWorkouts(limit: 10)
        if !cachedRecent.isEmpty {
            self.recentWorkouts = cachedRecent
            self.hasRealData = true
        }

        // Get latest workout
        if let cachedWorkout = persistenceService.fetchLatestWorkout() {
            self.latestWorkout = cachedWorkout
            self.hasRealData = true

            // Load stored interpretation
            if let storedInterpretation = persistenceService.getStoredInterpretation(for: cachedWorkout.id) {
                self.workoutInterpretation = storedInterpretation
            }
        }

        // Load cached daily context - ALWAYS update values (even to 0/nil)
        if let cachedContext = persistenceService.fetchTodayDailyContext() {
            self.dailyContext = cachedContext

            // ALWAYS update water intake from context (including 0)
            let waterMl = cachedContext.waterIntakeMl ?? 0
            self.waterIntake = Double(waterMl) / 1000.0
        } else {
            self.dailyContext = nil
            self.waterIntake = 0
        }

        // Load cached recovery. If none exists but we have a context (e.g. from a
        // manual daily log), compute recovery now so the card shows real data.
        if let cachedRecovery = persistenceService.fetchTodayRecovery() {
            self.recovery = cachedRecovery
        } else if let context = self.dailyContext, let calculatedRecovery = calculateRecovery(from: context) {
            self.recovery = calculatedRecovery
            _ = persistenceService.saveNextDayRecovery(calculatedRecovery, for: nil)
        }

        // Refresh analytics @Published properties (SwiftData queries done once here, not per-render)
        self.workoutsThisWeek = MetricsEngine.shared.workoutCountThisCalendarWeek()
        self.currentStreak = MetricsEngine.shared.currentStreak()
        self.weeklyWeightDelta = MetricsEngine.shared.weeklyWeightDeltaKg()
        self.workoutDaysThisWeek = MetricsEngine.shared.workoutDaysThisCalendarWeek()

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        #if DEBUG
        print("💾 HOME CACHED LOAD: \(String(format: "%.1f", elapsed))ms | water=\(String(format: "%.2f", waterIntake))L workouts=\(workoutsThisWeek)")
        #endif
    }

    // MARK: - Data Loading

    /// Load all health data from HealthKit.
    /// Falls back to cached data when HealthKit is unavailable.
    /// Shows empty states when no data exists.
    func loadData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        #if DEBUG
        let _loadStart = CFAbsoluteTimeGetCurrent()
        print("🏠 [HOME] loadData() BEGIN — cached first, then HealthKit")
        #endif

        // First, load cached data immediately (local-first)
        loadCachedData()

        // On simulator or when HealthKit unavailable, skip HealthKit entirely
        if HealthKitService.isSimulator {
            if hasRealData { generateInterpretation() }
            isLoading = false
            return
        }

        // Check authorization status
        healthKitService.checkAuthorizationStatus()

        guard healthKitService.authorizationStatus == .authorized else {
            #if DEBUG
            print("🏠 [HOME] loadData() — HealthKit not authorized (\(healthKitService.authorizationStatus.rawValue)), showing cached data")
            #endif
            if hasRealData { generateInterpretation() }
            isLoading = false
            return
        }

        #if DEBUG
        print("🏠 [HOME] loadData() — HealthKit authorized, starting concurrent fetch")
        let _hkStart = CFAbsoluteTimeGetCurrent()
        #endif

        // Fetch all data concurrently from HealthKit
        async let workoutTask = fetchLatestWorkout()
        async let recentWorkoutsTask = fetchRecentWorkouts()
        async let contextTask = fetchDailyContext()
        async let waterTask = fetchWaterIntake()

        let (workout, recent, context, water) = await (workoutTask, recentWorkoutsTask, contextTask, waterTask)
        #if DEBUG
        let _hkElapsed = (CFAbsoluteTimeGetCurrent() - _hkStart) * 1000
        print("🏠 [HOME] HealthKit concurrent fetch done: \(String(format: "%.0f", _hkElapsed)) ms | workout=\(workout != nil) recent=\(recent.count) context=\(context != nil) water=\(water != nil)")
        print("🏥 HK→HOME: ══════════ DATA LANDED IN APP STATE ══════════════")
        print("🏥 HK→HOME: latestWorkout   = \(workout.map { "\($0.type.rawValue) \(Int($0.duration / 60)) min" } ?? "nil")")
        print("🏥 HK→HOME: recentWorkouts  = \(recent.count) workouts")
        print("🏥 HK→HOME: sleep.hours     = \(context.map { String(format: "%.2f h", $0.sleepHours) } ?? "nil (no sleep data)")")
        print("🏥 HK→HOME: hrv             = \(context?.hrvScore.map { String(format: "%.1f ms", $0) } ?? "nil")")
        print("🏥 HK→HOME: restingHR       = \(context?.restingHeartRate.map { "\($0) bpm" } ?? "nil")")
        print("🏥 HK→HOME: water           = \(water.map { String(format: "%.3f L", $0) } ?? "nil (none today)")")
        print("🏥 HK→HOME: readiness       = \(context.map { $0.readinessScore.map { "\($0)/100" } ?? "nil (no data)" } ?? "nil")")
        print("🏥 HK→HOME: ════════════════════════════════════════════════════")
        #endif

        // Update published properties and persist to local storage
        if let workout = workout {
            // Mark HealthKit workouts with proper source
            var workoutWithSource = workout
            workoutWithSource.source = .healthKit

            self.latestWorkout = workoutWithSource
            self.hasRealData = true

            // Save workout to persistence
            persistenceService.saveWorkout(workoutWithSource)

            // Sync to cloud (non-blocking with timeout)
            Task.detached(priority: .utility) { [syncService] in
                await syncService.syncWorkoutWithTimeout(workoutWithSource, timeout: 15)
            }
        }

        // Store recent workouts for pattern analysis and persist
        if !recent.isEmpty {
            self.recentWorkouts = recent
            self.hasRealData = true

            for var recentWorkout in recent {
                recentWorkout.source = .healthKit
                persistenceService.saveWorkout(recentWorkout)
                // Sync each in background with timeout
                let workout = recentWorkout
                Task.detached(priority: .utility) { [syncService] in
                    await syncService.syncWorkoutWithTimeout(workout, timeout: 15)
                }
            }
        }

        if let context = context {
            self.dailyContext = context
            persistenceService.saveDailyContext(context)
            // Sync context in background with timeout
            Task.detached(priority: .utility) { [syncService] in
                await syncService.syncDailyContextWithTimeout(context, timeout: 10)
            }
        }

        if let water = water {
            self.waterIntake = water
        }

        // Calculate recovery based on available data (nil when readiness is unavailable).
        // Only persist a new recovery if the workout doesn't already have one linked —
        // saves once per workout per day, not on every loadData() call.
        if let context = dailyContext, let calculatedRecovery = calculateRecovery(from: context) {
            self.recovery = calculatedRecovery

            if let workout = latestWorkout {
                let alreadyLinked = persistenceService.fetchPersistedWorkout(id: workout.id)?.nextDayRecovery != nil
                #if DEBUG
                print("📈 [RECOVERY] workout.nextDayRecovery alreadyLinked=\(alreadyLinked)")
                #endif
                if !alreadyLinked {
                    persistenceService.saveNextDayRecovery(calculatedRecovery, for: workout.id)
                }
            }
        }

        // Generate interpretation
        if hasRealData {
            generateInterpretation()

            if let workout = latestWorkout, let interpretation = workoutInterpretation {
                persistenceService.saveWorkoutInterpretation(
                    workoutId: workout.id,
                    interpretation: interpretation
                )
            }
        }

        // Generate Plus daily guidance (non-blocking — updates UI when done)
        if let ctx = dailyContext {
            Task { [weak self] in
                let tip = await OpenRouterService.shared.generateDailyGuidance(context: ctx)
                await MainActor.run { self?.dailyGuidance = tip }
            }
        }

        #if DEBUG
        MetricsEngine.shared.auditLog(screen: "Dashboard")
        Task { await HealthKitService.shared.printDiagnosticSummary() }
        let _loadElapsed = (CFAbsoluteTimeGetCurrent() - _loadStart) * 1000
        print("🏠 [HOME] loadData() COMPLETE: \(String(format: "%.0f", _loadElapsed)) ms total")
        #endif
        isLoading = false
    }

    /// Refresh analytics after a workout is added.
    /// Call this from WorkoutsListView after AddWorkoutView saves.
    /// Also called by DataBroadcaster when any metric is logged.
    func refreshAnalytics() {
        #if DEBUG
        print("🏠 [TRACE 2b] refreshAnalytics() called — caller: DataBroadcaster debounce or manual onSave")
        #endif
        loadCachedData()
        if hasRealData {
            generateInterpretation()
        }
        #if DEBUG
        print("🏠 [TRACE 2b] refreshAnalytics() done")
        #endif
    }

    /// Generate workout interpretation using the InterpretationEngine.
    private func generateInterpretation() {
        guard let workout = latestWorkout else { return }

        // Filter out the current workout from previous workouts
        let previousWorkouts = recentWorkouts.filter { $0.id != workout.id }

        // Fetch check-in data for this workout from persistence
        let checkInInput = fetchCheckInData(for: workout.id)

        // Generate interpretation using rule-based engine
        self.workoutInterpretation = InterpretationEngine.interpret(
            workout: workout,
            context: dailyContext,
            previousWorkouts: previousWorkouts,
            checkIn: checkInInput
        )
    }

    /// Fetch check-in data from persistence for a workout
    private func fetchCheckInData(for workoutId: UUID) -> CheckInInput? {
        let postCheckIn = persistenceService.fetchPostWorkoutCheckIn(for: workoutId)
        let persistedWorkout = persistenceService.fetchPersistedWorkout(id: workoutId)
        let nextDayFeeling = persistedWorkout?.nextDayRecovery?.bodyFeeling

        if postCheckIn != nil || nextDayFeeling != nil {
            return CheckInInput(
                postWorkoutFeeling: postCheckIn?.feeling,
                postWorkoutNote: postCheckIn?.note,
                nextDayFeeling: nextDayFeeling
            )
        }

        return nil
    }

    /// Refresh data (pull-to-refresh or manual refresh)
    func refresh() async {
        await loadData()
    }

    // MARK: - Individual Data Fetchers

    private func fetchLatestWorkout() async -> Workout? {
        return await healthKitService.fetchAndMapMostRecentWorkout()
    }

    private func fetchRecentWorkouts() async -> [Workout] {
        return await healthKitService.fetchAndMapRecentWorkouts(limit: 10)
    }

    private func fetchDailyContext() async -> DailyContext? {
        async let sleepTask = healthKitService.fetchLastNightSleep()
        async let hrvTask = healthKitService.fetchHRV()
        async let restingHRTask = healthKitService.fetchRestingHeartRate()

        let (sleep, hrv, restingHR) = await (sleepTask, hrvTask, restingHRTask)

        // If we have no data at all, return nil (no fake data)
        if sleep == nil && hrv == nil && restingHR == nil {
            return nil
        }

        let energyLevel = calculateEnergyLevel(sleepHours: sleep?.hours, hrv: hrv)
        let stressLevel = calculateStressLevel(hrv: hrv)
        let readinessScore = calculateReadinessScore(
            sleepHours: sleep?.hours,
            sleepQuality: sleep?.quality,
            hrv: hrv,
            restingHR: restingHR
        )

        return DailyContext(
            id: UUID(),
            date: Date(),
            sleepHours: sleep?.hours ?? 0.0,
            sleepQuality: sleep?.quality ?? .fair,
            stressLevel: stressLevel,
            energyLevel: energyLevel,
            restingHeartRate: restingHR,
            hrvScore: hrv,
            readinessScore: readinessScore
        )
    }

    private func fetchWaterIntake() async -> Double? {
        return await healthKitService.fetchTodayWaterIntake()
    }

    // MARK: - Calculations

    private func calculateEnergyLevel(sleepHours: Double?, hrv: Double?) -> EnergyLevel {
        guard let sleep = sleepHours else { return .moderate }

        switch sleep {
        case 8...:
            return hrv != nil && hrv! > 50 ? .peak : .high
        case 7..<8:
            return .high
        case 6..<7:
            return .moderate
        case 5..<6:
            return .low
        default:
            return .depleted
        }
    }

    private func calculateStressLevel(hrv: Double?) -> StressLevel {
        guard let hrv = hrv else { return .moderate }

        switch hrv {
        case 60...:
            return .low
        case 40..<60:
            return .moderate
        case 25..<40:
            return .high
        default:
            return .veryHigh
        }
    }

    private func calculateReadinessScore(
        sleepHours: Double?,
        sleepQuality: SleepQuality?,
        hrv: Double?,
        restingHR: Int?
    ) -> Int? {
        // Require at least one real metric; never fabricate a score from nothing.
        guard sleepHours != nil || hrv != nil else { return nil }

        var score = 70

        if let sleep = sleepHours {
            switch sleep {
            case 8...: score += 15
            case 7..<8: score += 10
            case 6..<7: score += 0
            case 5..<6: score -= 10
            default: score -= 20
            }
        }

        if let hrv = hrv {
            switch hrv {
            case 60...: score += 10
            case 45..<60: score += 5
            case 30..<45: score += 0
            default: score -= 10
            }
        }

        return max(0, min(100, score))
    }

    private func calculateRecovery(from context: DailyContext) -> NextDayRecovery? {
        guard let score = context.readinessScore else { return nil }

        let muscleRecovery: RecoveryStatus
        let cardioRecovery: RecoveryStatus
        let mentalRecovery: RecoveryStatus

        switch score {
        case 80...:
            muscleRecovery = .optimal
            cardioRecovery = .optimal
            mentalRecovery = .ready
        case 65..<80:
            muscleRecovery = .ready
            cardioRecovery = .ready
            mentalRecovery = .ready
        case 50..<65:
            muscleRecovery = .recovering
            cardioRecovery = .recovering
            mentalRecovery = .partial
        default:
            muscleRecovery = .recovering
            cardioRecovery = .recovering
            mentalRecovery = .recovering
        }

        let recommendation: RecoveryRecommendation
        let suggestedTypes: [WorkoutType]
        let interpretation: String

        switch score {
        case 85...:
            recommendation = .pushHard
            suggestedTypes = [.hiit, .run, .strength]
            interpretation = "Your body is fully recovered. This is a great day to push hard if you're motivated."
        case 70..<85:
            recommendation = .moderateTraining
            suggestedTypes = [.run, .cycle, .strength]
            interpretation = "Good recovery. You can train at moderate intensity today."
        case 55..<70:
            recommendation = .lightActivity
            suggestedTypes = [.walk, .yoga]
            interpretation = "Consider lighter activity today. Your body is still recovering."
        default:
            recommendation = .rest
            suggestedTypes = [.yoga]
            interpretation = "Rest is recommended. Focus on sleep, hydration, and nutrition."
        }

        return NextDayRecovery(
            id: UUID(),
            date: Date(),
            overallScore: score,
            muscleRecovery: muscleRecovery,
            cardioRecovery: cardioRecovery,
            mentalRecovery: mentalRecovery,
            recommendation: recommendation,
            suggestedWorkoutTypes: suggestedTypes,
            interpretation: interpretation
        )
    }
}
