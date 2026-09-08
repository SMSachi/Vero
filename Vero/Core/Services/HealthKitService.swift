//
//  HealthKitService.swift
//  WellPattern Health
//
//  HealthKit integration service for reading workout and health data.
//  This service handles all HealthKit authorization and data fetching.
//
//  ARCHITECTURE:
//  - HealthKitService is a singleton that manages all HealthKit interactions
//  - All fetch methods are async and return optionals (nil if unavailable)
//  - The service gracefully handles missing permissions or data
//  - Mock data fallback is handled at the ViewModel level, not here
//
//  IMPORTANT: HealthKit READ Authorization
//  - HealthKit does NOT provide a way to check READ authorization status directly
//  - authorizationStatus(for:) only checks WRITE authorization
//  - To determine READ access, we must attempt to fetch data
//  - After requestAuthorization(), we verify by attempting a data fetch
//

import Foundation
import HealthKit

// MARK: - HealthKit Service

/// Singleton service for all HealthKit interactions.
/// Handles authorization, data fetching, and model mapping.
@MainActor
final class HealthKitService: ObservableObject {

    // MARK: - Singleton

    static let shared = HealthKitService()

    // MARK: - Properties

    /// The HealthKit store - nil if HealthKit is not available on this device
    private let healthStore: HKHealthStore?

    /// Published authorization status for UI updates
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    /// Whether we have verified read access by successfully fetching data
    @Published private(set) var hasVerifiedReadAccess = false

    /// Last error message for debugging
    @Published private(set) var lastError: String?

    /// Whether HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether running on simulator (static for safe access during init)
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Instance convenience accessor
    var isSimulator: Bool {
        Self.isSimulator
    }

    // MARK: - Authorization Status

    enum AuthorizationStatus: String {
        case notDetermined = "Not Determined"
        case authorized = "Authorized"
        case denied = "Denied"
        case unavailable = "Unavailable"
    }

    // MARK: - Explicit Connection State (for UI)

    /// Explicit connection state that distinguishes between data availability
    enum ConnectionState: String {
        case notConnected = "Not Connected"
        case denied = "Access Denied"
        case connectedNoData = "Connected - No Data"
        case connectedWithData = "Connected"
        case unavailable = "Unavailable"

        var displayText: String { rawValue }

        var icon: String {
            switch self {
            case .notConnected: return "questionmark.circle"
            case .denied: return "xmark.circle.fill"
            case .connectedNoData: return "checkmark.circle"
            case .connectedWithData: return "checkmark.circle.fill"
            case .unavailable: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .notConnected: return "textTertiary"
            case .denied: return "coral"
            case .connectedNoData: return "orange"
            case .connectedWithData: return "olive"
            case .unavailable: return "textTertiary"
            }
        }

        var isConnected: Bool {
            self == .connectedNoData || self == .connectedWithData
        }
    }

    /// Explicit connection state computed from authorization + data availability
    var connectionState: ConnectionState {
        switch authorizationStatus {
        case .notDetermined:
            return .notConnected
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        case .authorized:
            return hasWorkoutData ? .connectedWithData : .connectedNoData
        }
    }

    /// Whether we have found any workout data in HealthKit
    @Published private(set) var hasWorkoutData = false

    // MARK: - HealthKit Types

    /// All the HealthKit types we request READ authorization for.
    /// Each type is documented with its purpose in the app.
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // WORKOUTS
        // Used to: Display workout history, analyze workout patterns, show recent activity
        types.insert(HKObjectType.workoutType())

        // HEART RATE
        // Used to: Show heart rate during workouts, calculate recovery metrics
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }

        // RESTING HEART RATE
        // Used to: Calculate readiness score, track cardiovascular fitness trends
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }

        // HEART RATE VARIABILITY (SDNN)
        // Used to: Assess recovery status, calculate readiness score, detect overtraining
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }

        // SLEEP ANALYSIS
        // Used to: Display sleep duration, assess recovery, personalize recommendations
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        // ACTIVE ENERGY BURNED
        // Used to: Show calories burned in workouts, calculate total daily energy expenditure
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // DISTANCE WALKING/RUNNING
        // Used to: Show distance for outdoor workouts (runs, walks)
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }

        // DIETARY WATER
        // Used to: Track daily hydration, display water intake on home screen
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(water)
        }

        // DIETARY ENERGY CONSUMED
        // Used to: Track calorie intake, show nutrition summary
        if let calories = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(calories)
        }

        // DIETARY CARBOHYDRATES
        // Used to: Display macro breakdown, nutrition insights
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbs)
        }

        // DIETARY PROTEIN
        // Used to: Display macro breakdown, nutrition insights
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(protein)
        }

        // MENSTRUAL FLOW
        // Used to: Auto-detect menstrual phase for cycle tracking (optional feature)
        if let menstrual = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) {
            types.insert(menstrual)
        }

        return types
    }

    // MARK: - Initialization

    private init() {
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🏥 HealthKit: SERVICE INITIALIZING")
        #endif
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🏥 HealthKit: isHealthDataAvailable = \(HKHealthStore.isHealthDataAvailable())")
        #endif
        #if DEBUG
        print("🏥 HealthKit: isSimulator = \(Self.isSimulator)")
        #endif

        // IMPORTANT: On simulator, treat HealthKit as unavailable even though
        // isHealthDataAvailable() returns true on iOS 17+. The simulator's
        // HealthKit database is non-functional and queries will hang indefinitely.
        if Self.isSimulator {
            #if DEBUG
            print("🏥 HealthKit: ⚠️ SIMULATOR DETECTED - marking HealthKit as unavailable")
            #endif
            #if DEBUG
            print("🏥 HealthKit: ⚠️ This prevents hangs from non-functional HealthKit queries")
            #endif
            self.healthStore = nil
            self.authorizationStatus = .unavailable
        } else if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
            #if DEBUG
            print("🏥 HealthKit: ✅ HKHealthStore created successfully")
            #endif
            // Restore authorization state across restarts using UserDefaults.
            // HealthKit's authorizationStatus(for:) always returns .notDetermined for READ-only
            // types (we never request WRITE), so we persist the flag ourselves.
            if UserDefaults.standard.bool(forKey: "wp.hk.hasVerifiedReadAccess") {
                self.hasVerifiedReadAccess = true
                self.authorizationStatus = .authorized
            }
        } else {
            self.healthStore = nil
            self.authorizationStatus = .unavailable
            #if DEBUG
            print("🏥 HealthKit: ❌ HealthKit unavailable on this device")
            #endif
        }
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
    }

    // MARK: - Authorization

    /// Request HealthKit authorization for all required data types.
    /// This presents the system HealthKit authorization sheet to the user.
    ///
    /// - Returns: True if authorization was granted (at least partially), false otherwise
    func requestAuthorization() async -> Bool {
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🏥 HealthKit: AUTHORIZATION REQUEST")
        #endif
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif

        guard let healthStore = healthStore else {
            #if DEBUG
            print("🏥 HealthKit: ❌ ABORT - HealthStore is nil (unavailable)")
            #endif
            authorizationStatus = .unavailable
            lastError = "HealthKit is not available on this device"
            return false
        }

        #if DEBUG
        print("🏥 HealthKit: Requesting authorization for \(readTypes.count) data types...")
        #endif
        #if DEBUG
        print("🏥 HealthKit: Types: \(readTypes.map { $0.identifier.components(separatedBy: ".").last ?? $0.identifier })")
        #endif

        do {
            // Request authorization - we only need READ access, no WRITE access
            // The empty set for toShare means we won't write any data
            #if DEBUG
            print("🏥 HealthKit: 🚀 Calling healthStore.requestAuthorization()...")
            #endif

            try await healthStore.requestAuthorization(toShare: [], read: readTypes)

            #if DEBUG
            print("🏥 HealthKit: ✅ Authorization request completed (no error thrown)")
            #endif

            // IMPORTANT: HealthKit requestAuthorization completes successfully even if user denies
            // We need to verify READ access by attempting to fetch data
            #if DEBUG
            print("🏥 HealthKit: 🔍 Verifying READ access by attempting data fetch...")
            #endif

            let hasAccess = await verifyReadAccess()

            if hasAccess {
                #if DEBUG
                print("🏥 HealthKit: ✅ READ access VERIFIED - data fetch succeeded")
                #endif
                authorizationStatus = .authorized
                hasVerifiedReadAccess = true
                UserDefaults.standard.set(true, forKey: "wp.hk.hasVerifiedReadAccess")
                lastError = nil
                return true
            } else {
                #if DEBUG
                print("🏥 HealthKit: ⚠️ READ access NOT verified - user may have denied or no data exists")
                #endif
                // Don't set to denied yet - could just be no data
                // Try checking if we can at least query
                let canQuery = await checkCanQuery()
                if canQuery {
                    #if DEBUG
                    print("🏥 HealthKit: ℹ️ Can query but no data - marking as authorized")
                    #endif
                    authorizationStatus = .authorized
                    hasVerifiedReadAccess = true
                    UserDefaults.standard.set(true, forKey: "wp.hk.hasVerifiedReadAccess")
                    return true
                } else {
                    #if DEBUG
                    print("🏥 HealthKit: ❌ Cannot query - likely denied")
                    #endif
                    authorizationStatus = .denied
                    hasVerifiedReadAccess = false
                    UserDefaults.standard.set(false, forKey: "wp.hk.hasVerifiedReadAccess")
                    return false
                }
            }

        } catch {
            #if DEBUG
            print("🏥 HealthKit: ❌ Authorization ERROR: \(error)")
            #endif
            #if DEBUG
            print("🏥 HealthKit: Error type: \(type(of: error))")
            #endif
            #if DEBUG
            print("🏥 HealthKit: Localized: \(error.localizedDescription)")
            #endif
            authorizationStatus = .denied
            hasVerifiedReadAccess = false
            UserDefaults.standard.set(false, forKey: "wp.hk.hasVerifiedReadAccess")
            lastError = error.localizedDescription
            return false
        }
    }

    /// Verify READ access by attempting to fetch workout data.
    /// Returns true if we can successfully query (even if empty results).
    /// Also updates hasWorkoutData based on whether workouts were found.
    private func verifyReadAccess() async -> Bool {
        guard let healthStore = healthStore else { return false }

        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                if let error = error {
                    #if DEBUG
                    print("🏥 HealthKit: verifyReadAccess error: \(error.localizedDescription)")
                    #endif
                    // Check if it's a permission error
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("authorization") || errorString.contains("denied") || errorString.contains("permission") {
                        continuation.resume(returning: false)
                    } else {
                        // Other errors might just mean no data
                        continuation.resume(returning: true)
                    }
                    return
                }

                // Query succeeded - we have read access
                let count = samples?.count ?? 0
                let foundData = count > 0
                #if DEBUG
                print("🏥 HealthKit: verifyReadAccess succeeded - found \(count) workout(s)")
                #endif

                // Update hasWorkoutData on main thread
                Task { @MainActor in
                    self?.hasWorkoutData = foundData
                    #if DEBUG
                    print("🏥 HealthKit: hasWorkoutData = \(foundData)")
                    #endif
                }

                continuation.resume(returning: true)
            }

            healthStore.execute(query)
        }
    }

    /// Check if we can query HealthKit at all (even for empty results).
    private func checkCanQuery() async -> Bool {
        guard let healthStore = healthStore else { return false }

        return await withCheckedContinuation { continuation in
            // Try querying for heart rate samples from today
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.resume(returning: false)
                return
            }

            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, _, error in
                if let error = error {
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("authorization") || errorString.contains("denied") {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: true)
                }
            }

            healthStore.execute(query)
        }
    }

    /// Check current authorization status.
    /// This attempts to verify actual READ access since HealthKit doesn't provide
    /// a direct way to check READ authorization.
    func checkAuthorizationStatus() {
        #if DEBUG
        print("🏥 HealthKit: checkAuthorizationStatus() called")
        #endif

        guard let healthStore = healthStore else {
            #if DEBUG
            print("🏥 HealthKit: HealthStore is nil - marking as unavailable")
            #endif
            authorizationStatus = .unavailable
            return
        }

        // Note: authorizationStatus(for:) only checks WRITE authorization
        // For READ, we need to rely on our hasVerifiedReadAccess flag
        // or attempt a data fetch

        if hasVerifiedReadAccess {
            #if DEBUG
            print("🏥 HealthKit: Previously verified read access - status: authorized")
            #endif
            authorizationStatus = .authorized
            return
        }

        // Check if we've ever requested authorization
        // This is a heuristic - if the app has requested before, HealthKit remembers
        let workoutWriteStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        #if DEBUG
        print("🏥 HealthKit: Workout WRITE status: \(workoutWriteStatus.rawValue)")
        #endif

        // For READ-only apps, we can't rely on write status
        // Best we can do is check if we haven't requested yet
        // Once requested, we need to verify via data fetch
        if workoutWriteStatus == .notDetermined {
            #if DEBUG
            print("🏥 HealthKit: Authorization not yet requested - status: notDetermined")
            #endif
            authorizationStatus = .notDetermined
        } else {
            // We've requested before - need to verify read access
            #if DEBUG
            print("🏥 HealthKit: Authorization was requested before - need to verify")
            #endif
            // Don't change status here - let the caller use refreshAuthorizationStatus() if needed
        }
    }

    /// Refresh authorization status by attempting a data fetch.
    /// Call this when returning from iOS Settings or when status might have changed.
    func refreshAuthorizationStatus() async {
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🏥 HealthKit: REFRESHING AUTHORIZATION STATUS")
        #endif
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif

        guard healthStore != nil else {
            #if DEBUG
            print("🏥 HealthKit: HealthStore is nil - marking as unavailable")
            #endif
            authorizationStatus = .unavailable
            hasWorkoutData = false
            return
        }

        let hasAccess = await verifyReadAccess()

        if hasAccess {
            #if DEBUG
            print("🏥 HealthKit: ✅ Refresh: READ access confirmed")
            #endif
            authorizationStatus = .authorized
            hasVerifiedReadAccess = true
            UserDefaults.standard.set(true, forKey: "wp.hk.hasVerifiedReadAccess")
        } else {
            #if DEBUG
            print("🏥 HealthKit: ❌ Refresh: READ access denied or unavailable")
            #endif
            authorizationStatus = .denied
            hasVerifiedReadAccess = false
            UserDefaults.standard.set(false, forKey: "wp.hk.hasVerifiedReadAccess")
            hasWorkoutData = false
        }

        #if DEBUG
        print("🏥 HealthKit: Final status: \(authorizationStatus.rawValue)")
        #endif
        #if DEBUG
        print("🏥 HealthKit: Connection state: \(connectionState.rawValue)")
        #endif
        #if DEBUG
        print("🏥 HealthKit: Has workout data: \(hasWorkoutData)")
        #endif
        #if DEBUG
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
    }

    // MARK: - Query Timeout

    /// Execute a HealthKit query with timeout protection
    /// Default timeout is 5 seconds (5_000_000_000 nanoseconds)
    private func executeQueryWithTimeout<T>(
        _ operation: @escaping () async -> T?,
        timeout: UInt64 = 5_000_000_000,
        fallback: T? = nil
    ) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            // Task 1: The actual operation
            group.addTask {
                return await operation()
            }

            // Task 2: Timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: timeout)
                return fallback
            }

            // Return whichever finishes first
            if let result = await group.next() {
                group.cancelAll()
                return result
            }
            return fallback
        }
    }

    // MARK: - Workout Fetching

    /// Fetch the most recent workout from HealthKit.
    /// Returns nil if no workouts exist or HealthKit is unavailable.
    func fetchMostRecentWorkout() async -> HKWorkout? {
        guard let healthStore = healthStore else {
            #if DEBUG
            print("🏥 HealthKit: fetchMostRecentWorkout - healthStore is nil, returning nil")
            #endif
            return nil
        }

        #if DEBUG
        print("🏥 HealthKit: fetchMostRecentWorkout - starting query...")
        #endif

        return await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let workoutType = HKObjectType.workoutType()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        #if DEBUG
                        print("🏥 HealthKit: fetchMostRecentWorkout - error: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: nil)
                        return
                    }

                    let workout = samples?.first as? HKWorkout
                    #if DEBUG
                    print("🏥 HealthKit: fetchMostRecentWorkout - found: \(workout != nil)")
                    #endif
                    continuation.resume(returning: workout)
                }

                healthStore.execute(query)
            }
        })
    }

    /// Fetch recent workouts from HealthKit.
    /// - Parameter limit: Maximum number of workouts to fetch (default 10)
    /// - Returns: Array of HKWorkout objects, empty if none found
    func fetchRecentWorkouts(limit: Int = 10) async -> [HKWorkout] {
        guard let healthStore = healthStore else {
            #if DEBUG
            print("🏥 HealthKit: fetchRecentWorkouts - healthStore is nil, returning []")
            #endif
            return []
        }

        #if DEBUG
        print("🏥 HealthKit: fetchRecentWorkouts - starting query for \(limit) workouts...")
        #endif

        let result = await executeQueryWithTimeout({
            await withCheckedContinuation { (continuation: CheckedContinuation<[HKWorkout]?, Never>) in
                let workoutType = HKObjectType.workoutType()
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: nil,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        #if DEBUG
                        print("🏥 HealthKit: fetchRecentWorkouts - error: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: [])
                        return
                    }

                    let workouts = samples as? [HKWorkout] ?? []
                    #if DEBUG
                    print("🏥 HealthKit: fetchRecentWorkouts - found \(workouts.count) workouts")
                    #endif
                    continuation.resume(returning: workouts)
                }

                healthStore.execute(query)
            }
        }, fallback: [] as [HKWorkout]?)

        return result ?? []
    }

    /// Map an HKWorkout to the app's Workout model.
    /// Fetches additional statistics (heart rate, distance) from HealthKit.
    func mapWorkout(_ hkWorkout: HKWorkout) async -> Workout {
        // Fetch heart rate data for this workout (nil when workout has no HR samples)
        let heartRateStats = await fetchHeartRateStats(for: hkWorkout)

        // Map HKWorkoutActivityType to our WorkoutType
        let workoutType = mapWorkoutType(hkWorkout.workoutActivityType)

        // Calculate intensity — pass 0 only for the duration-based fallback when HR is absent
        let intensity = calculateIntensity(
            averageHR: heartRateStats?.average ?? 0,
            maxHR: heartRateStats?.max ?? 0,
            duration: hkWorkout.duration
        )

        // Get calories — prefer activeEnergyBurned, fallback to totalEnergyBurned
        let calories: Int
        if let activeEnergy = hkWorkout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
            calories = Int(activeEnergy.doubleValue(for: .kilocalorie()))
        } else if let totalEnergy = hkWorkout.totalEnergyBurned {
            calories = Int(totalEnergy.doubleValue(for: .kilocalorie()))
        } else {
            calories = 0
        }

        // Get distance if available
        let distance: Double?
        if let distanceQuantity = hkWorkout.totalDistance {
            distance = distanceQuantity.doubleValue(for: .meterUnit(with: .kilo))
        } else {
            distance = nil
        }

        // Generate a basic interpretation
        let interpretation = generateWorkoutInterpretation(
            type: workoutType,
            duration: hkWorkout.duration,
            averageHR: heartRateStats?.average ?? 0,
            intensity: intensity
        )

        return Workout(
            id: hkWorkout.uuid,
            type: workoutType,
            startDate: hkWorkout.startDate,
            endDate: hkWorkout.endDate,
            duration: hkWorkout.duration,
            calories: calories,
            averageHeartRate: heartRateStats?.average,
            maxHeartRate: heartRateStats?.max,
            intensity: intensity,
            interpretation: interpretation,
            recoveryHeartRate: nil, // Would need additional query
            distance: distance,
            elevationGain: nil, // Would need additional query
            whatHappened: nil,
            whatItMeans: nil,
            whatToDoNext: nil,
            sleepBeforeWorkout: nil,
            hydrationLevel: nil,
            nutritionStatus: nil,
            preWorkoutNote: nil,
            perceivedEffort: nil,
            userFeedback: nil
        )
    }

    // MARK: - Heart Rate

    /// Heart rate statistics for a workout
    struct HeartRateStats {
        let average: Int
        let max: Int
        let min: Int
    }

    /// Fetch heart rate statistics for a specific workout.
    /// Returns nil when HealthKit is unavailable, the query fails, or the workout has no HR samples.
    private func fetchHeartRateStats(for workout: HKWorkout) async -> HeartRateStats? {
        guard let healthStore = healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        #if DEBUG
        let t = CFAbsoluteTimeGetCurrent()
        #endif
        let result: HeartRateStats? = await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: heartRateType,
                    quantitySamplePredicate: predicate,
                    options: [.discreteAverage, .discreteMax, .discreteMin]
                ) { _, statistics, error in
                    if error != nil {
                        continuation.resume(returning: nil)
                        return
                    }
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    guard let avgQuantity = statistics?.averageQuantity() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let average = Int(avgQuantity.doubleValue(for: unit))
                    let max = Int(statistics?.maximumQuantity()?.doubleValue(for: unit) ?? Double(average))
                    let min = Int(statistics?.minimumQuantity()?.doubleValue(for: unit) ?? Double(average))
                    continuation.resume(returning: HeartRateStats(average: average, max: max, min: min))
                }
                healthStore.execute(query)
            }
        }, timeout: 5_000_000_000)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t) * 1000
        if elapsed > 500 { print("🏥 [SLOW] fetchHeartRateStats: \(String(format: "%.0f", elapsed)) ms") }
        #endif
        return result
    }

    /// Fetch the most recent resting heart rate value.
    /// Returns nil if no data is available.
    func fetchRestingHeartRate() async -> Int? {
        guard let healthStore = healthStore,
              let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        #if DEBUG
        let t = CFAbsoluteTimeGetCurrent()
        #endif
        let result: Int? = await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: restingHRType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        #if DEBUG
                        print("Error fetching resting HR: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    let value = Int(sample.quantity.doubleValue(for: unit))
                    #if DEBUG
                    print("🏥 HealthKit: fetchRestingHeartRate → \(value) bpm")
                    #endif
                    continuation.resume(returning: value)
                }
                healthStore.execute(query)
            }
        }, timeout: 5_000_000_000)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t) * 1000
        if elapsed > 500 { print("🏥 [SLOW] fetchRestingHeartRate: \(String(format: "%.0f", elapsed)) ms") }
        #endif
        return result
    }

    // MARK: - HRV

    /// Fetch the most recent HRV (Heart Rate Variability) SDNN value in milliseconds.
    /// Returns nil if no data is available.
    func fetchHRV() async -> Double? {
        guard let healthStore = healthStore,
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        #if DEBUG
        let t = CFAbsoluteTimeGetCurrent()
        #endif
        let result: Double? = await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: hrvType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        #if DEBUG
                        print("Error fetching HRV: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    #if DEBUG
                    print("🏥 HealthKit: fetchHRV → \(String(format: "%.1f", value)) ms SDNN")
                    #endif
                    continuation.resume(returning: value)
                }
                healthStore.execute(query)
            }
        }, timeout: 5_000_000_000)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t) * 1000
        if elapsed > 500 { print("🏥 [SLOW] fetchHRV: \(String(format: "%.0f", elapsed)) ms") }
        #endif
        return result
    }

    // MARK: - Sleep

    /// Fetch sleep data for the previous night.
    /// Returns total sleep hours and inferred sleep quality.
    func fetchLastNightSleep() async -> (hours: Double, quality: SleepQuality)? {
        guard let healthStore = healthStore,
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday),
              let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfToday) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart, end: sleepWindowEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        #if DEBUG
        let t = CFAbsoluteTimeGetCurrent()
        #endif
        let result: (hours: Double, quality: SleepQuality)? = await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        #if DEBUG
                        print("Error fetching sleep: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    var totalSleepSeconds: TimeInterval = 0
                    for sample in sleepSamples {
                        if sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue &&
                           sample.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                            totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                    let totalHours = totalSleepSeconds / 3600
                    #if DEBUG
                    print("🏥 HealthKit: fetchLastNightSleep → samples=\(sleepSamples.count), asleep=\(String(format: "%.2f", totalHours)) hrs")
                    #endif
                    let quality: SleepQuality
                    switch totalHours {
                    case 8...: quality = .excellent
                    case 7..<8: quality = .good
                    case 6..<7: quality = .fair
                    default: quality = .poor
                    }
                    continuation.resume(returning: (hours: totalHours, quality: quality))
                }
                healthStore.execute(query)
            }
        }, timeout: 5_000_000_000)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t) * 1000
        if elapsed > 500 { print("🏥 [SLOW] fetchLastNightSleep: \(String(format: "%.0f", elapsed)) ms") }
        #endif
        return result
    }

    // MARK: - Nutrition & Water

    /// Fetch today's water intake in liters.
    func fetchTodayWaterIntake() async -> Double? {
        guard let healthStore = healthStore,
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return nil
        }

        let predicate = createTodayPredicate()

        #if DEBUG
        let t = CFAbsoluteTimeGetCurrent()
        #endif
        let result: Double? = await executeQueryWithTimeout({
            await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: waterType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error = error {
                        #if DEBUG
                        print("Error fetching water: \(error.localizedDescription)")
                        #endif
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let sum = statistics?.sumQuantity() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let liters = sum.doubleValue(for: .liter())
                    #if DEBUG
                    print("🏥 HealthKit: fetchTodayWaterIntake → \(String(format: "%.3f", liters)) L")
                    #endif
                    continuation.resume(returning: liters)
                }
                healthStore.execute(query)
            }
        }, timeout: 5_000_000_000)
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t) * 1000
        if elapsed > 500 { print("🏥 [SLOW] fetchTodayWaterIntake: \(String(format: "%.0f", elapsed)) ms") }
        #endif
        return result
    }

    /// Nutrition values for the day
    struct NutritionData {
        let caloriesConsumed: Int
        let carbohydrates: Double // grams
        let protein: Double // grams
    }

    // fetchTodayNutrition() removed: it was never called in production and used
    // ?? 0 fallbacks that would fabricate zero nutrition values. Nutrition is
    // handled by manual logging in NutritionLoggingView / NutritionService.

    /// Helper to fetch a single nutrient sum.
    private func fetchNutrientSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let healthStore = healthStore,
              let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        // Create predicate inside function to avoid Sendable issues
        let predicate = createTodayPredicate()

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    #if DEBUG
                    print("Error fetching \(identifier): \(error.localizedDescription)")
                    #endif
                    continuation.resume(returning: nil)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sum.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Helpers

    /// Create a predicate for samples from today (midnight to now).
    private func createTodayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
    }

    /// Map HKWorkoutActivityType to our app's WorkoutType enum.
    private func mapWorkoutType(_ activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .running:
            return .run
        case .walking, .hiking:
            return .walk
        case .cycling, .handCycling:
            return .cycle
        case .swimming, .waterFitness:
            return .swim
        case .highIntensityIntervalTraining, .crossTraining, .functionalStrengthTraining:
            return .hiit
        case .traditionalStrengthTraining, .coreTraining:
            return .strength
        case .yoga, .mindAndBody, .pilates, .flexibility:
            return .yoga
        default:
            return .other
        }
    }

    /// Calculate workout intensity based on heart rate and duration.
    private func calculateIntensity(averageHR: Int, maxHR: Int, duration: TimeInterval) -> WorkoutIntensity {
        // Simple intensity calculation based on heart rate zones
        // This is a basic heuristic - a more accurate version would use user's max HR

        // Assume max HR of ~190 for calculation
        let estimatedMaxHR = 190.0
        let avgHRPercent = Double(averageHR) / estimatedMaxHR

        switch avgHRPercent {
        case 0.9...:
            return .max
        case 0.8..<0.9:
            return .high
        case 0.7..<0.8:
            return .moderate
        default:
            return .low
        }
    }

    /// Generate a basic interpretation for the workout.
    private func generateWorkoutInterpretation(
        type: WorkoutType,
        duration: TimeInterval,
        averageHR: Int,
        intensity: WorkoutIntensity
    ) -> String {
        let durationMinutes = Int(duration / 60)

        switch intensity {
        case .low:
            return "Easy \(type.rawValue.lowercased()) session. Good for active recovery."
        case .moderate:
            return "Solid \(durationMinutes)-minute \(type.rawValue.lowercased()). Your effort was consistent and sustainable."
        case .high:
            return "Challenging \(type.rawValue.lowercased()) with elevated heart rate. Allow adequate recovery."
        case .max:
            return "Intense effort! Your body worked hard. Prioritize rest and nutrition today."
        }
    }
}

// MARK: - Developer Diagnostic Summary

extension HealthKitService {

    /// Print a full HealthKit diagnostic summary to the console.
    /// Call once after authorization completes to verify what HealthKit is providing.
    ///
    /// TYPES REQUESTED vs ACTUALLY FETCHED:
    ///   workouts              requested ✅  fetched ✅  → HomeViewModel.latestWorkout / recentWorkouts
    ///   heartRate             requested ✅  fetched ✅  → Workout.averageHeartRate / maxHeartRate (per-workout stats query)
    ///   restingHeartRate      requested ✅  fetched ✅  → DailyContext.restingHeartRate → readinessScore
    ///   heartRateVariability  requested ✅  fetched ✅  → DailyContext.hrvScore → stressLevel / readinessScore
    ///   sleepAnalysis         requested ✅  fetched ✅  → DailyContext.sleepHours / sleepQuality → readinessScore
    ///   activeEnergyBurned    requested ✅  fetched ✅  → Workout.calories (via workout.statistics)
    ///   distanceWalkingRun    requested ✅  fetched ✅  → Workout.distance (via workout.totalDistance)
    ///   dietaryWater          requested ✅  fetched ✅  → HomeViewModel.waterIntake
    ///   dietaryEnergyConsumed requested ✅  fetched ⚠️  → fetchTodayNutrition() defined but NEVER CALLED
    ///   dietaryCarbohydrates  requested ✅  fetched ⚠️  → fetchTodayNutrition() defined but NEVER CALLED
    ///   dietaryProtein        requested ✅  fetched ⚠️  → fetchTodayNutrition() defined but NEVER CALLED
    ///   bodyMass (weight)     NOT requested ❌          → weight is manual-entry only (DailyContext.weightKg)
    func printDiagnosticSummary() async {
        #if DEBUG
        print("🏥 HealthKit: ══════════ DIAGNOSTIC SUMMARY ══════════════════")
        print("🏥 HealthKit: available         = \(isHealthKitAvailable)")
        print("🏥 HealthKit: isSimulator       = \(isSimulator)")
        print("🏥 HealthKit: authStatus        = \(authorizationStatus.rawValue)")
        print("🏥 HealthKit: verifiedRead      = \(hasVerifiedReadAccess)")
        print("🏥 HealthKit: hasWorkoutData    = \(hasWorkoutData)")

        guard healthStore != nil && !isSimulator && authorizationStatus == .authorized else {
            print("🏥 HealthKit: ⚠️ Skipping fetch counts — not authorized or simulator")
            print("🏥 HealthKit: ══════════════════════════════════════════════════")
            return
        }

        let workouts = await fetchRecentWorkouts(limit: 500)
        print("🏥 HealthKit: workouts fetched  = \(workouts.count)")

        let sleepCount = await countSamples(type: HKCategoryType(.sleepAnalysis), days: 30)
        print("🏥 HealthKit: sleep samples     = \(sleepCount) (last 30 days)")

        let water = await fetchTodayWaterIntake()
        print("🏥 HealthKit: water today       = \(water.map { String(format: "%.3f L", $0) } ?? "nil (none logged)")")

        let rhr = await fetchRestingHeartRate()
        print("🏥 HealthKit: resting HR        = \(rhr.map { "\($0) bpm" } ?? "nil (no data)")")

        let hrv = await fetchHRV()
        print("🏥 HealthKit: HRV (SDNN)        = \(hrv.map { String(format: "%.1f ms", $0) } ?? "nil (no data)")")

        print("🏥 HealthKit: weight            = ❌ NOT read from HealthKit — manual entry only")
        print("🏥 HealthKit: nutrition (carbs/cal/protein) = ⚠️ fetchTodayNutrition() exists but is NEVER CALLED")
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        #endif
    }

    private func countSamples(type: HKSampleType, days: Int) async -> Int {
        guard let healthStore = healthStore else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Cycle / Reproductive Health

extension HealthKitService {

    /// Returns true if HealthKit has any menstrual flow data for today.
    /// Used to auto-suggest the Menstruation phase in CycleLoggingView.
    func hasTodayMenstrualFlow() async -> Bool {
        guard let store = healthStore,
              let menstrualType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow),
              !isSimulator else { return false }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfToday, end: endOfToday)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: menstrualType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                let hasSamples = !(samples ?? []).isEmpty
                continuation.resume(returning: hasSamples)
            }
            store.execute(query)
        }
    }
}

// MARK: - Convenience Extension for Workout Mapping

extension HealthKitService {

    /// Fetch and map the most recent workout to our Workout model.
    /// Returns nil if no workouts exist.
    func fetchAndMapMostRecentWorkout() async -> Workout? {
        guard let hkWorkout = await fetchMostRecentWorkout() else {
            return nil
        }
        return await mapWorkout(hkWorkout)
    }

    /// Fetch and map recent workouts to our Workout model.
    /// - Parameter limit: Maximum number of workouts to fetch
    /// - Returns: Array of mapped Workout objects
    func fetchAndMapRecentWorkouts(limit: Int = 10) async -> [Workout] {
        let hkWorkouts = await fetchRecentWorkouts(limit: limit)

        var workouts: [Workout] = []
        for hkWorkout in hkWorkouts {
            let workout = await mapWorkout(hkWorkout)
            workouts.append(workout)
        }

        return workouts
    }
}
