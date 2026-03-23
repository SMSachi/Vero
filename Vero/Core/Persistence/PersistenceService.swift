//
//  PersistenceService.swift
//  Insio Health
//
//  Service for managing local data persistence using SwiftData.
//  Handles CRUD operations for workouts, contexts, check-ins, and recovery data.
//
//  ARCHITECTURE:
//  - Singleton service accessible throughout the app
//  - All operations are @MainActor for thread safety with SwiftUI
//  - Provides both synchronous (from context) and async methods
//  - Falls back gracefully if persistence fails
//
//  DATA FLOW:
//  1. HealthKit data → HealthKitService fetches → PersistenceService saves
//  2. UI reads → PersistenceService provides cached/stored data
//  3. Check-ins → UI captures → PersistenceService saves
//  4. InterpretationEngine → generates → PersistenceService stores with workout
//

import Foundation
import SwiftData

// MARK: - Persistence Service

/// Singleton service for all local data persistence operations.
@MainActor
final class PersistenceService: ObservableObject {

    // MARK: - Singleton

    static let shared = PersistenceService()

    // MARK: - Container

    /// The SwiftData model container
    let container: ModelContainer

    /// Main model context for operations
    var context: ModelContext {
        container.mainContext
    }

    // MARK: - Schema Version

    /// Increment this when making breaking schema changes during development.
    /// This triggers a store reset to avoid migration issues.
    private static let schemaVersion = 2  // v2: suggestedWorkoutTypes → suggestedWorkoutTypesData

    // MARK: - Initialization

    private init() {
        // Check if we need to reset the store due to schema changes
        let lastSchemaVersion = UserDefaults.standard.integer(forKey: "swiftDataSchemaVersion")
        if lastSchemaVersion != Self.schemaVersion {
            print("PersistenceService: Schema version changed (\(lastSchemaVersion) → \(Self.schemaVersion)), resetting store...")
            Self.deleteExistingStore()
            UserDefaults.standard.set(Self.schemaVersion, forKey: "swiftDataSchemaVersion")
        }

        do {
            // Configure the schema with all persistent models
            let schema = Schema([
                PersistedWorkout.self,
                PersistedDailyContext.self,
                PersistedCheckIn.self,
                PersistedNextDayRecovery.self,
                PersistedPostWorkoutCheckIn.self
            ])

            // Configure the model (stored in app's documents directory)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            print("PersistenceService: SwiftData container initialized successfully (schema v\(Self.schemaVersion))")

        } catch {
            // Schema mismatch - try to recover by deleting the store
            print("PersistenceService: ⚠️ Container creation failed: \(error)")
            print("PersistenceService: Attempting recovery by deleting incompatible store...")

            Self.deleteExistingStore()

            // Try again with fresh store
            do {
                let schema = Schema([
                    PersistedWorkout.self,
                    PersistedDailyContext.self,
                    PersistedCheckIn.self,
                    PersistedNextDayRecovery.self,
                    PersistedPostWorkoutCheckIn.self
                ])

                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )

                container = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )

                UserDefaults.standard.set(Self.schemaVersion, forKey: "swiftDataSchemaVersion")
                print("PersistenceService: ✅ Recovery successful - store recreated")

            } catch {
                fatalError("Failed to create SwiftData container even after reset: \(error)")
            }
        }
    }

    /// Delete existing SwiftData store files
    private static func deleteExistingStore() {
        let fileManager = FileManager.default

        // SwiftData stores in Application Support directory
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("PersistenceService: Could not find Application Support directory")
            return
        }

        // Default SwiftData store name
        let storeURL = appSupport.appendingPathComponent("default.store")

        // Delete all store-related files
        let filesToDelete = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        for url in filesToDelete {
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    print("PersistenceService: Deleted \(url.lastPathComponent)")
                }
            } catch {
                print("PersistenceService: Failed to delete \(url.lastPathComponent): \(error)")
            }
        }
    }

    // MARK: - Workout Operations

    /// Save or update a workout from HealthKit data.
    /// If a workout with the same ID exists, it's updated; otherwise, a new one is created.
    @discardableResult
    func saveWorkout(_ workout: Workout) -> PersistedWorkout {
        print("💾 PersistenceService: ─────────────────────────────────")
        print("💾 PersistenceService: SAVING WORKOUT")
        print("💾 PersistenceService: ID: \(workout.id)")
        print("💾 PersistenceService: Type: \(workout.type.rawValue)")
        print("💾 PersistenceService: Source: \(workout.source.rawValue)")
        print("💾 PersistenceService: Duration: \(Int(workout.duration / 60)) min")
        print("💾 PersistenceService: Calories: \(workout.calories)")
        if let avgHR = workout.averageHeartRate {
            print("💾 PersistenceService: Avg HR: \(avgHR) bpm")
        }

        // Check if workout already exists
        if let existing = fetchPersistedWorkout(id: workout.id) {
            // Update existing workout
            print("💾 PersistenceService: ↻ Updating existing workout")
            updatePersistedWorkout(existing, from: workout)
            return existing
        }

        // Create new persisted workout
        print("💾 PersistenceService: ✚ Creating new workout record")
        let persisted = PersistedWorkout(from: workout)
        context.insert(persisted)

        do {
            try context.save()
            print("💾 PersistenceService: ✅ WORKOUT SAVED SUCCESSFULLY")
            print("💾 PersistenceService: ─────────────────────────────────")
        } catch {
            print("💾 PersistenceService: ❌ ERROR SAVING WORKOUT: \(error)")
        }

        return persisted
    }

    /// Update an existing persisted workout with new data
    private func updatePersistedWorkout(_ persisted: PersistedWorkout, from workout: Workout) {
        persisted.type = workout.type.rawValue
        persisted.startDate = workout.startDate
        persisted.endDate = workout.endDate
        persisted.duration = workout.duration
        persisted.calories = workout.calories
        persisted.averageHeartRate = workout.averageHeartRate
        persisted.maxHeartRate = workout.maxHeartRate
        persisted.intensity = workout.intensity.rawValue
        persisted.interpretation = workout.interpretation
        persisted.recoveryHeartRate = workout.recoveryHeartRate
        persisted.distance = workout.distance
        persisted.elevationGain = workout.elevationGain
        persisted.whatHappened = workout.whatHappened
        persisted.whatItMeans = workout.whatItMeans
        persisted.whatToDoNext = workout.whatToDoNext
        persisted.source = workout.source.rawValue
        persisted.updatedAt = Date()

        do {
            try context.save()
        } catch {
            print("PersistenceService: Error updating workout: \(error)")
        }
    }

    /// Save interpretation data for a workout
    func saveWorkoutInterpretation(workoutId: UUID, interpretation: WorkoutInterpretation) {
        print("💾 PersistenceService: ─────────────────────────────────")
        print("💾 PersistenceService: SAVING INTERPRETATION")
        print("💾 PersistenceService: Workout ID: \(workoutId)")
        print("💾 PersistenceService: Summary: \(interpretation.summaryText.prefix(50))...")
        print("💾 PersistenceService: Sentiment: \(interpretation.sentiment)")

        guard let persisted = fetchPersistedWorkout(id: workoutId) else {
            print("💾 PersistenceService: ❌ Workout not found for interpretation")
            return
        }

        persisted.updateInterpretation(interpretation)

        do {
            try context.save()
            print("💾 PersistenceService: ✅ INTERPRETATION SAVED")
            print("💾 PersistenceService: ─────────────────────────────────")
        } catch {
            print("💾 PersistenceService: ❌ ERROR SAVING INTERPRETATION: \(error)")
        }
    }

    /// Fetch a persisted workout by ID
    func fetchPersistedWorkout(id: UUID) -> PersistedWorkout? {
        let descriptor = FetchDescriptor<PersistedWorkout>(
            predicate: #Predicate { $0.workoutId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("PersistenceService: Error fetching workout: \(error)")
            return nil
        }
    }

    /// Fetch the most recent workout
    func fetchLatestWorkout() -> Workout? {
        var descriptor = FetchDescriptor<PersistedWorkout>(
            sortBy: [SortDescriptor(\.endDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let results = try context.fetch(descriptor)
            return results.first?.toWorkout()
        } catch {
            print("PersistenceService: Error fetching latest workout: \(error)")
            return nil
        }
    }

    /// Fetch recent workouts
    func fetchRecentWorkouts(limit: Int = 10) -> [Workout] {
        var descriptor = FetchDescriptor<PersistedWorkout>(
            sortBy: [SortDescriptor(\.endDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let results = try context.fetch(descriptor)
            return results.map { $0.toWorkout() }
        } catch {
            print("PersistenceService: Error fetching recent workouts: \(error)")
            return []
        }
    }

    /// Fetch workouts within a date range
    func fetchWorkouts(from startDate: Date, to endDate: Date) -> [Workout] {
        let descriptor = FetchDescriptor<PersistedWorkout>(
            predicate: #Predicate { $0.startDate >= startDate && $0.startDate <= endDate },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            return results.map { $0.toWorkout() }
        } catch {
            print("PersistenceService: Error fetching workouts in range: \(error)")
            return []
        }
    }

    // MARK: - Daily Context Operations

    /// Save or update daily context
    @discardableResult
    func saveDailyContext(_ context: DailyContext) -> PersistedDailyContext {
        // Check if context for today already exists
        if let existing = fetchTodayContext() {
            updatePersistedContext(existing, from: context)
            return existing
        }

        let persisted = PersistedDailyContext(from: context)
        self.context.insert(persisted)

        do {
            try self.context.save()
            print("PersistenceService: Saved daily context for \(context.date)")
        } catch {
            print("PersistenceService: Error saving daily context: \(error)")
        }

        return persisted
    }

    /// Update existing daily context
    private func updatePersistedContext(_ persisted: PersistedDailyContext, from ctx: DailyContext) {
        persisted.sleepHours = ctx.sleepHours
        persisted.sleepQuality = ctx.sleepQuality.rawValue
        persisted.stressLevel = ctx.stressLevel.rawValue
        persisted.energyLevel = ctx.energyLevel.rawValue
        persisted.restingHeartRate = ctx.restingHeartRate
        persisted.hrvScore = ctx.hrvScore
        persisted.readinessScore = ctx.readinessScore
        persisted.updatedAt = Date()

        do {
            try context.save()
        } catch {
            print("PersistenceService: Error updating daily context: \(error)")
        }
    }

    /// Fetch today's daily context
    func fetchTodayContext() -> PersistedDailyContext? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let descriptor = FetchDescriptor<PersistedDailyContext>(
            predicate: #Predicate { $0.date >= startOfToday && $0.date < endOfToday },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("PersistenceService: Error fetching today's context: \(error)")
            return nil
        }
    }

    /// Fetch daily context as struct
    func fetchTodayDailyContext() -> DailyContext? {
        return fetchTodayContext()?.toDailyContext()
    }

    /// Fetch recent daily contexts
    func fetchRecentDailyContexts(limit: Int = 30) -> [DailyContext] {
        var descriptor = FetchDescriptor<PersistedDailyContext>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let results = try context.fetch(descriptor)
            return results.map { $0.toDailyContext() }
        } catch {
            print("PersistenceService: Error fetching recent daily contexts: \(error)")
            return []
        }
    }

    /// Fetch daily context for a specific date
    func fetchDailyContext(for date: Date) -> DailyContext? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<PersistedDailyContext>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.toDailyContext()
        } catch {
            print("PersistenceService: Error fetching daily context for date: \(error)")
            return nil
        }
    }

    // MARK: - Post-Workout Check-In Operations

    /// Save a post-workout check-in
    func savePostWorkoutCheckIn(
        workoutId: UUID,
        feeling: String,
        note: String?
    ) {
        print("💾 PersistenceService: ─────────────────────────────────")
        print("💾 PersistenceService: SAVING POST-WORKOUT CHECK-IN")
        print("💾 PersistenceService: Workout ID: \(workoutId)")
        print("💾 PersistenceService: Feeling: \(feeling)")
        if let note = note, !note.isEmpty {
            print("💾 PersistenceService: Note: \(note)")
        }

        // Create the check-in record
        let checkIn = PersistedPostWorkoutCheckIn(
            workoutId: workoutId,
            feeling: feeling,
            note: note
        )
        context.insert(checkIn)
        print("💾 PersistenceService: ✚ Created check-in record")

        // Also update the workout with check-in data
        if let workout = fetchPersistedWorkout(id: workoutId) {
            workout.updateWithCheckIn(feeling: feeling, note: note)
            print("💾 PersistenceService: ↻ Updated workout with check-in data")
        } else {
            print("💾 PersistenceService: ⚠️ Workout not found for check-in update")
        }

        do {
            try context.save()
            print("💾 PersistenceService: ✅ CHECK-IN SAVED SUCCESSFULLY")
            print("💾 PersistenceService: ─────────────────────────────────")
        } catch {
            print("💾 PersistenceService: ❌ ERROR SAVING CHECK-IN: \(error)")
        }
    }

    /// Fetch post-workout check-in for a specific workout
    func fetchPostWorkoutCheckIn(for workoutId: UUID) -> PersistedPostWorkoutCheckIn? {
        let descriptor = FetchDescriptor<PersistedPostWorkoutCheckIn>(
            predicate: #Predicate { $0.workoutId == workoutId }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("PersistenceService: Error fetching post-workout check-in: \(error)")
            return nil
        }
    }

    // MARK: - Next Day Recovery Operations

    /// Save or update next day recovery data
    @discardableResult
    func saveNextDayRecovery(_ recovery: NextDayRecovery, for workoutId: UUID? = nil) -> PersistedNextDayRecovery {
        let persisted = PersistedNextDayRecovery(from: recovery)

        // Link to related workout if provided
        if let workoutId = workoutId,
           let workout = fetchPersistedWorkout(id: workoutId) {
            persisted.relatedWorkout = workout
        }

        context.insert(persisted)

        do {
            try context.save()
            print("PersistenceService: Saved next day recovery for \(recovery.date)")
        } catch {
            print("PersistenceService: Error saving next day recovery: \(error)")
        }

        return persisted
    }

    /// Save next-day check-in (morning feeling)
    func saveNextDayCheckIn(
        recoveryId: UUID? = nil,
        workoutId: UUID?,
        bodyFeeling: String
    ) {
        // If we have a recovery ID, update that record
        if let recoveryId = recoveryId,
           let recovery = fetchPersistedRecovery(id: recoveryId) {
            recovery.updateWithCheckIn(bodyFeeling: bodyFeeling)

            do {
                try context.save()
                print("PersistenceService: Updated next day recovery with check-in")
            } catch {
                print("PersistenceService: Error updating recovery check-in: \(error)")
            }
            return
        }

        // Otherwise, find the most recent workout's recovery or create new
        if let workoutId = workoutId,
           let workout = fetchPersistedWorkout(id: workoutId),
           let recovery = workout.nextDayRecovery {
            recovery.updateWithCheckIn(bodyFeeling: bodyFeeling)

            do {
                try context.save()
                print("PersistenceService: Updated workout's recovery with check-in")
            } catch {
                print("PersistenceService: Error updating recovery check-in: \(error)")
            }
        }
    }

    /// Fetch recovery by ID
    func fetchPersistedRecovery(id: UUID) -> PersistedNextDayRecovery? {
        let descriptor = FetchDescriptor<PersistedNextDayRecovery>(
            predicate: #Predicate { $0.recoveryId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("PersistenceService: Error fetching recovery: \(error)")
            return nil
        }
    }

    /// Fetch today's recovery data
    func fetchTodayRecovery() -> NextDayRecovery? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let descriptor = FetchDescriptor<PersistedNextDayRecovery>(
            predicate: #Predicate { $0.date >= startOfToday && $0.date < endOfToday },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.toNextDayRecovery()
        } catch {
            print("PersistenceService: Error fetching today's recovery: \(error)")
            return nil
        }
    }

    // MARK: - General Check-In Operations

    /// Save a general check-in
    func saveCheckIn(_ checkIn: CheckIn) {
        let persisted = PersistedCheckIn(from: checkIn)
        context.insert(persisted)

        do {
            try context.save()
            print("PersistenceService: Saved general check-in")
        } catch {
            print("PersistenceService: Error saving check-in: \(error)")
        }
    }

    /// Fetch recent check-ins
    func fetchRecentCheckIns(limit: Int = 10) -> [CheckIn] {
        var descriptor = FetchDescriptor<PersistedCheckIn>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let results = try context.fetch(descriptor)
            return results.map { $0.toCheckIn() }
        } catch {
            print("PersistenceService: Error fetching check-ins: \(error)")
            return []
        }
    }

    /// Fetch check-in by ID
    func fetchCheckIn(id: UUID) -> CheckIn? {
        let descriptor = FetchDescriptor<PersistedCheckIn>(
            predicate: #Predicate { $0.checkInId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first?.toCheckIn()
        } catch {
            print("PersistenceService: Error fetching check-in by ID: \(error)")
            return nil
        }
    }

    /// Fetch recent post-workout check-ins
    func fetchRecentPostWorkoutCheckIns(limit: Int = 100) -> [PersistedPostWorkoutCheckIn] {
        var descriptor = FetchDescriptor<PersistedPostWorkoutCheckIn>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try context.fetch(descriptor)
        } catch {
            print("PersistenceService: Error fetching post-workout check-ins: \(error)")
            return []
        }
    }

    /// Fetch recent recoveries as structs
    func fetchRecentRecoveries(limit: Int = 100) -> [NextDayRecovery] {
        var descriptor = FetchDescriptor<PersistedNextDayRecovery>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let results = try context.fetch(descriptor)
            return results.map { $0.toNextDayRecovery() }
        } catch {
            print("PersistenceService: Error fetching recoveries: \(error)")
            return []
        }
    }

    /// Fetch recent trend insights (placeholder - returns empty until TrendInsight persistence is added)
    func fetchRecentTrendInsights(limit: Int = 50) -> [TrendInsight] {
        // TrendInsights are currently generated on-demand by TrendAnalysisService
        // and not persisted. Return empty array for now.
        return []
    }

    // MARK: - Statistics & Queries

    /// Count workouts this week
    func countWorkoutsThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }

        let descriptor = FetchDescriptor<PersistedWorkout>(
            predicate: #Predicate { $0.startDate >= startOfWeek }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.count
        } catch {
            print("PersistenceService: Error counting workouts: \(error)")
            return 0
        }
    }

    /// Calculate current workout streak (consecutive days)
    func calculateCurrentStreak() -> Int {
        var descriptor = FetchDescriptor<PersistedWorkout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 30 // Look back up to 30 days

        do {
            let results = try context.fetch(descriptor)
            guard !results.isEmpty else { return 0 }

            let calendar = Calendar.current
            var streak = 0
            var currentDate = calendar.startOfDay(for: Date())

            // Group workouts by day
            let workoutDays = Set(results.map { calendar.startOfDay(for: $0.startDate) })

            // Check if there's a workout today or yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate)!

            if !workoutDays.contains(currentDate) && !workoutDays.contains(yesterday) {
                return 0 // Streak broken
            }

            // Count backwards
            while workoutDays.contains(currentDate) || workoutDays.contains(yesterday) {
                if workoutDays.contains(currentDate) {
                    streak += 1
                }
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                if streak > 30 { break } // Safety limit
            }

            return streak
        } catch {
            print("PersistenceService: Error calculating streak: \(error)")
            return 0
        }
    }

    /// Calculate longest workout streak ever
    func calculateLongestStreak() -> Int {
        let descriptor = FetchDescriptor<PersistedWorkout>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )

        do {
            let results = try context.fetch(descriptor)
            guard !results.isEmpty else { return 0 }

            let calendar = Calendar.current

            // Group workouts by day
            let workoutDays = Set(results.map { calendar.startOfDay(for: $0.startDate) }).sorted()

            var longestStreak = 1
            var currentStreak = 1

            for i in 1..<workoutDays.count {
                let previousDay = workoutDays[i - 1]
                let currentDay = workoutDays[i]

                // Check if consecutive days
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
                   calendar.isDate(currentDay, inSameDayAs: nextDay) {
                    currentStreak += 1
                    longestStreak = max(longestStreak, currentStreak)
                } else {
                    currentStreak = 1
                }
            }

            return longestStreak
        } catch {
            print("PersistenceService: Error calculating longest streak: \(error)")
            return 0
        }
    }

    /// Check if user has checked in for a workout
    func hasCheckedIn(for workoutId: UUID) -> Bool {
        return fetchPostWorkoutCheckIn(for: workoutId) != nil
    }

    // MARK: - Stored Interpretation Access

    /// Get stored interpretation for a workout
    func getStoredInterpretation(for workoutId: UUID) -> WorkoutInterpretation? {
        guard let persisted = fetchPersistedWorkout(id: workoutId),
              let summary = persisted.interpretationSummary,
              let text = persisted.interpretationText,
              let recommendation = persisted.interpretationRecommendation else {
            return nil
        }

        let sentiment: InterpretationSentiment = {
            switch persisted.interpretationSentiment {
            case "positive": return .positive
            case "caution": return .caution
            default: return .neutral
            }
        }()

        return WorkoutInterpretation(
            summaryText: summary,
            interpretationText: text,
            recommendationText: recommendation,
            bulletPoints: [], // Bullet points aren't persisted currently
            sentiment: sentiment,
            signals: [] // Signals aren't persisted currently
        )
    }

    // MARK: - Data Cleanup

    /// Clear all persisted data (for account deletion)
    func clearAllData() {
        print("🗑️ PersistenceService: Clearing all data...")

        do {
            // Delete all workouts
            let workoutDescriptor = FetchDescriptor<PersistedWorkout>()
            let workouts = try context.fetch(workoutDescriptor)
            for workout in workouts {
                context.delete(workout)
            }
            print("🗑️ PersistenceService: Deleted \(workouts.count) workouts")

            // Delete all daily contexts
            let contextDescriptor = FetchDescriptor<PersistedDailyContext>()
            let contexts = try context.fetch(contextDescriptor)
            for ctx in contexts {
                context.delete(ctx)
            }
            print("🗑️ PersistenceService: Deleted \(contexts.count) daily contexts")

            // Delete all post-workout check-ins
            let checkInDescriptor = FetchDescriptor<PersistedPostWorkoutCheckIn>()
            let checkIns = try context.fetch(checkInDescriptor)
            for checkIn in checkIns {
                context.delete(checkIn)
            }
            print("🗑️ PersistenceService: Deleted \(checkIns.count) check-ins")

            // Delete all next-day recoveries
            let recoveryDescriptor = FetchDescriptor<PersistedNextDayRecovery>()
            let recoveries = try context.fetch(recoveryDescriptor)
            for recovery in recoveries {
                context.delete(recovery)
            }
            print("🗑️ PersistenceService: Deleted \(recoveries.count) recoveries")

            // Save changes
            try context.save()
            print("🗑️ PersistenceService: ✅ All data cleared successfully")

        } catch {
            print("🗑️ PersistenceService: ❌ Error clearing data: \(error)")
        }
    }
}

// MARK: - Check-In Data for Interpretation

/// Data structure for passing check-in information to InterpretationEngine
struct CheckInData {
    let postWorkoutFeeling: String?
    let postWorkoutNote: String?
    let nextDayFeeling: String?

    /// Create from persisted workout data
    static func from(workout: PersistedWorkout) -> CheckInData {
        CheckInData(
            postWorkoutFeeling: workout.postWorkoutFeeling,
            postWorkoutNote: workout.postWorkoutNote,
            nextDayFeeling: workout.nextDayRecovery?.bodyFeeling
        )
    }
}
