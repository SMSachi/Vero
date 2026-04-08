//
//  HomeViewModel.swift
//  Insio Health
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

    // MARK: - Analytics Properties (computed from local data)

    /// Number of workouts this week from persistence
    var workoutsThisWeek: Int {
        persistenceService.countWorkoutsThisWeek()
    }

    /// Current workout streak from persistence
    var currentStreak: Int {
        persistenceService.calculateCurrentStreak()
    }

    /// Weekly weight change (for weight loss tracking)
    var weeklyWeightDelta: Double? {
        persistenceService.calculateWeeklyWeightDelta()
    }

    /// Set of weekday indices (0=Mon…6=Sun) that had at least one workout this calendar week.
    /// Used by WeeklyTracker to show actual workout days instead of a sequential fill.
    var workoutDaysThisWeek: Set<Int> {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) else { return [] }
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        let workouts = persistenceService.fetchWorkouts(from: startOfWeek, to: endOfWeek)
        return Set(workouts.map { workout in
            let weekday = calendar.component(.weekday, from: workout.startDate)
            return (weekday + 5) % 7  // 0=Mon, 1=Tue … 6=Sun
        })
    }

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
        // CRITICAL: Don't do ANY work in init - it blocks the main thread
        // and prevents SwiftUI views from appearing (onAppear never fires)
        print("🏠 HomeViewModel: init() - subscribing to DataBroadcaster")

        // Subscribe to home-relevant data changes
        DataBroadcaster.shared.homeDataChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                print("🏠 HomeViewModel: RECEIVED broadcast - \(event.type.rawValue)")
                self?.refreshAnalytics()
            }
            .store(in: &cancellables)
    }

    // MARK: - Cached Data Loading

    /// Load data from local persistence (for immediate display before HealthKit fetch)
    private func loadCachedData() {
        print("💾 ════════════════════════════════════════════════════")
        print("💾 HOME REFRESH START")
        print("💾 ════════════════════════════════════════════════════")
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
            let waterLiters = Double(waterMl) / 1000.0
            let previousWater = self.waterIntake
            self.waterIntake = waterLiters

            print("💾 VALUE LOADED into Home card: HYDRATION")
            print("💾   Previous: \(String(format: "%.2f", previousWater))L")
            print("💾   New: \(String(format: "%.2f", waterLiters))L (\(waterMl)ml from persistence)")

            // Log sleep if available
            if cachedContext.sleepHours > 0 {
                print("💾 VALUE LOADED into Home card: SLEEP = \(String(format: "%.1f", cachedContext.sleepHours))h")
            }

            // Log weight if available
            if let weightKg = cachedContext.weightKg, weightKg > 0 {
                print("💾 VALUE LOADED into Home card: WEIGHT = \(String(format: "%.1f", weightKg))kg")
            }
        } else {
            // No context - reset values
            self.dailyContext = nil
            self.waterIntake = 0
            print("💾 No daily context found - values reset to 0")
        }

        // Load cached recovery
        if let cachedRecovery = persistenceService.fetchTodayRecovery() {
            self.recovery = cachedRecovery
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("💾 ════════════════════════════════════════════════════")
        print("💾 HOME REFRESH COMPLETE")
        print("💾 Duration: \(String(format: "%.1f", elapsed))ms")
        print("💾 Water: \(String(format: "%.2f", waterIntake))L")
        print("💾 Sleep: \(String(format: "%.1f", dailyContext?.sleepHours ?? 0))h")
        print("💾 Weight: \(dailyContext?.weightKg.map { String(format: "%.1f", $0) + "kg" } ?? "—")")
        print("💾 ════════════════════════════════════════════════════")
    }

    // MARK: - Data Loading

    /// Load all health data from HealthKit.
    /// Falls back to cached data when HealthKit is unavailable.
    /// Shows empty states when no data exists.
    func loadData() async {
        print("🏠 HomeViewModel: ══════════════════════════════════════════════════")
        print("🏠 HomeViewModel: LOAD DATA STARTED")
        print("🏠 HomeViewModel: ══════════════════════════════════════════════════")

        isLoading = true
        errorMessage = nil

        // First, load cached data immediately (local-first)
        print("🏠 HomeViewModel: Loading cached data first...")
        loadCachedData()
        print("🏠 HomeViewModel: Cached data loaded - hasRealData: \(hasRealData)")

        // Check HealthKit availability
        print("🏠 HomeViewModel: Checking HealthKit status...")
        print("🏠 HomeViewModel: isSimulator: \(HealthKitService.isSimulator)")
        print("🏠 HomeViewModel: isHealthKitAvailable: \(healthKitService.isHealthKitAvailable)")

        // On simulator or when HealthKit unavailable, skip HealthKit entirely
        if HealthKitService.isSimulator {
            print("🏠 HomeViewModel: ⚠️ SIMULATOR - skipping HealthKit, using cached/empty data")
            if hasRealData {
                generateInterpretation()
            }
            isLoading = false
            print("🏠 HomeViewModel: ══════════════════════════════════════════════════")
            return
        }

        // Check authorization status
        healthKitService.checkAuthorizationStatus()
        print("🏠 HomeViewModel: Authorization status: \(healthKitService.authorizationStatus.rawValue)")
        print("🏠 HomeViewModel: Has verified read access: \(healthKitService.hasVerifiedReadAccess)")

        guard healthKitService.authorizationStatus == .authorized else {
            print("🏠 HomeViewModel: ⚠️ HealthKit not authorized - using cached data only")
            // Not authorized - rely on cached data only
            if hasRealData {
                generateInterpretation()
            }
            isLoading = false
            print("🏠 HomeViewModel: ══════════════════════════════════════════════════")
            return
        }

        print("🏠 HomeViewModel: ✅ HealthKit authorized - fetching data from HealthKit...")

        // Fetch all data concurrently from HealthKit
        async let workoutTask = fetchLatestWorkout()
        async let recentWorkoutsTask = fetchRecentWorkouts()
        async let contextTask = fetchDailyContext()
        async let waterTask = fetchWaterIntake()

        // Wait for all tasks
        let (workout, recent, context, water) = await (workoutTask, recentWorkoutsTask, contextTask, waterTask)

        print("🏠 HomeViewModel: ──────────────────────────────────────────────────")
        print("🏠 HomeViewModel: FETCH RESULTS:")
        print("🏠 HomeViewModel: Latest workout: \(workout != nil ? "✅ Found" : "❌ None")")
        print("🏠 HomeViewModel: Recent workouts: \(recent.count) found")
        print("🏠 HomeViewModel: Daily context: \(context != nil ? "✅ Found" : "❌ None")")
        print("🏠 HomeViewModel: Water intake: \(water.map { String(format: "%.1fL", $0) } ?? "None")")
        print("🏠 HomeViewModel: ──────────────────────────────────────────────────")

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

        // Calculate recovery based on available data
        if let context = dailyContext {
            let calculatedRecovery = calculateRecovery(from: context)
            self.recovery = calculatedRecovery

            if let workout = latestWorkout {
                persistenceService.saveNextDayRecovery(calculatedRecovery, for: workout.id)
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

        isLoading = false
        print("🏠 HomeViewModel: ══════════════════════════════════════════════════")
        print("🏠 HomeViewModel: LOAD DATA COMPLETE")
        print("🏠 HomeViewModel: hasRealData: \(hasRealData)")
        print("🏠 HomeViewModel: showEmptyState: \(showEmptyState)")
        print("🏠 HomeViewModel: ══════════════════════════════════════════════════")
    }

    /// Refresh analytics after a workout is added.
    /// Call this from WorkoutsListView after AddWorkoutView saves.
    /// Also called by DataBroadcaster when any metric is logged.
    func refreshAnalytics() {
        print("🔄 ════════════════════════════════════════════════════")
        print("🔄 HOME: REFRESH TRIGGERED (broadcast received)")
        print("🔄 ════════════════════════════════════════════════════")

        // Reload from persistence - this updates all @Published properties
        loadCachedData()

        // Regenerate interpretation if we have a workout
        if hasRealData {
            generateInterpretation()
        }

        // Force UI update by publishing change (belt and suspenders)
        objectWillChange.send()

        print("🔄 ════════════════════════════════════════════════════")
        print("🔄 HOME: REFRESH DONE")
        print("🔄 ════════════════════════════════════════════════════")
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
            sleepHours: sleep?.hours ?? 7.0,
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
            return hrv ?? 0 > 50 ? .peak : .high
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
    ) -> Int {
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

    private func calculateRecovery(from context: DailyContext) -> NextDayRecovery {
        let score = context.readinessScore

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
