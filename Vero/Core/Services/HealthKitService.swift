//
//  HealthKitService.swift
//  Insio Health
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

        return types
    }

    // MARK: - Initialization

    private init() {
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        print("🏥 HealthKit: SERVICE INITIALIZING")
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        print("🏥 HealthKit: isHealthDataAvailable = \(HKHealthStore.isHealthDataAvailable())")
        print("🏥 HealthKit: isSimulator = \(Self.isSimulator)")

        // IMPORTANT: On simulator, treat HealthKit as unavailable even though
        // isHealthDataAvailable() returns true on iOS 17+. The simulator's
        // HealthKit database is non-functional and queries will hang indefinitely.
        if Self.isSimulator {
            print("🏥 HealthKit: ⚠️ SIMULATOR DETECTED - marking HealthKit as unavailable")
            print("🏥 HealthKit: ⚠️ This prevents hangs from non-functional HealthKit queries")
            self.healthStore = nil
            self.authorizationStatus = .unavailable
        } else if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
            print("🏥 HealthKit: ✅ HKHealthStore created successfully")
        } else {
            self.healthStore = nil
            self.authorizationStatus = .unavailable
            print("🏥 HealthKit: ❌ HealthKit unavailable on this device")
        }
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
    }

    // MARK: - Authorization

    /// Request HealthKit authorization for all required data types.
    /// This presents the system HealthKit authorization sheet to the user.
    ///
    /// - Returns: True if authorization was granted (at least partially), false otherwise
    func requestAuthorization() async -> Bool {
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        print("🏥 HealthKit: AUTHORIZATION REQUEST")
        print("🏥 HealthKit: ══════════════════════════════════════════════════")

        guard let healthStore = healthStore else {
            print("🏥 HealthKit: ❌ ABORT - HealthStore is nil (unavailable)")
            authorizationStatus = .unavailable
            lastError = "HealthKit is not available on this device"
            return false
        }

        print("🏥 HealthKit: Requesting authorization for \(readTypes.count) data types...")
        print("🏥 HealthKit: Types: \(readTypes.map { $0.identifier.components(separatedBy: ".").last ?? $0.identifier })")

        do {
            // Request authorization - we only need READ access, no WRITE access
            // The empty set for toShare means we won't write any data
            print("🏥 HealthKit: 🚀 Calling healthStore.requestAuthorization()...")

            try await healthStore.requestAuthorization(toShare: [], read: readTypes)

            print("🏥 HealthKit: ✅ Authorization request completed (no error thrown)")

            // IMPORTANT: HealthKit requestAuthorization completes successfully even if user denies
            // We need to verify READ access by attempting to fetch data
            print("🏥 HealthKit: 🔍 Verifying READ access by attempting data fetch...")

            let hasAccess = await verifyReadAccess()

            if hasAccess {
                print("🏥 HealthKit: ✅ READ access VERIFIED - data fetch succeeded")
                authorizationStatus = .authorized
                hasVerifiedReadAccess = true
                lastError = nil
                return true
            } else {
                print("🏥 HealthKit: ⚠️ READ access NOT verified - user may have denied or no data exists")
                // Don't set to denied yet - could just be no data
                // Try checking if we can at least query
                let canQuery = await checkCanQuery()
                if canQuery {
                    print("🏥 HealthKit: ℹ️ Can query but no data - marking as authorized")
                    authorizationStatus = .authorized
                    hasVerifiedReadAccess = true
                    return true
                } else {
                    print("🏥 HealthKit: ❌ Cannot query - likely denied")
                    authorizationStatus = .denied
                    hasVerifiedReadAccess = false
                    return false
                }
            }

        } catch {
            print("🏥 HealthKit: ❌ Authorization ERROR: \(error)")
            print("🏥 HealthKit: Error type: \(type(of: error))")
            print("🏥 HealthKit: Localized: \(error.localizedDescription)")
            authorizationStatus = .denied
            hasVerifiedReadAccess = false
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
                    print("🏥 HealthKit: verifyReadAccess error: \(error.localizedDescription)")
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
                print("🏥 HealthKit: verifyReadAccess succeeded - found \(count) workout(s)")

                // Update hasWorkoutData on main thread
                Task { @MainActor in
                    self?.hasWorkoutData = foundData
                    print("🏥 HealthKit: hasWorkoutData = \(foundData)")
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
        print("🏥 HealthKit: checkAuthorizationStatus() called")

        guard let healthStore = healthStore else {
            print("🏥 HealthKit: HealthStore is nil - marking as unavailable")
            authorizationStatus = .unavailable
            return
        }

        // Note: authorizationStatus(for:) only checks WRITE authorization
        // For READ, we need to rely on our hasVerifiedReadAccess flag
        // or attempt a data fetch

        if hasVerifiedReadAccess {
            print("🏥 HealthKit: Previously verified read access - status: authorized")
            authorizationStatus = .authorized
            return
        }

        // Check if we've ever requested authorization
        // This is a heuristic - if the app has requested before, HealthKit remembers
        let workoutWriteStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        print("🏥 HealthKit: Workout WRITE status: \(workoutWriteStatus.rawValue)")

        // For READ-only apps, we can't rely on write status
        // Best we can do is check if we haven't requested yet
        // Once requested, we need to verify via data fetch
        if workoutWriteStatus == .notDetermined {
            print("🏥 HealthKit: Authorization not yet requested - status: notDetermined")
            authorizationStatus = .notDetermined
        } else {
            // We've requested before - need to verify read access
            print("🏥 HealthKit: Authorization was requested before - need to verify")
            // Don't change status here - let the caller use refreshAuthorizationStatus() if needed
        }
    }

    /// Refresh authorization status by attempting a data fetch.
    /// Call this when returning from iOS Settings or when status might have changed.
    func refreshAuthorizationStatus() async {
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
        print("🏥 HealthKit: REFRESHING AUTHORIZATION STATUS")
        print("🏥 HealthKit: ══════════════════════════════════════════════════")

        guard healthStore != nil else {
            print("🏥 HealthKit: HealthStore is nil - marking as unavailable")
            authorizationStatus = .unavailable
            hasWorkoutData = false
            return
        }

        let hasAccess = await verifyReadAccess()

        if hasAccess {
            print("🏥 HealthKit: ✅ Refresh: READ access confirmed")
            authorizationStatus = .authorized
            hasVerifiedReadAccess = true
        } else {
            print("🏥 HealthKit: ❌ Refresh: READ access denied or unavailable")
            authorizationStatus = .denied
            hasVerifiedReadAccess = false
            hasWorkoutData = false
        }

        print("🏥 HealthKit: Final status: \(authorizationStatus.rawValue)")
        print("🏥 HealthKit: Connection state: \(connectionState.rawValue)")
        print("🏥 HealthKit: Has workout data: \(hasWorkoutData)")
        print("🏥 HealthKit: ══════════════════════════════════════════════════")
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
            print("🏥 HealthKit: fetchMostRecentWorkout - healthStore is nil, returning nil")
            return nil
        }

        print("🏥 HealthKit: fetchMostRecentWorkout - starting query...")

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
                        print("🏥 HealthKit: fetchMostRecentWorkout - error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }

                    let workout = samples?.first as? HKWorkout
                    print("🏥 HealthKit: fetchMostRecentWorkout - found: \(workout != nil)")
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
            print("🏥 HealthKit: fetchRecentWorkouts - healthStore is nil, returning []")
            return []
        }

        print("🏥 HealthKit: fetchRecentWorkouts - starting query for \(limit) workouts...")

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
                        print("🏥 HealthKit: fetchRecentWorkouts - error: \(error.localizedDescription)")
                        continuation.resume(returning: [])
                        return
                    }

                    let workouts = samples as? [HKWorkout] ?? []
                    print("🏥 HealthKit: fetchRecentWorkouts - found \(workouts.count) workouts")
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
        // Fetch heart rate data for this workout
        let heartRateStats = await fetchHeartRateStats(for: hkWorkout)

        // Map HKWorkoutActivityType to our WorkoutType
        let workoutType = mapWorkoutType(hkWorkout.workoutActivityType)

        // Calculate intensity based on heart rate and duration
        let intensity = calculateIntensity(
            averageHR: heartRateStats.average,
            maxHR: heartRateStats.max,
            duration: hkWorkout.duration
        )

        // Get calories - prefer activeEnergyBurned, fallback to totalEnergyBurned
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
            averageHR: heartRateStats.average,
            intensity: intensity
        )

        return Workout(
            id: UUID(),
            type: workoutType,
            startDate: hkWorkout.startDate,
            endDate: hkWorkout.endDate,
            duration: hkWorkout.duration,
            calories: calories,
            averageHeartRate: heartRateStats.average,
            maxHeartRate: heartRateStats.max,
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
    private func fetchHeartRateStats(for workout: HKWorkout) async -> HeartRateStats {
        guard let healthStore = healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return HeartRateStats(average: 0, max: 0, min: 0)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax, .discreteMin]
            ) { _, statistics, error in
                if let error = error {
                    print("Error fetching heart rate: \(error.localizedDescription)")
                    continuation.resume(returning: HeartRateStats(average: 0, max: 0, min: 0))
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let average = Int(statistics?.averageQuantity()?.doubleValue(for: unit) ?? 0)
                let max = Int(statistics?.maximumQuantity()?.doubleValue(for: unit) ?? 0)
                let min = Int(statistics?.minimumQuantity()?.doubleValue(for: unit) ?? 0)

                continuation.resume(returning: HeartRateStats(average: average, max: max, min: min))
            }

            healthStore.execute(query)
        }
    }

    /// Fetch the most recent resting heart rate value.
    /// Returns nil if no data is available.
    func fetchRestingHeartRate() async -> Int? {
        guard let healthStore = healthStore,
              let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching resting HR: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let value = Int(sample.quantity.doubleValue(for: unit))
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
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

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching HRV: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                // HRV SDNN is measured in milliseconds
                let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Sleep

    /// Fetch sleep data for the previous night.
    /// Returns total sleep hours and inferred sleep quality.
    func fetchLastNightSleep() async -> (hours: Double, quality: SleepQuality)? {
        guard let healthStore = healthStore,
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        // Calculate the time range for "last night" (yesterday 6pm to today 12pm)
        let calendar = Calendar.current
        let now = Date()

        // Start of today
        let startOfToday = calendar.startOfDay(for: now)

        // Yesterday at 6pm (sleep window start)
        guard let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) else {
            return nil
        }

        // Today at 12pm (sleep window end)
        guard let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfToday) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepWindowStart,
            end: sleepWindowEnd,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching sleep: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Calculate total sleep duration
                // We look for asleep states (not just "in bed")
                var totalSleepSeconds: TimeInterval = 0

                for sample in sleepSamples {
                    // Check for actual sleep states (not "in bed" which is value 0)
                    // HKCategoryValueSleepAnalysis: inBed = 0, asleepUnspecified = 1, awake = 2, asleepCore = 3, asleepDeep = 4, asleepREM = 5
                    if sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue &&
                       sample.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                        totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let totalHours = totalSleepSeconds / 3600

                // Determine sleep quality based on duration
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
    }

    // MARK: - Nutrition & Water

    /// Fetch today's water intake in liters.
    func fetchTodayWaterIntake() async -> Double? {
        guard let healthStore = healthStore,
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return nil
        }

        let predicate = createTodayPredicate()

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    print("Error fetching water: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                // Convert to liters
                let liters = sum.doubleValue(for: .liter())
                continuation.resume(returning: liters)
            }

            healthStore.execute(query)
        }
    }

    /// Nutrition values for the day
    struct NutritionData {
        let caloriesConsumed: Int
        let carbohydrates: Double // grams
        let protein: Double // grams
    }

    /// Fetch today's nutrition data (calories, carbs, protein).
    func fetchTodayNutrition() async -> NutritionData? {
        guard healthStore != nil else { return nil }

        // Fetch values sequentially to avoid Swift 6 sendability warnings
        // (NSPredicate is not Sendable and cannot be captured in async let)
        let calories = await fetchNutrientSum(.dietaryEnergyConsumed, unit: .kilocalorie())
        let carbs = await fetchNutrientSum(.dietaryCarbohydrates, unit: .gram())
        let protein = await fetchNutrientSum(.dietaryProtein, unit: .gram())

        // Return nil if we have no data at all
        if calories == nil && carbs == nil && protein == nil {
            return nil
        }

        return NutritionData(
            caloriesConsumed: Int(calories ?? 0),
            carbohydrates: carbs ?? 0,
            protein: protein ?? 0
        )
    }

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
                    print("Error fetching \(identifier): \(error.localizedDescription)")
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
