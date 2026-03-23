//
//  DataAvailability.swift
//  Insio Health
//
//  Centralized data availability tracking for honest UI states.
//  Determines what data is actually available vs. what would be guessing.
//

import Foundation

// MARK: - Data Availability

/// Tracks what real data is available for honest UI rendering.
/// Used to determine when to show real insights vs. placeholder states.
@MainActor
final class DataAvailability: ObservableObject {

    // MARK: - Singleton

    static let shared = DataAvailability()

    // MARK: - Services

    private let healthKitService = HealthKitService.shared
    private let persistenceService = PersistenceService.shared

    // MARK: - Published State

    /// Whether HealthKit is connected and authorized
    @Published private(set) var isHealthKitConnected = false

    /// Whether we have any HealthKit workout data
    @Published private(set) var hasHealthKitWorkouts = false

    /// Whether we have heart rate data from any source
    @Published private(set) var hasHeartRateData = false

    /// Whether we have HRV data
    @Published private(set) var hasHRVData = false

    /// Whether we have sleep data
    @Published private(set) var hasSleepData = false

    /// Total workout count (manual + HealthKit)
    @Published private(set) var totalWorkoutCount = 0

    /// Whether this appears to be a first-time user
    @Published private(set) var isFirstTimeUser = true

    // MARK: - Computed Properties

    /// Whether we have enough data for physiological insights
    var hasPhysiologicalData: Bool {
        hasHeartRateData || hasHRVData
    }

    /// Whether we have enough data for recovery insights
    var hasRecoveryData: Bool {
        hasSleepData && hasHRVData
    }

    /// Whether we have enough data for trend analysis (at least 3 workouts)
    var hasTrendData: Bool {
        totalWorkoutCount >= 3
    }

    /// Whether we have enough data for weekly summary (at least 1 workout)
    var hasWeeklyData: Bool {
        totalWorkoutCount >= 1
    }

    /// User-friendly connection status
    var healthKitStatusText: String {
        if !healthKitService.isHealthKitAvailable {
            return "Not Available"
        }
        switch healthKitService.authorizationStatus {
        case .authorized:
            return hasHealthKitWorkouts ? "Connected" : "Connected · No workouts yet"
        case .denied:
            return "Access Denied"
        case .notDetermined:
            return "Not Connected"
        case .unavailable:
            return "Not Available"
        }
    }

    var healthKitStatusColor: String {
        switch healthKitService.authorizationStatus {
        case .authorized:
            return hasHealthKitWorkouts ? "olive" : "navy"
        case .denied:
            return "coral"
        case .notDetermined, .unavailable:
            return "textTertiary"
        }
    }

    // MARK: - Initialization

    private init() {
        refresh()
    }

    // MARK: - Refresh

    /// Refresh all data availability states
    func refresh() {
        // Check HealthKit status
        healthKitService.checkAuthorizationStatus()
        isHealthKitConnected = healthKitService.authorizationStatus == .authorized

        // Check workout count
        let workouts = persistenceService.fetchRecentWorkouts(limit: 100)
        totalWorkoutCount = workouts.count
        isFirstTimeUser = totalWorkoutCount == 0

        // Check for HealthKit workouts (non-manual)
        hasHealthKitWorkouts = workouts.contains { $0.source == .healthKit }

        // Check for heart rate data
        hasHeartRateData = workouts.contains { $0.averageHeartRate != nil }

        // Check for HRV data (from daily context)
        if let context = persistenceService.fetchTodayDailyContext() {
            hasHRVData = context.hrvScore != nil
            hasSleepData = context.sleepHours > 0
        } else {
            hasHRVData = false
            hasSleepData = false
        }

        print("📊 DataAvailability: refreshed - HealthKit=\(isHealthKitConnected), workouts=\(totalWorkoutCount), HR=\(hasHeartRateData), HRV=\(hasHRVData)")
    }

    /// Check if a specific workout has physiological data
    func workoutHasPhysiologicalData(_ workout: Workout) -> Bool {
        workout.averageHeartRate != nil || workout.maxHeartRate != nil
    }

    /// Check if this is the user's first workout
    func isFirstWorkout(_ workout: Workout) -> Bool {
        let allWorkouts = persistenceService.fetchRecentWorkouts(limit: 100)
        return allWorkouts.count == 1 && allWorkouts.first?.id == workout.id
    }
}
