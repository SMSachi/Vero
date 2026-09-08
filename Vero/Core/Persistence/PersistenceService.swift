//
//  PersistenceService.swift
//  WellPattern Health
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
            #if DEBUG
            print("PersistenceService: Schema version changed (\(lastSchemaVersion) → \(Self.schemaVersion)), resetting store...")
            #endif
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

            #if DEBUG
            print("PersistenceService: SwiftData container initialized successfully (schema v\(Self.schemaVersion))")
            #endif

        } catch {
            // Schema mismatch - try to recover by deleting the store
            #if DEBUG
            print("PersistenceService: ⚠️ Container creation failed: \(error)")
            #endif
            #if DEBUG
            print("PersistenceService: Attempting recovery by deleting incompatible store...")
            #endif

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
                #if DEBUG
                print("PersistenceService: ✅ Recovery successful - store recreated")
                #endif

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
            #if DEBUG
            print("PersistenceService: Could not find Application Support directory")
            #endif
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
                    #if DEBUG
                    print("PersistenceService: Deleted \(url.lastPathComponent)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("PersistenceService: Failed to delete \(url.lastPathComponent): \(error)")
                #endif
            }
        }
    }

    // MARK: - Workout Operations

    /// Save or update a workout from HealthKit data.
    /// If a workout with the same ID exists, it's updated; otherwise, a new one is created.
    @discardableResult
    func saveWorkout(_ workout: Workout) -> PersistedWorkout {
        #if DEBUG
        print("💾 PersistenceService: ─────────────────────────────────")
        #endif
        #if DEBUG
        print("💾 PersistenceService: SAVING WORKOUT")
        #endif
        #if DEBUG
        print("💾 PersistenceService: ID: \(workout.id)")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Type: \(workout.type.rawValue)")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Source: \(workout.source.rawValue)")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Duration: \(Int(workout.duration / 60)) min")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Calories: \(workout.calories)")
        #endif
        if let avgHR = workout.averageHeartRate {
            #if DEBUG
            print("💾 PersistenceService: Avg HR: \(avgHR) bpm")
            #endif
        }

        // Check if workout already exists
        if let existing = fetchPersistedWorkout(id: workout.id) {
            // Update existing workout
            #if DEBUG
            print("💾 PersistenceService: ↻ Updating existing workout")
            #endif
            updatePersistedWorkout(existing, from: workout)
            return existing
        }

        // Create new persisted workout
        #if DEBUG
        print("💾 PersistenceService: ✚ Creating new workout record")
        #endif
        let persisted = PersistedWorkout(from: workout)
        context.insert(persisted)

        do {
            try context.save()
            #if DEBUG
            print("💾 PersistenceService: ✅ WORKOUT SAVED SUCCESSFULLY")
            #endif
            #if DEBUG
            print("💾 PersistenceService: ─────────────────────────────────")
            #endif
        } catch {
            #if DEBUG
            print("💾 PersistenceService: ❌ ERROR SAVING WORKOUT: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error updating workout: \(error)")
            #endif
        }
    }

    /// Save interpretation data for a workout
    func saveWorkoutInterpretation(workoutId: UUID, interpretation: WorkoutInterpretation) {
        #if DEBUG
        print("💾 PersistenceService: ─────────────────────────────────")
        #endif
        #if DEBUG
        print("💾 PersistenceService: SAVING INTERPRETATION")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Workout ID: \(workoutId)")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Summary: \(interpretation.summaryText.prefix(50))...")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Sentiment: \(interpretation.sentiment)")
        #endif

        guard let persisted = fetchPersistedWorkout(id: workoutId) else {
            #if DEBUG
            print("💾 PersistenceService: ❌ Workout not found for interpretation")
            #endif
            return
        }

        persisted.updateInterpretation(interpretation)

        do {
            try context.save()
            #if DEBUG
            print("💾 PersistenceService: ✅ INTERPRETATION SAVED")
            #endif
            #if DEBUG
            print("💾 PersistenceService: ─────────────────────────────────")
            #endif
        } catch {
            #if DEBUG
            print("💾 PersistenceService: ❌ ERROR SAVING INTERPRETATION: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching workout: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching latest workout: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching recent workouts: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching workouts in range: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Daily Context Operations

    /// Save or update daily context
    @discardableResult
    func saveDailyContext(_ context: DailyContext) -> PersistedDailyContext {
        #if DEBUG
        print("📊 PersistenceService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("📊 PersistenceService: SAVING DAILY CONTEXT")
        #endif
        #if DEBUG
        print("📊 PersistenceService: Date: \(context.date)")
        #endif
        #if DEBUG
        print("📊 PersistenceService: Water: \(context.waterIntakeMl ?? 0)ml")
        #endif
        #if DEBUG
        print("📊 PersistenceService: Calories: \(context.calories ?? 0)")
        #endif
        #if DEBUG
        print("📊 PersistenceService: Weight: \(context.weightKg ?? 0)kg")
        #endif

        // Check if context for today already exists
        if let existing = fetchTodayContext() {
            #if DEBUG
            print("📊 PersistenceService: Found existing context, updating...")
            #endif
            updatePersistedContext(existing, from: context)
            return existing
        }

        #if DEBUG
        print("📊 PersistenceService: Creating new context...")
        #endif
        let persisted = PersistedDailyContext(from: context)
        self.context.insert(persisted)

        do {
            try self.context.save()
            #if DEBUG
            print("📊 PersistenceService: ✅ Saved daily context for \(context.date)")
            #endif
            #if DEBUG
            print("📊 PersistenceService: ══════════════════════════════════════════════════")
            #endif
        } catch {
            #if DEBUG
            print("📊 PersistenceService: ❌ Error saving daily context: \(error)")
            #endif
            #if DEBUG
            print("📊 PersistenceService: ══════════════════════════════════════════════════")
            #endif
        }

        return persisted
    }

    /// Update existing daily context using merge semantics.
    ///
    /// MERGE RULES:
    /// - HK-owned biometrics (restingHR, hrv, readiness, stress, energy): always update —
    ///   these are fresh measurements and should replace stale cached values.
    /// - User-owned sleep: only update if incoming > 0. Zero means HealthKit had no sleep
    ///   data, NOT that the user slept 0 hours. A manual log of 9h must survive a subsequent
    ///   HK fetch that returns 0.
    /// - User-owned nutrition / weight: only update if incoming is non-nil (and > 0 for weight).
    ///   nil means the caller (typically HomeViewModel.fetchDailyContext) did not receive this
    ///   value from HealthKit and the field is absent from the incoming struct — never a
    ///   deliberate nil-write from a manual logging view, which always passes the current value.
    private func updatePersistedContext(_ persisted: PersistedDailyContext, from ctx: DailyContext) {
        #if DEBUG
        print("📊 [TRACE 8] updatePersistedContext() START — sleep=\(ctx.sleepHours)h water=\(ctx.waterIntakeMl.map {"\($0)ml"} ?? "nil") weight=\(ctx.weightKg.map {"\($0)kg"} ?? "nil") hrv=\(ctx.hrvScore.map {"\($0)ms"} ?? "nil")")
        #endif

        // HK-owned biometrics: fresh measurement always wins
        persisted.restingHeartRate = ctx.restingHeartRate
        persisted.hrvScore = ctx.hrvScore
        persisted.readinessScore = ctx.readinessScore
        persisted.stressLevel = ctx.stressLevel.rawValue
        persisted.energyLevel = ctx.energyLevel.rawValue

        // Sleep: only update if HK actually returned sleep data (> 0)
        // Zero means HealthKit has no record — preserve any manually logged value
        if ctx.sleepHours > 0 {
            #if DEBUG
            print("📊 [TRACE 8] sleep → UPDATING to \(ctx.sleepHours)h (was \(persisted.sleepHours)h)")
            #endif
            persisted.sleepHours = ctx.sleepHours
            persisted.sleepQuality = ctx.sleepQuality.rawValue
        } else {
            #if DEBUG
            print("📊 [TRACE 8] sleep → PRESERVED \(persisted.sleepHours)h (incoming was 0)")
            #endif
        }

        // Nutrition / weight: only update when the caller provided a real value
        // nil means this field was absent from the incoming context (HK had no data)
        if let v = ctx.waterIntakeMl {
            #if DEBUG
            print("📊 [TRACE 8] water → UPDATING to \(v)ml (was \(persisted.waterIntakeMl?.description ?? "nil")ml)")
            #endif
            persisted.waterIntakeMl = v
        } else {
            #if DEBUG
            print("📊 [TRACE 8] water → PRESERVED \(persisted.waterIntakeMl?.description ?? "nil")ml (incoming was nil)")
            #endif
        }
        if let v = ctx.calories { persisted.calories = v }
        if let v = ctx.proteinGrams { persisted.proteinGrams = v }
        if let v = ctx.carbsGrams { persisted.carbsGrams = v }
        if let v = ctx.fatGrams { persisted.fatGrams = v }
        if let v = ctx.weightKg, v > 0 {
            #if DEBUG
            print("📊 [TRACE 8] weight → UPDATING to \(v)kg (was \(persisted.weightKg?.description ?? "nil")kg)")
            #endif
            persisted.weightKg = v
        } else {
            #if DEBUG
            print("📊 [TRACE 8] weight → PRESERVED \(persisted.weightKg?.description ?? "nil")kg (incoming was \(ctx.weightKg?.description ?? "nil"))")
            #endif
        }
        if let v = ctx.bodyFatPercentage { persisted.bodyFatPercentage = v }
        if let v = ctx.cyclePhase { persisted.cyclePhase = v.rawValue }
        if let v = ctx.cycleDay { persisted.cycleDay = v }

        persisted.updatedAt = Date()

        do {
            try context.save()
            #if DEBUG
            print("📊 [TRACE 8] updatePersistedContext() COMPLETE ✅")
            #endif
        } catch {
            #if DEBUG
            print("📊 [TRACE 8] updatePersistedContext() SAVE ERROR ❌: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching today's context: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching recent daily contexts: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching daily context for date: \(error)")
            #endif
            return nil
        }
    }

    /// Fetch the last recorded weight (from any daily context that has weight data)
    func fetchLastRecordedWeight() -> Double? {
        var descriptor = FetchDescriptor<PersistedDailyContext>(
            predicate: #Predicate { $0.weightKg != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        do {
            let results = try context.fetch(descriptor)
            return results.first(where: { ($0.weightKg ?? 0) > 0 })?.weightKg
        } catch {
            #if DEBUG
            print("PersistenceService: Error fetching last weight: \(error)")
            #endif
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
        #if DEBUG
        print("💾 PersistenceService: ─────────────────────────────────")
        #endif
        #if DEBUG
        print("💾 PersistenceService: SAVING POST-WORKOUT CHECK-IN")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Workout ID: \(workoutId)")
        #endif
        #if DEBUG
        print("💾 PersistenceService: Feeling: \(feeling)")
        #endif
        if let note = note, !note.isEmpty {
            #if DEBUG
            print("💾 PersistenceService: Note: \(note)")
            #endif
        }

        // Create the check-in record
        let checkIn = PersistedPostWorkoutCheckIn(
            workoutId: workoutId,
            feeling: feeling,
            note: note
        )
        context.insert(checkIn)
        #if DEBUG
        print("💾 PersistenceService: ✚ Created check-in record")
        #endif

        // Also update the workout with check-in data
        if let workout = fetchPersistedWorkout(id: workoutId) {
            workout.updateWithCheckIn(feeling: feeling, note: note)
            #if DEBUG
            print("💾 PersistenceService: ↻ Updated workout with check-in data")
            #endif
        } else {
            #if DEBUG
            print("💾 PersistenceService: ⚠️ Workout not found for check-in update")
            #endif
        }

        do {
            try context.save()
            #if DEBUG
            print("💾 PersistenceService: ✅ CHECK-IN SAVED SUCCESSFULLY")
            #endif
            #if DEBUG
            print("💾 PersistenceService: ─────────────────────────────────")
            #endif
        } catch {
            #if DEBUG
            print("💾 PersistenceService: ❌ ERROR SAVING CHECK-IN: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching post-workout check-in: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Next Day Recovery Operations

    /// Save or update next day recovery data
    @discardableResult
    func saveNextDayRecovery(_ recovery: NextDayRecovery, for workoutId: UUID? = nil) -> PersistedNextDayRecovery {
        let persisted = PersistedNextDayRecovery(from: recovery)

        // Insert into context FIRST — SwiftData requires backing data to be initialized
        // before any relationship property is read or written. Setting relatedWorkout
        // on an uninserted @Model object triggers "Never access a full future backing
        // data" because the backing store placeholder is not yet materialized.
        context.insert(persisted)

        // Link to related workout AFTER insert (both objects now have valid contexts)
        if let workoutId = workoutId,
           let workout = fetchPersistedWorkout(id: workoutId) {
            #if DEBUG
            print("📈 [RECOVERY] linking recovery to workout \(workoutId)")
            #endif
            persisted.relatedWorkout = workout
        }

        do {
            try context.save()
            #if DEBUG
            print("📈 [RECOVERY] saveNextDayRecovery ✅ date=\(recovery.date) workoutId=\(workoutId?.uuidString ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            print("📈 [RECOVERY] saveNextDayRecovery ❌ \(error)")
            #endif
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
                #if DEBUG
                print("PersistenceService: Updated next day recovery with check-in")
                #endif
            } catch {
                #if DEBUG
                print("PersistenceService: Error updating recovery check-in: \(error)")
                #endif
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
                #if DEBUG
                print("PersistenceService: Updated workout's recovery with check-in")
                #endif
            } catch {
                #if DEBUG
                print("PersistenceService: Error updating recovery check-in: \(error)")
                #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching recovery: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching today's recovery: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Saved general check-in")
            #endif
        } catch {
            #if DEBUG
            print("PersistenceService: Error saving check-in: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching check-ins: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching check-in by ID: \(error)")
            #endif
            return nil
        }
    }

    /// Batch fetch: all workout IDs mapped to their updatedAt timestamps.
    /// Used by sync service to avoid N individual fetchPersistedWorkout(id:) calls.
    func fetchAllWorkoutTimestamps() -> [UUID: Date] {
        let descriptor = FetchDescriptor<PersistedWorkout>()
        do {
            let results = try context.fetch(descriptor)
            return Dictionary(uniqueKeysWithValues: results.map { ($0.workoutId, $0.updatedAt) })
        } catch {
            #if DEBUG
            print("PersistenceService: Error fetching workout timestamps: \(error)")
            #endif
            return [:]
        }
    }

    /// Batch fetch: all persisted daily context dates (normalized to start-of-day).
    /// Used by sync service to avoid N individual fetchDailyContext(for:) calls.
    func fetchAllContextDates() -> Set<Date> {
        let descriptor = FetchDescriptor<PersistedDailyContext>()
        do {
            let results = try context.fetch(descriptor)
            let cal = Calendar.current
            return Set(results.map { cal.startOfDay(for: $0.date) })
        } catch {
            #if DEBUG
            print("PersistenceService: Error fetching context dates: \(error)")
            #endif
            return []
        }
    }

    /// Merge a cloud-sourced DailyContext into local store.
    /// - Finds the local record for the same calendar day (if any).
    /// - If found: fills in nil/zero local fields from cloud values; never overwrites existing local data.
    /// - If not found: inserts the cloud record directly.
    /// - Returns `true` if merged into existing, `false` if a new record was created.
    @discardableResult
    func mergeCloudDailyContext(_ cloudContext: DailyContext) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: cloudContext.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<PersistedDailyContext>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            if let existing = results.first {
                // Only fill in fields that are missing locally
                if existing.sleepHours == 0, cloudContext.sleepHours > 0 {
                    existing.sleepHours = cloudContext.sleepHours
                }
                if existing.waterIntakeMl == nil, let v = cloudContext.waterIntakeMl { existing.waterIntakeMl = v }
                if existing.weightKg == nil, let v = cloudContext.weightKg { existing.weightKg = v }
                if existing.bodyFatPercentage == nil, let v = cloudContext.bodyFatPercentage { existing.bodyFatPercentage = v }
                if existing.calories == nil, let v = cloudContext.calories { existing.calories = v }
                if existing.proteinGrams == nil, let v = cloudContext.proteinGrams { existing.proteinGrams = v }
                if existing.carbsGrams == nil, let v = cloudContext.carbsGrams { existing.carbsGrams = v }
                if existing.fatGrams == nil, let v = cloudContext.fatGrams { existing.fatGrams = v }
                if existing.restingHeartRate == nil, let v = cloudContext.restingHeartRate { existing.restingHeartRate = v }
                if existing.hrvScore == nil, let v = cloudContext.hrvScore { existing.hrvScore = v }
                existing.updatedAt = Date()

                try context.save()
                #if DEBUG
                print("📊 PersistenceService: ↔ Merged cloud context date=\(startOfDay) water=\(cloudContext.waterIntakeMl?.description ?? "nil")ml sleep=\(cloudContext.sleepHours)h weight=\(cloudContext.weightKg?.description ?? "nil")kg")
                #endif
                return true
            } else {
                let persisted = PersistedDailyContext(from: cloudContext)
                context.insert(persisted)
                try context.save()
                #if DEBUG
                print("📊 PersistenceService: ✚ Inserted cloud context date=\(startOfDay) water=\(cloudContext.waterIntakeMl?.description ?? "nil")ml sleep=\(cloudContext.sleepHours)h weight=\(cloudContext.weightKg?.description ?? "nil")kg")
                #endif
                return false
            }
        } catch {
            #if DEBUG
            print("📊 PersistenceService: ❌ mergeCloudDailyContext failed: \(error)")
            #endif
            return false
        }
    }

    /// Batch fetch: all persisted check-in IDs.
    /// Used by sync service to avoid N individual fetchCheckIn(id:) calls.
    func fetchAllCheckInIds() -> Set<UUID> {
        let descriptor = FetchDescriptor<PersistedCheckIn>()
        do {
            let results = try context.fetch(descriptor)
            return Set(results.map { $0.checkInId })
        } catch {
            #if DEBUG
            print("PersistenceService: Error fetching check-in IDs: \(error)")
            #endif
            return []
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
            #if DEBUG
            print("PersistenceService: Error fetching post-workout check-ins: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error fetching recoveries: \(error)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error counting workouts: \(error)")
            #endif
            return 0
        }
    }

    /// Calculate current workout streak (consecutive days)
    func calculateCurrentStreak() -> Int {
        #if DEBUG
        print("📈 [TRACE 7] calculateCurrentStreak() START")
        #endif

        var descriptor = FetchDescriptor<PersistedWorkout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 30 // Look back up to 30 days

        do {
            let results = try context.fetch(descriptor)
            #if DEBUG
            print("📈 [STREAK] Recomputing streak from \(results.count) local workouts (most recent 30)")
            if let first = results.first {
                print("📈 [STREAK] Most recent workout: \(first.startDate)")
            }
            #endif
            guard !results.isEmpty else {
                #if DEBUG
                print("📈 [TRACE 7] calculateCurrentStreak() — no workouts, returning 0")
                #endif
                return 0
            }

            let calendar = Calendar.current
            var streak = 0
            var currentDate = calendar.startOfDay(for: Date())

            // Group workouts by day
            let workoutDays = Set(results.map { calendar.startOfDay(for: $0.startDate) })

            #if DEBUG
            print("📈 [TRACE 7] unique workout days in set: \(workoutDays.count), today=\(currentDate)")
            #endif

            // Check if there's a workout today or yesterday
            let initialYesterday = calendar.date(byAdding: .day, value: -1, to: currentDate)!

            if !workoutDays.contains(currentDate) && !workoutDays.contains(initialYesterday) {
                #if DEBUG
                print("📈 [TRACE 7] calculateCurrentStreak() — no workout today or yesterday, returning 0")
                #endif
                return 0 // Streak broken
            }

            // FIX: if today has no workout, start counting from yesterday
            if !workoutDays.contains(currentDate) {
                currentDate = initialYesterday
            }

            #if DEBUG
            print("📈 [TRACE 7] entering streak loop, startDate=\(currentDate)")
            #endif

            // Count consecutive workout days backwards from currentDate.
            // FIX: loop condition checks only currentDate (not a fixed 'yesterday') so it
            // exits as soon as a gap is found. Previous code captured 'yesterday' before the
            // loop and never updated it, causing an infinite loop when yesterday was in the set.
            var loopIteration = 0
            while workoutDays.contains(currentDate) {
                loopIteration += 1
                streak += 1
                #if DEBUG
                if loopIteration <= 35 {
                    print("📈 [TRACE 7] loop iter \(loopIteration): currentDate=\(currentDate) streak=\(streak)")
                }
                #endif
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                if streak > 30 { break } // Safety cap matching fetch limit
            }

            #if DEBUG
            print("📈 [TRACE 7] calculateCurrentStreak() END — streak=\(streak) after \(loopIteration) iterations")
            #endif
            return streak
        } catch {
            #if DEBUG
            print("📈 [TRACE 7] calculateCurrentStreak() ERROR: \(error.localizedDescription)")
            #endif
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
            #if DEBUG
            print("PersistenceService: Error calculating longest streak: \(error)")
            #endif
            return 0
        }
    }

    /// Check if user has checked in for a workout
    func hasCheckedIn(for workoutId: UUID) -> Bool {
        return fetchPostWorkoutCheckIn(for: workoutId) != nil
    }

    /// Calculate weekly weight delta (current - week ago)
    func calculateWeeklyWeightDelta() -> Double? {
        let calendar = Calendar.current
        let now = Date()

        // Get today's weight
        guard let todayContext = fetchTodayDailyContext(),
              let currentWeight = todayContext.weightKg,
              currentWeight > 0 else {
            return nil
        }

        // Get weight from ~7 days ago
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        // Find daily context from around a week ago (within 2 days tolerance)
        var descriptor = FetchDescriptor<PersistedDailyContext>(
            predicate: #Predicate<PersistedDailyContext> { context in
                context.weightKg != nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 14 // Look at last 2 weeks of entries

        do {
            let contexts = try container.mainContext.fetch(descriptor)

            // Find entry closest to a week ago
            for context in contexts {
                let daysDiff = abs(calendar.dateComponents([.day], from: weekAgo, to: context.date).day ?? 0)
                if daysDiff <= 2, let w = context.weightKg, w > 0 {
                    return currentWeight - w
                }
            }
            return nil
        } catch {
            #if DEBUG
            print("PersistenceService: Error calculating weekly weight delta: \(error)")
            #endif
            return nil
        }
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
        #if DEBUG
        print("🗑️ PersistenceService: Clearing all data...")
        #endif

        do {
            // Delete all workouts
            let workoutDescriptor = FetchDescriptor<PersistedWorkout>()
            let workouts = try context.fetch(workoutDescriptor)
            for workout in workouts {
                context.delete(workout)
            }
            #if DEBUG
            print("🗑️ PersistenceService: Deleted \(workouts.count) workouts")
            #endif

            // Delete all daily contexts
            let contextDescriptor = FetchDescriptor<PersistedDailyContext>()
            let contexts = try context.fetch(contextDescriptor)
            for ctx in contexts {
                context.delete(ctx)
            }
            #if DEBUG
            print("🗑️ PersistenceService: Deleted \(contexts.count) daily contexts")
            #endif

            // Delete all post-workout check-ins
            let checkInDescriptor = FetchDescriptor<PersistedPostWorkoutCheckIn>()
            let checkIns = try context.fetch(checkInDescriptor)
            for checkIn in checkIns {
                context.delete(checkIn)
            }
            #if DEBUG
            print("🗑️ PersistenceService: Deleted \(checkIns.count) check-ins")
            #endif

            // Delete all next-day recoveries
            let recoveryDescriptor = FetchDescriptor<PersistedNextDayRecovery>()
            let recoveries = try context.fetch(recoveryDescriptor)
            for recovery in recoveries {
                context.delete(recovery)
            }
            #if DEBUG
            print("🗑️ PersistenceService: Deleted \(recoveries.count) recoveries")
            #endif

            // Delete all check-ins
            let checkInBaseDescriptor = FetchDescriptor<PersistedCheckIn>()
            let checkInBases = try context.fetch(checkInBaseDescriptor)
            for checkIn in checkInBases {
                context.delete(checkIn)
            }
            #if DEBUG
            print("🗑️ PersistenceService: Deleted \(checkInBases.count) base check-ins")
            #endif

            // Save changes
            try context.save()
            #if DEBUG
            print("🗑️ PersistenceService: ✅ All data cleared successfully")
            #endif

        } catch {
            #if DEBUG
            print("🗑️ PersistenceService: ❌ Error clearing data: \(error)")
            #endif
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
