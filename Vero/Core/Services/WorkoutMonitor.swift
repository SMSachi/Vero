//
//  WorkoutMonitor.swift
//  Insio Health
//
//  Monitors for new workouts and automates check-in triggers.
//  This service detects when new workouts are saved locally and
//  triggers the appropriate check-in flows.
//
//  ARCHITECTURE:
//  - Singleton service that monitors workout persistence
//  - Triggers post-workout check-in when new workout is detected
//  - Schedules next-day check-in for the following morning
//  - All logic runs locally (no remote calls)
//
//  CHECK-IN FLOW:
//  1. New workout detected → trigger post-workout check-in
//  2. After post-workout → schedule next-day check-in
//  3. Next day morning → trigger next-day recovery check-in
//  4. All check-ins linked to originating workout
//

import Foundation
import Combine

// MARK: - Workout Monitor

/// Monitors for new workouts and triggers check-in flows automatically.
@MainActor
final class WorkoutMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = WorkoutMonitor()

    // MARK: - Published State

    /// Whether a post-workout check-in is pending
    @Published private(set) var hasPendingPostWorkoutCheckIn = false

    /// Whether a next-day check-in is pending
    @Published private(set) var hasPendingNextDayCheckIn = false

    /// The workout awaiting post-workout check-in
    @Published private(set) var pendingWorkoutForCheckIn: Workout?

    /// The workout awaiting next-day check-in
    @Published private(set) var pendingWorkoutForNextDayCheckIn: Workout?

    // MARK: - Private State

    /// Last known workout ID to detect new workouts
    private var lastKnownWorkoutId: UUID? {
        get { UserDefaults.standard.string(forKey: "lastKnownWorkoutId").flatMap { UUID(uuidString: $0) } }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "lastKnownWorkoutId") }
    }

    /// Scheduled next-day check-in workout ID
    private var scheduledNextDayWorkoutId: UUID? {
        get { UserDefaults.standard.string(forKey: "scheduledNextDayWorkoutId").flatMap { UUID(uuidString: $0) } }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "scheduledNextDayWorkoutId") }
    }

    /// Scheduled next-day check-in date
    private var scheduledNextDayDate: Date? {
        get { UserDefaults.standard.object(forKey: "scheduledNextDayDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "scheduledNextDayDate") }
    }

    /// Workouts that have already had check-ins completed
    private var completedPostWorkoutIds: Set<UUID> {
        get {
            let strings = UserDefaults.standard.stringArray(forKey: "completedPostWorkoutIds") ?? []
            return Set(strings.compactMap { UUID(uuidString: $0) })
        }
        set {
            let strings = newValue.map { $0.uuidString }
            UserDefaults.standard.set(Array(strings), forKey: "completedPostWorkoutIds")
        }
    }

    private var completedNextDayIds: Set<UUID> {
        get {
            let strings = UserDefaults.standard.stringArray(forKey: "completedNextDayIds") ?? []
            return Set(strings.compactMap { UUID(uuidString: $0) })
        }
        set {
            let strings = newValue.map { $0.uuidString }
            UserDefaults.standard.set(Array(strings), forKey: "completedNextDayIds")
        }
    }

    // MARK: - Services

    private let persistenceService = PersistenceService.shared

    // MARK: - Initialization

    private init() {
        // Check for pending check-ins on launch
        checkForPendingCheckIns()
    }

    // MARK: - Public Methods

    /// Check for any new workouts and pending check-ins.
    /// Called on app launch and after data sync.
    func checkForPendingCheckIns() {
        checkForNewWorkout()
        checkForScheduledNextDayCheckIn()
        checkForYesterdaysWorkoutWithoutCheckIn()
    }

    /// Notify the monitor that a new workout has been saved.
    /// This triggers the post-workout check-in flow ONLY for eligible workouts.
    ///
    /// Check-in eligibility rules:
    /// - Workout must be from current session (not restored from cloud sync)
    /// - Workout must be recent (within 4 hours)
    /// - Workout must not have already had a check-in
    func workoutSaved(_ workout: Workout) {
        // Skip if this workout already had a post-workout check-in
        guard !completedPostWorkoutIds.contains(workout.id) else {
            print("WorkoutMonitor: Workout already has post-workout check-in")
            return
        }

        // Skip if this is the same workout we already know about
        guard workout.id != lastKnownWorkoutId else {
            print("WorkoutMonitor: Workout already known")
            return
        }

        // CRITICAL: Check workout source - only trigger for eligible sources
        // This prevents check-ins for restored/synced historical workouts
        guard workout.source.eligibleForCheckIn else {
            print("WorkoutMonitor: Workout source '\(workout.source.rawValue)' not eligible for check-in")
            lastKnownWorkoutId = workout.id
            return
        }

        // Check if workout is recent enough for post-workout check-in (within 4 hours)
        let hoursSinceWorkout = -workout.endDate.timeIntervalSinceNow / 3600
        guard hoursSinceWorkout < 4 else {
            print("WorkoutMonitor: Workout too old for post-workout check-in (\(Int(hoursSinceWorkout))h ago)")
            lastKnownWorkoutId = workout.id
            return
        }

        // All checks passed - trigger post-workout check-in
        pendingWorkoutForCheckIn = workout
        hasPendingPostWorkoutCheckIn = true
        lastKnownWorkoutId = workout.id

        print("WorkoutMonitor: New workout detected (source: \(workout.source.rawValue)), triggering post-workout check-in")
    }

    /// Mark post-workout check-in as completed.
    /// Schedules next-day check-in for the following morning.
    func postWorkoutCheckInCompleted(for workoutId: UUID) {
        completedPostWorkoutIds.insert(workoutId)
        hasPendingPostWorkoutCheckIn = false
        pendingWorkoutForCheckIn = nil

        // Schedule next-day check-in
        scheduleNextDayCheckIn(for: workoutId)

        print("WorkoutMonitor: Post-workout check-in completed, next-day scheduled")
    }

    /// Mark post-workout check-in as skipped.
    /// Still schedules next-day check-in.
    func postWorkoutCheckInSkipped(for workoutId: UUID) {
        hasPendingPostWorkoutCheckIn = false
        pendingWorkoutForCheckIn = nil

        // Still schedule next-day check-in even if post-workout was skipped
        scheduleNextDayCheckIn(for: workoutId)

        print("WorkoutMonitor: Post-workout check-in skipped, next-day still scheduled")
    }

    /// Mark next-day check-in as completed.
    func nextDayCheckInCompleted(for workoutId: UUID) {
        completedNextDayIds.insert(workoutId)
        hasPendingNextDayCheckIn = false
        pendingWorkoutForNextDayCheckIn = nil
        scheduledNextDayWorkoutId = nil
        scheduledNextDayDate = nil

        print("WorkoutMonitor: Next-day check-in completed")
    }

    /// Mark next-day check-in as skipped.
    func nextDayCheckInSkipped(for workoutId: UUID) {
        hasPendingNextDayCheckIn = false
        pendingWorkoutForNextDayCheckIn = nil
        scheduledNextDayWorkoutId = nil
        scheduledNextDayDate = nil

        print("WorkoutMonitor: Next-day check-in skipped")
    }

    /// Get the appropriate time window for post-workout check-in.
    func shouldShowPostWorkoutCheckIn() -> Bool {
        guard let workout = pendingWorkoutForCheckIn else { return false }

        // Show if workout ended within last 4 hours
        let hoursSinceWorkout = -workout.endDate.timeIntervalSinceNow / 3600
        return hoursSinceWorkout < 4 && hoursSinceWorkout >= 0
    }

    /// Check if it's the right time for next-day check-in.
    func shouldShowNextDayCheckIn() -> Bool {
        guard let scheduledDate = scheduledNextDayDate,
              scheduledNextDayWorkoutId != nil else {
            return false
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        // Show between 6 AM and 12 PM on the scheduled day
        let isScheduledDay = calendar.isDate(now, inSameDayAs: scheduledDate)
        let isWithinTimeWindow = hour >= 6 && hour < 12

        return isScheduledDay && isWithinTimeWindow
    }

    // MARK: - Private Methods

    private func checkForNewWorkout() {
        // Get the most recent workout
        guard let latestWorkout = persistenceService.fetchLatestWorkout() else {
            return
        }

        // Update last known workout ID even if we don't trigger check-in
        // This prevents re-checking the same workout repeatedly
        if latestWorkout.id != lastKnownWorkoutId {
            // Only trigger check-in if workout is eligible
            // This prevents check-ins for synced/restored historical workouts
            if latestWorkout.isEligibleForCheckIn {
                workoutSaved(latestWorkout)
            } else {
                // Just update the tracking without triggering check-in
                lastKnownWorkoutId = latestWorkout.id
                print("WorkoutMonitor: Latest workout not eligible for check-in, skipping")
            }
        }
    }

    private func checkForScheduledNextDayCheckIn() {
        guard let workoutId = scheduledNextDayWorkoutId,
              !completedNextDayIds.contains(workoutId) else {
            return
        }

        // Check if it's time for the check-in
        if shouldShowNextDayCheckIn() {
            // Load the workout
            if let workout = persistenceService.fetchLatestWorkout() {
                pendingWorkoutForNextDayCheckIn = workout
                hasPendingNextDayCheckIn = true

                print("WorkoutMonitor: Next-day check-in time reached")
            }
        }
    }

    /// Check for workouts from yesterday that qualify for next-day check-in
    /// even if they weren't explicitly scheduled (e.g., user didn't open app yesterday)
    private func checkForYesterdaysWorkoutWithoutCheckIn() {
        // Skip if we already have a pending next-day check-in
        guard !hasPendingNextDayCheckIn else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Only check during morning hours (6 AM - 12 PM)
        guard hour >= 6 && hour < 12 else { return }

        // Get yesterday's date range
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }
        let yesterdayStart = calendar.startOfDay(for: yesterday)
        guard let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart) else { return }

        // Fetch recent workouts and find one from yesterday
        let recentWorkouts = persistenceService.fetchRecentWorkouts(limit: 10)
        let yesterdaysWorkouts = recentWorkouts.filter { workout in
            workout.endDate >= yesterdayStart && workout.endDate < yesterdayEnd
        }

        // Find the first workout that hasn't had a next-day check-in
        for workout in yesterdaysWorkouts {
            guard !completedNextDayIds.contains(workout.id) else { continue }

            // Check if there's no existing next-day check-in for this workout
            let persistedWorkout = persistenceService.fetchPersistedWorkout(id: workout.id)
            if persistedWorkout?.nextDayRecovery?.bodyFeeling == nil {
                // Found a qualifying workout - trigger check-in
                pendingWorkoutForNextDayCheckIn = workout
                hasPendingNextDayCheckIn = true
                scheduledNextDayWorkoutId = workout.id
                scheduledNextDayDate = now

                print("WorkoutMonitor: Found yesterday's workout without next-day check-in: \(workout.type.rawValue)")
                return
            }
        }
    }

    private func scheduleNextDayCheckIn(for workoutId: UUID) {
        // Skip if already completed for this workout
        guard !completedNextDayIds.contains(workoutId) else {
            return
        }

        // Schedule for tomorrow morning at 8 AM
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            return
        }

        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 8
        components.minute = 0

        if let scheduledDate = calendar.date(from: components) {
            scheduledNextDayWorkoutId = workoutId
            scheduledNextDayDate = scheduledDate

            print("WorkoutMonitor: Next-day check-in scheduled for \(scheduledDate)")
        }
    }

    // MARK: - Debug/Reset

    /// Clear all pending check-ins (for debugging)
    func clearAllPending() {
        hasPendingPostWorkoutCheckIn = false
        hasPendingNextDayCheckIn = false
        pendingWorkoutForCheckIn = nil
        pendingWorkoutForNextDayCheckIn = nil
        scheduledNextDayWorkoutId = nil
        scheduledNextDayDate = nil
    }

    /// Reset all completed check-in tracking (for debugging)
    func resetCompletedTracking() {
        completedPostWorkoutIds = []
        completedNextDayIds = []
        lastKnownWorkoutId = nil
    }
}

// MARK: - Check-In Status

/// Status of check-ins for a specific workout
struct WorkoutCheckInStatus {
    let workoutId: UUID
    let hasPostWorkoutCheckIn: Bool
    let hasNextDayCheckIn: Bool
    let postWorkoutFeeling: String?
    let nextDayFeeling: String?

    var isComplete: Bool {
        hasPostWorkoutCheckIn && hasNextDayCheckIn
    }
}

extension WorkoutMonitor {

    /// Get check-in status for a specific workout
    func getCheckInStatus(for workoutId: UUID) -> WorkoutCheckInStatus {
        let postCheckIn = persistenceService.fetchPostWorkoutCheckIn(for: workoutId)
        let persistedWorkout = persistenceService.fetchPersistedWorkout(id: workoutId)

        return WorkoutCheckInStatus(
            workoutId: workoutId,
            hasPostWorkoutCheckIn: postCheckIn != nil,
            hasNextDayCheckIn: persistedWorkout?.nextDayRecovery?.bodyFeeling != nil,
            postWorkoutFeeling: postCheckIn?.feeling,
            nextDayFeeling: persistedWorkout?.nextDayRecovery?.bodyFeeling
        )
    }

    /// Get all workouts that need check-ins
    func getWorkoutsNeedingCheckIns() -> [Workout] {
        let recentWorkouts = persistenceService.fetchRecentWorkouts(limit: 5)

        return recentWorkouts.filter { workout in
            let status = getCheckInStatus(for: workout.id)
            return !status.isComplete
        }
    }
}
