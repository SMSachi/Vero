//
//  SupabaseSyncService.swift
//  Insio Health
//
//  Cloud sync for local-first data architecture.
//  Syncs: workouts, daily_contexts, check_ins
//
//  ARCHITECTURE:
//  - All writes go to local storage first (PersistenceService)
//  - Sync service then pushes to Supabase
//  - On login/app start, pulls from Supabase and merges
//  - App works offline - sync failures don't break UI
//

import Foundation
import Supabase

// MARK: - Sync Service

@MainActor
final class SupabaseSyncService: ObservableObject {

    // MARK: - Singleton

    static let shared = SupabaseSyncService()

    // MARK: - Published State

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published var syncError: String?
    @Published private(set) var pendingSyncCount = 0

    // MARK: - Dependencies

    private let persistenceService = PersistenceService.shared
    private let authService = AuthService.shared
    private var supabase: SupabaseClient { SupabaseConfig.client }

    // MARK: - Initialization

    private init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        #if DEBUG
        print("☁️ SyncService: Initialized")
        #endif
    }

    // MARK: - Full Sync

    /// Perform a full sync: push local → pull remote → merge
    func performFullSync() async {
        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("☁️ SyncService: ❌ Cannot sync - user not authenticated")
            #endif
            syncError = "Please sign in to sync"
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("☁️ SyncService: ❌ Supabase not configured")
            #endif
            syncError = "Cloud sync not configured"
            return
        }

        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════")
        #endif
        #if DEBUG
        print("☁️ SyncService: FULL SYNC STARTED")
        #endif
        #if DEBUG
        print("☁️ SyncService: User: \(userId)")
        #endif
        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════")
        #endif

        isSyncing = true
        syncError = nil

        do {
            // Step 1: Push local data to cloud
            #if DEBUG
            print("☁️ SyncService: 📤 PHASE 1: Pushing local data to cloud...")
            #endif
            try await pushWorkouts(userId: userId)
            try await pushDailyContexts(userId: userId)
            try await pushCheckIns(userId: userId)

            // Step 2: Pull cloud data and merge with local
            #if DEBUG
            print("☁️ SyncService: 📥 PHASE 2: Pulling cloud data...")
            #endif
            try await pullWorkouts(userId: userId)
            try await pullDailyContexts(userId: userId)
            try await pullCheckIns(userId: userId)

            // Step 3: Update sync timestamp
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")

            // Step 4: Verify sync completed successfully
            let verification = await verifySyncStatus()

            isSyncing = false
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif
            #if DEBUG
            print("☁️ SyncService: ✅ FULL SYNC COMPLETE")
            #endif
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif
            #if DEBUG
            print("☁️ SyncService: SYNC SUMMARY:")
            #endif
            #if DEBUG
            print("☁️ SyncService:   Workouts: \(verification.localWorkoutCount) local → \(verification.cloudWorkoutCount) cloud")
            #endif
            #if DEBUG
            print("☁️ SyncService:   Contexts: \(verification.localDailyContextCount) local → \(verification.cloudDailyContextCount) cloud")
            #endif
            #if DEBUG
            print("☁️ SyncService:   Check-ins: \(verification.localCheckInCount) local → \(verification.cloudCheckInCount) cloud")
            #endif
            #if DEBUG
            print("☁️ SyncService:   Status: \(verification.summary)")
            #endif
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif

        } catch {
            isSyncing = false
            syncError = "Sync failed: \(error.localizedDescription)"
            #if DEBUG
            print("☁️ SyncService: ❌ SYNC FAILED: \(error)")
            #endif
            // App continues to work with local data
        }
    }

    // MARK: - Data Restore (On Login)

    /// Restore user data from cloud on login
    /// IMPORTANT: This is called from a detached task - must not block UI
    func restoreUserData() async {
        #if DEBUG
        print("☁️ SyncService: restoreUserData() - entered")
        #endif

        // CRITICAL: Yield immediately to allow UI to render first
        // This ensures MainTabView appears before we do heavy work
        await Task.yield()
        #if DEBUG
        print("☁️ SyncService: restoreUserData() - yielded to main thread")
        #endif

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("☁️ SyncService: ❌ Cannot restore - not authenticated")
            #endif
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("☁️ SyncService: ⚠️ Supabase not configured, skipping restore")
            #endif
            return
        }

        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════")
        #endif
        #if DEBUG
        print("☁️ SyncService: DATA RESTORE STARTED (login)")
        #endif
        #if DEBUG
        print("☁️ SyncService: User ID: \(userId)")
        #endif
        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════")
        #endif

        isSyncing = true
        syncError = nil

        do {
            #if DEBUG
            let t0 = Date()
            print("☁️ [9] restoreUserData: Step 1/3 — pullWorkouts START")
            #endif
            try await pullWorkouts(userId: userId)
            #if DEBUG
            print("☁️ [9] restoreUserData: Step 1/3 — pullWorkouts DONE (\(String(format: "%.2f", Date().timeIntervalSince(t0)))s)")
            print("☁️ [9] restoreUserData: Step 2/3 — pullDailyContexts START")
            #endif
            try await pullDailyContexts(userId: userId)
            #if DEBUG
            print("☁️ [9] restoreUserData: Step 2/3 — pullDailyContexts DONE (\(String(format: "%.2f", Date().timeIntervalSince(t0)))s)")
            print("☁️ [9] restoreUserData: Step 3/3 — pullCheckIns START")
            #endif
            try await pullCheckIns(userId: userId)
            #if DEBUG
            print("☁️ [9] restoreUserData: Step 3/3 — pullCheckIns DONE (\(String(format: "%.2f", Date().timeIntervalSince(t0)))s total)")
            #endif

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            isSyncing = false

            // Notify Home and Trends to reload with the freshly-restored user data.
            // Broadcast both workouts AND daily context so sleep/water/weight
            // also refresh after a login restore.
            DataBroadcaster.shared.workoutSaved(id: UUID())
            DataBroadcaster.shared.dailyContextSaved()
            #if DEBUG
            let restoredWorkouts = persistenceService.fetchRecentWorkouts(limit: 500).count
            let restoredContexts = persistenceService.fetchRecentDailyContexts(limit: 100).count
            let restoredCheckIns = persistenceService.fetchRecentCheckIns(limit: 100).count
            print("☁️ SyncService: [RESTORE] ── POST-RESTORE VERIFICATION ──")
            print("☁️ SyncService: [RESTORE]   user_id   : \(userId)")
            print("☁️ SyncService: [RESTORE]   Workouts  : \(restoredWorkouts)")
            print("☁️ SyncService: [RESTORE]   Contexts  : \(restoredContexts)")
            print("☁️ SyncService: [RESTORE]   Check-ins : \(restoredCheckIns)")
            if restoredWorkouts == 0 && restoredContexts == 0 {
                print("☁️ SyncService: [RESTORE]   ⚠️ All counts are zero — new account or cloud is empty for this user")
            }
            #endif

            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif
            #if DEBUG
            print("☁️ SyncService: ✅ DATA RESTORE COMPLETE")
            #endif
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif

        } catch {
            isSyncing = false
            syncError = "Restore failed: \(error.localizedDescription)"
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif
            #if DEBUG
            print("☁️ SyncService: ❌ RESTORE FAILED: \(error)")
            #endif
            #if DEBUG
            print("☁️ SyncService: App continues with local data")
            #endif
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════")
            #endif
            // App continues with local data - non-blocking failure
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - WORKOUTS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local workouts to Supabase
    private func pushWorkouts(userId: UUID) async throws {
        let localWorkouts = persistenceService.fetchRecentWorkouts(limit: 500)
        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] Found \(localWorkouts.count) local workouts to push")
        #endif
        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] User ID for insert: \(userId)")
        #endif

        guard !localWorkouts.isEmpty else {
            #if DEBUG
            print("☁️ SyncService: [WORKOUTS] Nothing to push")
            #endif
            return
        }

        var successCount = 0
        var failCount = 0

        for workout in localWorkouts {
            let record = WorkoutSyncRecord(from: workout, userId: userId)

            do {
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] 📤 Pushing workout \(workout.id)...")
                #endif

                try await supabase
                    .from("workouts")
                    .upsert(record, onConflict: "id")
                    .execute()

                successCount += 1
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] ✅ Pushed: \(workout.id) (\(workout.type.rawValue))")
                #endif

            } catch {
                failCount += 1
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] ❌ Failed to push \(workout.id)")
                #endif
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] Error Type: \(type(of: error))")
                #endif
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] Error: \(error)")
                #endif
                #if DEBUG
                print("☁️ SyncService: [WORKOUTS] Localized: \(error.localizedDescription)")
                #endif

                // Log full error details for RLS debugging
                let errorString = String(describing: error)
                if errorString.contains("permission") || errorString.contains("policy") ||
                   errorString.contains("RLS") || errorString.contains("denied") {
                    #if DEBUG
                    print("☁️ SyncService: [WORKOUTS] ⚠️ This looks like an RLS policy error!")
                    #endif
                }
                // Continue with other workouts - don't fail entire sync
            }
        }

        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] Push complete - Success: \(successCount), Failed: \(failCount)")
        #endif
    }

    /// Pull workouts from Supabase and merge with local
    private func pullWorkouts(userId: UUID) async throws {
        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] Fetching from cloud...")
        #endif

        let records: [WorkoutSyncRecord]
        do {
            records = try await supabase
                .from("workouts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("start_date", ascending: false)
                .execute()
                .value
        } catch {
            #if DEBUG
            print("☁️ SyncService: [WORKOUTS] ❌ Fetch failed: \(error.localizedDescription)")
            #endif
            throw error
        }

        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] 📥 Received \(records.count) workouts from cloud")
        #endif

        // Batch-fetch all local timestamps in ONE @MainActor hop instead of N individual lookups
        let localTimestamps = persistenceService.fetchAllWorkoutTimestamps()

        var newCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for record in records {
            let workout = record.toWorkout()

            if let localUpdated = localTimestamps[workout.id] {
                // Compare timestamps - cloud wins if newer
                let cloudUpdated = record.updatedAt ?? record.createdAt
                if cloudUpdated > localUpdated {
                    persistenceService.saveWorkout(workout)
                    updatedCount += 1
                } else {
                    skippedCount += 1
                }
            } else {
                // New workout from cloud - add locally
                persistenceService.saveWorkout(workout)
                newCount += 1
            }
        }

        #if DEBUG
        print("☁️ SyncService: [WORKOUTS] Merge complete - New: \(newCount), Updated: \(updatedCount), Skipped: \(skippedCount)")
        #endif
    }

    /// Sync a single workout (called after local save)
    func syncWorkout(_ workout: Workout) async {
        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("☁️ SyncService: SYNC WORKOUT ATTEMPT")
        #endif
        #if DEBUG
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("☁️ SyncService: Workout ID: \(workout.id)")
        #endif
        #if DEBUG
        print("☁️ SyncService: Workout Type: \(workout.type.rawValue)")
        #endif
        #if DEBUG
        print("☁️ SyncService: Auth State: isAuthenticated=\(authService.isAuthenticated)")
        #endif
        #if DEBUG
        print("☁️ SyncService: User ID: \(authService.userId?.uuidString ?? "NIL")")
        #endif
        #if DEBUG
        print("☁️ SyncService: Supabase Configured: \(SupabaseConfig.isConfigured)")
        #endif

        guard authService.isAuthenticated else {
            #if DEBUG
            print("☁️ SyncService: ❌ ABORT - User not authenticated")
            #endif
            return
        }

        guard let userId = authService.userId else {
            #if DEBUG
            print("☁️ SyncService: ❌ ABORT - User ID is nil despite being authenticated")
            #endif
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("☁️ SyncService: ❌ ABORT - Supabase not configured")
            #endif
            return
        }

        // Create the sync record
        let record = WorkoutSyncRecord(from: workout, userId: userId)

        // Log the payload
        #if DEBUG
        print("☁️ SyncService: ──────────────────────────────────────────────────")
        #endif
        #if DEBUG
        print("☁️ SyncService: PAYLOAD TO UPLOAD:")
        #endif
        #if DEBUG
        print("☁️ SyncService: Table: workouts")
        #endif
        #if DEBUG
        print("☁️ SyncService: id: \(record.id)")
        #endif
        #if DEBUG
        print("☁️ SyncService: user_id: \(record.userId)")
        #endif
        #if DEBUG
        print("☁️ SyncService: type: \(record.type)")
        #endif
        #if DEBUG
        print("☁️ SyncService: start_date: \(record.startDate)")
        #endif
        #if DEBUG
        print("☁️ SyncService: end_date: \(record.endDate)")
        #endif
        #if DEBUG
        print("☁️ SyncService: duration: \(record.duration)")
        #endif
        #if DEBUG
        print("☁️ SyncService: calories: \(record.calories)")
        #endif
        #if DEBUG
        print("☁️ SyncService: intensity: \(record.intensity)")
        #endif
        #if DEBUG
        print("☁️ SyncService: average_heart_rate: \(record.averageHeartRate?.description ?? "nil")")
        #endif
        #if DEBUG
        print("☁️ SyncService: max_heart_rate: \(record.maxHeartRate?.description ?? "nil")")
        #endif
        #if DEBUG
        print("☁️ SyncService: created_at: \(record.createdAt)")
        #endif
        #if DEBUG
        print("☁️ SyncService: NOTE: updated_at is handled by Supabase trigger, not sent from client")
        #endif

        // Print actual JSON payload for debugging
        record.debugPrintJSON()
        #if DEBUG
        print("☁️ SyncService: ──────────────────────────────────────────────────")
        #endif

        do {
            #if DEBUG
            print("☁️ SyncService: 🚀 Sending upsert request to Supabase...")
            #endif

            try await supabase
                .from("workouts")
                .upsert(record, onConflict: "id")
                .execute()

            #if DEBUG
            print("☁️ SyncService: ✅ SUCCESS - Workout synced to Supabase")
            #endif

            // Verify the sync by reading back the record
            let verifyRecords: [WorkoutSyncRecord] = try await supabase
                .from("workouts")
                .select()
                .eq("id", value: workout.id.uuidString)
                .execute()
                .value

            if verifyRecords.count == 1 {
                #if DEBUG
                print("☁️ SyncService: 🔍 VERIFIED - Workout confirmed in Supabase")
                #endif
            } else {
                #if DEBUG
                print("☁️ SyncService: ⚠️ VERIFY WARNING - Could not confirm workout in Supabase")
                #endif
            }

            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════════════════")
            #endif

        } catch {
            #if DEBUG
            print("☁️ SyncService: ❌ SYNC FAILED")
            #endif
            #if DEBUG
            print("☁️ SyncService: Error Type: \(type(of: error))")
            #endif
            #if DEBUG
            print("☁️ SyncService: Error Description: \(error.localizedDescription)")
            #endif
            #if DEBUG
            print("☁️ SyncService: Full Error: \(error)")
            #endif

            // Try to extract more details from the error
            if let nsError = error as NSError? {
                #if DEBUG
                print("☁️ SyncService: NSError Domain: \(nsError.domain)")
                #endif
                #if DEBUG
                print("☁️ SyncService: NSError Code: \(nsError.code)")
                #endif
                #if DEBUG
                print("☁️ SyncService: NSError UserInfo: \(nsError.userInfo)")
                #endif
            }

            // Log the raw error string for debugging
            let errorString = String(describing: error)
            #if DEBUG
            print("☁️ SyncService: Raw Error String: \(errorString)")
            #endif
            #if DEBUG
            print("☁️ SyncService: ══════════════════════════════════════════════════")
            #endif

            // Don't throw - local data is safe, sync will retry on next full sync
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - DAILY CONTEXTS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local daily contexts to Supabase
    private func pushDailyContexts(userId: UUID) async throws {
        let contexts = persistenceService.fetchRecentDailyContexts(limit: 100)
        #if DEBUG
        print("☁️ SyncService: [DAILY_CONTEXTS] Found \(contexts.count) local contexts")
        #endif

        guard !contexts.isEmpty else {
            #if DEBUG
            print("☁️ SyncService: [DAILY_CONTEXTS] Nothing to push")
            #endif
            return
        }

        var successCount = 0
        var failCount = 0

        for context in contexts {
            do {
                let record = DailyContextSyncRecord(from: context, userId: userId)

                try await supabase
                    .from("daily_contexts")
                    .upsert(record, onConflict: "id")
                    .execute()

                successCount += 1
                #if DEBUG
                print("☁️ SyncService: [DAILY_CONTEXTS] ✅ Pushed: \(context.id)")
                #endif

            } catch {
                failCount += 1
                #if DEBUG
                print("☁️ SyncService: [DAILY_CONTEXTS] ⚠️ Failed: \(context.id): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("☁️ SyncService: [DAILY_CONTEXTS] Push complete - Success: \(successCount), Failed: \(failCount)")
        #endif
    }

    /// Pull daily contexts from Supabase and merge
    private func pullDailyContexts(userId: UUID) async throws {
        #if DEBUG
        print("☁️ SyncService: [DAILY_CONTEXTS] Fetching from cloud...")
        #endif

        let records: [DailyContextSyncRecord]
        do {
            records = try await supabase
                .from("daily_contexts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value
        } catch {
            #if DEBUG
            print("☁️ SyncService: [DAILY_CONTEXTS] ❌ Fetch failed: \(error.localizedDescription)")
            #endif
            throw error
        }

        #if DEBUG
        print("☁️ SyncService: [DAILY_CONTEXTS] 📥 Received \(records.count) contexts from cloud")
        #endif

        // Batch-fetch all local context dates in ONE @MainActor hop
        let localDates = persistenceService.fetchAllContextDates()
        let cal = Calendar.current

        var newCount = 0
        var skippedCount = 0

        for record in records {
            let context = record.toDailyContext()

            if localDates.contains(cal.startOfDay(for: context.date)) {
                skippedCount += 1
            } else {
                persistenceService.saveDailyContext(context)
                newCount += 1
            }
        }

        #if DEBUG
        print("☁️ SyncService: [DAILY_CONTEXTS] Merge complete - New: \(newCount), Skipped: \(skippedCount)")
        #endif
    }

    /// Sync a single daily context
    func syncDailyContext(_ context: DailyContext) async {
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: Context ID: \(context.id)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: Date: \(context.date)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: isAuthenticated = \(authService.isAuthenticated)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: userId = \(authService.userId?.uuidString ?? "NIL")")
        #endif

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("📊 DAILY_CONTEXT SYNC ERROR: Not authenticated - cannot sync")
            #endif
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("📊 DAILY_CONTEXT SYNC ERROR: Supabase not configured")
            #endif
            return
        }

        let record = DailyContextSyncRecord(from: context, userId: userId)

        // Log EXACT payload being sent
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: ──────────────────────────────────────")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: TABLE NAME: \"daily_contexts\"")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: PAYLOAD:")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   id = \(record.id)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   user_id = \(record.userId)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   date = \(record.date)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   sleep_hours = \(record.sleepHours?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   sleep_quality = \(record.sleepQuality ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   water_ml = \(record.waterMl?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   calories = \(record.calories?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   protein_grams = \(record.proteinGrams?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   carbs_grams = \(record.carbsGrams?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   weight_kg = \(record.weightKg?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   body_fat_percentage = \(record.bodyFatPercentage?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   stress_level = \(record.stressLevel ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   energy_level = \(record.energyLevel ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   readiness_score = \(record.readinessScore?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   hrv_score = \(record.hrvScore?.description ?? "nil")")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC:   created_at = \(record.createdAt)")
        #endif
        #if DEBUG
        print("📊 DAILY_CONTEXT SYNC: ──────────────────────────────────────")
        #endif

        do {
            #if DEBUG
            print("📊 DAILY_CONTEXT SYNC: Sending upsert to Supabase table \"daily_contexts\"...")
            print("📊 DAILY_CONTEXT SYNC: date field sent as: \"\(record.date)\" (YYYY-MM-DD string)")
            #endif

            try await supabase
                .from("daily_contexts")
                .upsert(record, onConflict: "id")
                .execute()

            #if DEBUG
            print("📊 DAILY_CONTEXT SYNC SUCCESS ✅")
            print("📊 DAILY_CONTEXT SYNC: Row should now appear in Supabase daily_contexts table")
            print("📊 DAILY_CONTEXT SYNC ══════════════════════════════════════════════════")
            #endif

        } catch {
            let errorString = String(describing: error)
            // Surface the error to the UI so it is not silently swallowed
            syncError = "daily_context sync failed: \(error.localizedDescription)"
            #if DEBUG
            print("📊 DAILY_CONTEXT SYNC ERROR ❌")
            print("📊 DAILY_CONTEXT SYNC ERROR TYPE     : \(type(of: error))")
            print("📊 DAILY_CONTEXT SYNC ERROR LOCALIZED: \(error.localizedDescription)")
            print("📊 DAILY_CONTEXT SYNC ERROR FULL     : \(errorString)")
            print("📊 DAILY_CONTEXT SYNC: If this is an RLS error, ensure the daily_contexts")
            print("📊 DAILY_CONTEXT SYNC: table has INSERT/UPDATE policies for authenticated users.")
            print("📊 DAILY_CONTEXT SYNC ══════════════════════════════════════════════════")
            #endif
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - CHECK-INS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local check-ins to Supabase
    private func pushCheckIns(userId: UUID) async throws {
        let checkIns = persistenceService.fetchRecentCheckIns(limit: 100)
        #if DEBUG
        print("☁️ SyncService: [CHECK_INS] Found \(checkIns.count) local check-ins")
        #endif

        guard !checkIns.isEmpty else {
            #if DEBUG
            print("☁️ SyncService: [CHECK_INS] Nothing to push")
            #endif
            return
        }

        var successCount = 0
        var failCount = 0

        for checkIn in checkIns {
            do {
                let record = CheckInSyncRecord(from: checkIn, userId: userId)

                try await supabase
                    .from("check_ins")
                    .upsert(record, onConflict: "id")
                    .execute()

                successCount += 1
                #if DEBUG
                print("☁️ SyncService: [CHECK_INS] ✅ Pushed: \(checkIn.id)")
                #endif

            } catch {
                failCount += 1
                #if DEBUG
                print("☁️ SyncService: [CHECK_INS] ⚠️ Failed: \(checkIn.id): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("☁️ SyncService: [CHECK_INS] Push complete - Success: \(successCount), Failed: \(failCount)")
        #endif
    }

    /// Pull check-ins from Supabase and merge
    private func pullCheckIns(userId: UUID) async throws {
        #if DEBUG
        print("☁️ SyncService: [CHECK_INS] Fetching from cloud...")
        #endif

        let records: [CheckInSyncRecord]
        do {
            records = try await supabase
                .from("check_ins")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value
        } catch {
            #if DEBUG
            print("☁️ SyncService: [CHECK_INS] ❌ Fetch failed: \(error.localizedDescription)")
            #endif
            throw error
        }

        #if DEBUG
        print("☁️ SyncService: [CHECK_INS] 📥 Received \(records.count) check-ins from cloud")
        #endif

        // Batch-fetch all local check-in IDs in ONE @MainActor hop
        let localIds = persistenceService.fetchAllCheckInIds()

        var newCount = 0
        var skippedCount = 0

        for record in records {
            let checkIn = record.toCheckIn()

            if localIds.contains(checkIn.id) {
                skippedCount += 1
            } else {
                persistenceService.saveCheckIn(checkIn)
                newCount += 1
            }
        }

        #if DEBUG
        print("☁️ SyncService: [CHECK_INS] Merge complete - New: \(newCount), Skipped: \(skippedCount)")
        #endif
    }

    /// Sync a single check-in
    func syncCheckIn(_ checkIn: CheckIn) async {
        #if DEBUG
        print("📋 CHECK_IN SYNC ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: Check-in ID: \(checkIn.id)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: Date: \(checkIn.date)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: isAuthenticated = \(authService.isAuthenticated)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: userId = \(authService.userId?.uuidString ?? "NIL")")
        #endif

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("📋 CHECK_IN SYNC ERROR: Not authenticated - cannot sync")
            #endif
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("📋 CHECK_IN SYNC ERROR: Supabase not configured")
            #endif
            return
        }

        let record = CheckInSyncRecord(from: checkIn, userId: userId)

        // Log EXACT payload being sent
        #if DEBUG
        print("📋 CHECK_IN SYNC: ──────────────────────────────────────")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: TABLE NAME: \"check_ins\"")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: PAYLOAD:")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   id = \(record.id)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   user_id = \(record.userId)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   date = \(record.date)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   mood = \(record.mood)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   energy_level = \(record.energyLevel)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   soreness = \(record.soreness)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   motivation = \(record.motivation)")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC:   notes = \(record.notes ?? "nil")")
        #endif
        #if DEBUG
        print("📋 CHECK_IN SYNC: ──────────────────────────────────────")
        #endif

        do {
            #if DEBUG
            print("📋 CHECK_IN SYNC: Sending upsert to Supabase table \"check_ins\"...")
            print("📋 CHECK_IN SYNC: date field sent as: \"\(record.date)\" (YYYY-MM-DD string)")
            print("📋 CHECK_IN SYNC: updated_at NOT sent — Supabase trigger manages it")
            #endif

            try await supabase
                .from("check_ins")
                .upsert(record, onConflict: "id")
                .execute()

            #if DEBUG
            print("📋 CHECK_IN SYNC SUCCESS ✅")
            print("📋 CHECK_IN SYNC: Row should now appear in Supabase check_ins table")
            print("📋 CHECK_IN SYNC ══════════════════════════════════════════════════")
            #endif

        } catch {
            let errorString = String(describing: error)
            // Surface the error to the UI so it is not silently swallowed
            syncError = "check_in sync failed: \(error.localizedDescription)"
            #if DEBUG
            print("📋 CHECK_IN SYNC ERROR ❌")
            print("📋 CHECK_IN SYNC ERROR TYPE     : \(type(of: error))")
            print("📋 CHECK_IN SYNC ERROR LOCALIZED: \(error.localizedDescription)")
            print("📋 CHECK_IN SYNC ERROR FULL     : \(errorString)")
            print("📋 CHECK_IN SYNC: If this is an RLS error, ensure the check_ins")
            print("📋 CHECK_IN SYNC: table has INSERT/UPDATE policies for authenticated users.")
            print("📋 CHECK_IN SYNC ══════════════════════════════════════════════════")
            #endif
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - POST-WORKOUT CHECK-INS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Sync a post-workout check-in
    func syncPostWorkoutCheckIn(workoutId: UUID, feeling: String, note: String?) async {
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: Workout ID: \(workoutId)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: Feeling: \(feeling)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: Note: \(note ?? "nil")")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: isAuthenticated = \(authService.isAuthenticated)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: userId = \(authService.userId?.uuidString ?? "NIL")")
        #endif

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR: Not authenticated - cannot sync")
            #endif
            return
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR: Supabase not configured")
            #endif
            return
        }

        let record = PostWorkoutCheckInSyncRecord(
            id: UUID(),
            workoutId: workoutId,
            userId: userId,
            feeling: feeling,
            note: note
        )

        // Log EXACT payload being sent
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: ──────────────────────────────────────")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: TABLE NAME: \"post_workout_check_ins\"")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: PAYLOAD:")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   id = \(record.id)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   workout_id = \(record.workoutId)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   user_id = \(record.userId)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   feeling = \(record.feeling)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   note = \(record.note ?? "nil")")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   date = \(record.date)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC:   created_at = \(record.createdAt)")
        #endif
        #if DEBUG
        print("💪 POST_WORKOUT_CHECK_IN SYNC: ──────────────────────────────────────")
        #endif

        do {
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC: Sending insert to Supabase table \"post_workout_check_ins\"...")
            #endif

            try await supabase
                .from("post_workout_check_ins")
                .insert(record)
                .execute()

            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC SUCCESS")
            #endif
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC: Row should now appear in Supabase post_workout_check_ins table")
            #endif
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ══════════════════════════════════════════════════")
            #endif

        } catch {
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR: \(error)")
            #endif
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR TYPE: \(type(of: error))")
            #endif
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR LOCALIZED: \(error.localizedDescription)")
            #endif
            let errorString = String(describing: error)
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ERROR FULL: \(errorString)")
            #endif
            #if DEBUG
            print("💪 POST_WORKOUT_CHECK_IN SYNC ══════════════════════════════════════════════════")
            #endif
        }
    }

    // MARK: - Sync Verification

    /// Verify that data has been successfully synced to Supabase
    /// This reads back from the cloud to confirm data was saved
    func verifySyncStatus() async -> SyncVerificationResult {
        guard authService.isAuthenticated,
              let userId = authService.userId else {
            #if DEBUG
            print("🔍 SyncVerify: ❌ Not authenticated")
            #endif
            return SyncVerificationResult(isAuthenticated: false)
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("🔍 SyncVerify: ❌ Supabase not configured")
            #endif
            return SyncVerificationResult(isAuthenticated: true, isConfigured: false)
        }

        #if DEBUG
        print("🔍 SyncVerify: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🔍 SyncVerify: SYNC VERIFICATION STARTED")
        #endif
        #if DEBUG
        print("🔍 SyncVerify: User ID: \(userId)")
        #endif
        #if DEBUG
        print("🔍 SyncVerify: ══════════════════════════════════════════════════")
        #endif

        var result = SyncVerificationResult(isAuthenticated: true, isConfigured: true)

        // Count local data
        let localWorkouts = persistenceService.fetchRecentWorkouts(limit: 500)
        let localContexts = persistenceService.fetchRecentDailyContexts(limit: 100)
        let localCheckIns = persistenceService.fetchRecentCheckIns(limit: 100)

        result.localWorkoutCount = localWorkouts.count
        result.localDailyContextCount = localContexts.count
        result.localCheckInCount = localCheckIns.count

        #if DEBUG
        print("🔍 SyncVerify: LOCAL DATA:")
        #endif
        #if DEBUG
        print("🔍 SyncVerify:   Workouts: \(result.localWorkoutCount)")
        #endif
        #if DEBUG
        print("🔍 SyncVerify:   Daily Contexts: \(result.localDailyContextCount)")
        #endif
        #if DEBUG
        print("🔍 SyncVerify:   Check-ins: \(result.localCheckInCount)")
        #endif

        // Count cloud data
        do {
            // Count workouts in cloud
            let cloudWorkouts: [WorkoutSyncRecord] = try await supabase
                .from("workouts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            result.cloudWorkoutCount = cloudWorkouts.count

            // Count daily contexts in cloud
            let cloudContexts: [DailyContextSyncRecord] = try await supabase
                .from("daily_contexts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            result.cloudDailyContextCount = cloudContexts.count

            // Count check-ins in cloud
            let cloudCheckIns: [CheckInSyncRecord] = try await supabase
                .from("check_ins")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            result.cloudCheckInCount = cloudCheckIns.count

            result.verificationSuccess = true

            #if DEBUG
            print("🔍 SyncVerify: CLOUD DATA:")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Workouts: \(result.cloudWorkoutCount)")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Daily Contexts: \(result.cloudDailyContextCount)")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Check-ins: \(result.cloudCheckInCount)")
            #endif

            // Calculate sync status
            let workoutsSynced = result.cloudWorkoutCount >= result.localWorkoutCount
            let contextsSynced = result.cloudDailyContextCount >= result.localDailyContextCount
            let checkInsSynced = result.cloudCheckInCount >= result.localCheckInCount

            #if DEBUG
            print("🔍 SyncVerify: ──────────────────────────────────────────────────")
            #endif
            #if DEBUG
            print("🔍 SyncVerify: SYNC STATUS:")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Workouts: \(workoutsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Daily Contexts: \(contextsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")
            #endif
            #if DEBUG
            print("🔍 SyncVerify:   Check-ins: \(checkInsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")
            #endif

            if workoutsSynced && contextsSynced && checkInsSynced {
                #if DEBUG
                print("🔍 SyncVerify: ✅ ALL DATA VERIFIED IN CLOUD")
                #endif
            } else {
                #if DEBUG
                print("🔍 SyncVerify: ⚠️ Some local data may not be synced yet")
                #endif
                #if DEBUG
                print("🔍 SyncVerify: Run performFullSync() to push pending data")
                #endif
            }

        } catch {
            result.verificationSuccess = false
            result.error = error.localizedDescription
            #if DEBUG
            print("🔍 SyncVerify: ❌ Verification failed: \(error.localizedDescription)")
            #endif
        }

        #if DEBUG
        print("🔍 SyncVerify: ══════════════════════════════════════════════════")
        #endif

        return result
    }

    // MARK: - Clear State (Logout)

    func clearSyncState() {
        lastSyncDate = nil
        syncError = nil
        pendingSyncCount = 0
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        #if DEBUG
        print("☁️ SyncService: State cleared (logout)")
        #endif
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - TIMEOUT-PROTECTED SYNC METHODS
    // ══════════════════════════════════════════════════════════════════════
    //
    // These methods wrap sync operations with timeout protection.
    // If sync takes too long, they abort gracefully without blocking the app.
    // Local data is safe - cloud sync can retry on next full sync.
    //

    /// Sync a single workout with timeout protection
    /// - Parameters:
    ///   - workout: The workout to sync
    ///   - timeout: Maximum seconds to wait (default 15)
    func syncWorkoutWithTimeout(_ workout: Workout, timeout: TimeInterval = 15) async {
        #if DEBUG
        print("☁️ SyncService: [TIMEOUT] syncWorkout starting (timeout: \(timeout)s)")
        #endif

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Add the actual sync task
                group.addTask {
                    await self.syncWorkout(workout)
                }

                // Add a timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SyncTimeoutError.timeout
                }

                // Wait for the first one to complete
                // If sync finishes first, we're good
                // If timeout fires first, we throw and cancel
                do {
                    try await group.next()
                    group.cancelAll() // Cancel the other task
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncWorkout completed within timeout ✅")
                    #endif
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncWorkout TIMED OUT after \(timeout)s ⚠️")
                    #endif
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] Local data is safe - will retry on next full sync")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("☁️ SyncService: [TIMEOUT] syncWorkout error: \(error)")
            #endif
        }
    }

    /// Sync a post-workout check-in with timeout protection
    func syncPostWorkoutCheckInWithTimeout(
        workoutId: UUID,
        feeling: String,
        note: String?,
        timeout: TimeInterval = 10
    ) async {
        #if DEBUG
        print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn starting (timeout: \(timeout)s)")
        #endif

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.syncPostWorkoutCheckIn(workoutId: workoutId, feeling: feeling, note: note)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SyncTimeoutError.timeout
                }

                do {
                    try await group.next()
                    group.cancelAll()
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn completed within timeout ✅")
                    #endif
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn TIMED OUT after \(timeout)s ⚠️")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn error: \(error)")
            #endif
        }
    }

    /// Sync daily context with timeout protection
    func syncDailyContextWithTimeout(_ context: DailyContext, timeout: TimeInterval = 10) async {
        #if DEBUG
        print("☁️ SyncService: [TIMEOUT] syncDailyContext starting (timeout: \(timeout)s)")
        #endif

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.syncDailyContext(context)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SyncTimeoutError.timeout
                }

                do {
                    try await group.next()
                    group.cancelAll()
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncDailyContext completed within timeout ✅")
                    #endif
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    #if DEBUG
                    print("☁️ SyncService: [TIMEOUT] syncDailyContext TIMED OUT after \(timeout)s ⚠️")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("☁️ SyncService: [TIMEOUT] syncDailyContext error: \(error)")
            #endif
        }
    }
}

// MARK: - Sync Timeout Error

enum SyncTimeoutError: Error {
    case timeout
}

// MARK: - Sync Verification Result

/// Result of sync verification check
struct SyncVerificationResult {
    var isAuthenticated = false
    var isConfigured = false
    var verificationSuccess = false
    var error: String?

    var localWorkoutCount = 0
    var cloudWorkoutCount = 0

    var localDailyContextCount = 0
    var cloudDailyContextCount = 0

    var localCheckInCount = 0
    var cloudCheckInCount = 0

    /// Whether all local data appears to be in the cloud
    var isFullySynced: Bool {
        guard verificationSuccess else { return false }
        return cloudWorkoutCount >= localWorkoutCount &&
               cloudDailyContextCount >= localDailyContextCount &&
               cloudCheckInCount >= localCheckInCount
    }

    /// Human-readable summary
    var summary: String {
        if !isAuthenticated { return "Not authenticated" }
        if !isConfigured { return "Supabase not configured" }
        if !verificationSuccess { return "Verification failed: \(error ?? "Unknown error")" }
        if isFullySynced { return "All data synced" }
        return "Some data pending sync"
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - SYNC RECORDS (Codable for Supabase)
// ══════════════════════════════════════════════════════════════════════

/// Workout record for Supabase
/// NOTE: updated_at is handled by Supabase trigger - we don't send it
struct WorkoutSyncRecord: Codable {
    let id: UUID
    let userId: UUID
    let type: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calories: Int
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let intensity: String
    let interpretation: String?
    let distance: Double?
    let elevationGain: Double?
    let perceivedEffort: Int?
    let whatHappened: String?
    let whatItMeans: String?
    let whatToDoNext: String?
    let createdAt: Date
    // NOTE: updatedAt removed from upload - Supabase handles this via trigger
    // We still decode it when pulling from cloud
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case startDate = "start_date"
        case endDate = "end_date"
        case duration
        case calories
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case intensity
        case interpretation
        case distance
        case elevationGain = "elevation_gain"
        case perceivedEffort = "perceived_effort"
        case whatHappened = "what_happened"
        case whatItMeans = "what_it_means"
        case whatToDoNext = "what_to_do_next"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom encode to EXCLUDE updated_at (Supabase handles it)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(type, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(duration, forKey: .duration)
        try container.encode(calories, forKey: .calories)
        try container.encodeIfPresent(averageHeartRate, forKey: .averageHeartRate)
        try container.encodeIfPresent(maxHeartRate, forKey: .maxHeartRate)
        try container.encode(intensity, forKey: .intensity)
        try container.encodeIfPresent(interpretation, forKey: .interpretation)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(elevationGain, forKey: .elevationGain)
        try container.encodeIfPresent(perceivedEffort, forKey: .perceivedEffort)
        try container.encodeIfPresent(whatHappened, forKey: .whatHappened)
        try container.encodeIfPresent(whatItMeans, forKey: .whatItMeans)
        try container.encodeIfPresent(whatToDoNext, forKey: .whatToDoNext)
        try container.encode(createdAt, forKey: .createdAt)
        // NOTE: updated_at is NOT encoded - Supabase trigger handles it
    }

    init(from workout: Workout, userId: UUID) {
        self.id = workout.id
        self.userId = userId
        self.type = workout.type.rawValue
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        self.calories = workout.calories
        self.averageHeartRate = workout.averageHeartRate
        self.maxHeartRate = workout.maxHeartRate
        self.intensity = workout.intensity.rawValue
        self.interpretation = workout.interpretation
        self.distance = workout.distance
        self.elevationGain = workout.elevationGain
        self.perceivedEffort = workout.perceivedEffort?.rawValue
        self.whatHappened = workout.whatHappened
        self.whatItMeans = workout.whatItMeans
        self.whatToDoNext = workout.whatToDoNext
        self.createdAt = workout.startDate
        self.updatedAt = nil // Not sent to Supabase
    }

    /// Debug helper to print JSON representation
    func debugPrintJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(self)
            if let json = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("☁️ SyncService: [DEBUG] JSON Payload:")
                #endif
                #if DEBUG
                print(json)
                #endif
            }
        } catch {
            #if DEBUG
            print("☁️ SyncService: [DEBUG] Failed to encode JSON: \(error)")
            #endif
        }
    }

    func toWorkout() -> Workout {
        var workout = Workout(
            id: id,
            type: WorkoutType(rawValue: type) ?? .other,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            calories: calories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            intensity: WorkoutIntensity(rawValue: intensity) ?? .moderate,
            interpretation: interpretation ?? ""
        )
        workout.distance = distance
        workout.elevationGain = elevationGain
        workout.whatHappened = whatHappened
        workout.whatItMeans = whatItMeans
        workout.whatToDoNext = whatToDoNext
        workout.perceivedEffort = perceivedEffort.flatMap { PerceivedEffort(rawValue: $0) }

        // Mark as restored from cloud sync - not eligible for check-ins
        workout.source = .cloudSync

        return workout
    }
}

/// Daily context record for Supabase (Extended with nutrition/weight)
/// NOTE: updated_at is handled by Supabase trigger - we don't send it
/// NOTE: date is sent as YYYY-MM-DD string to match PostgreSQL date column type.
///       Sending a full ISO-8601 timestamp to a `date` column causes a silent
///       PostgREST rejection, which is why daily_contexts was always empty.
struct DailyContextSyncRecord: Codable {
    let id: UUID
    let userId: UUID
    /// Stored as YYYY-MM-DD string so it is compatible with PostgreSQL `date` columns.
    let date: String
    // Sleep
    let sleepHours: Double?
    let sleepQuality: String?
    // Energy/Stress
    let stressLevel: String?
    let energyLevel: String?
    // Biometrics
    let restingHeartRate: Int?
    let hrvScore: Double?
    let readinessScore: Int?
    // Nutrition (new)
    let waterMl: Int?
    let calories: Int?
    let proteinGrams: Int?
    let carbsGrams: Int?
    let fatGrams: Int?
    let sodiumMg: Int?
    // Weight (new)
    let weightKg: Double?
    let bodyFatPercentage: Double?
    // Timestamps
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case sleepHours = "sleep_hours"
        case sleepQuality = "sleep_quality"
        case stressLevel = "stress_level"
        case energyLevel = "energy_level"
        case restingHeartRate = "resting_heart_rate"
        case hrvScore = "hrv_score"
        case readinessScore = "readiness_score"
        case waterMl = "water_ml"
        case calories
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case sodiumMg = "sodium_mg"
        case weightKg = "weight_kg"
        case bodyFatPercentage = "body_fat_percentage"
        case createdAt = "created_at"
    }

    // MARK: - Date helpers

    /// Formats a Date as YYYY-MM-DD for PostgreSQL `date` columns.
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Parses the stored string back to a Date.
    /// Accepts both "YYYY-MM-DD" (returned by Supabase date columns) and
    /// full ISO-8601 timestamps (returned by timestamp columns).
    var dateValue: Date {
        if let d = DailyContextSyncRecord.dayFormatter.date(from: date) { return d }
        if let d = ISO8601DateFormatter().date(from: date) { return d }
        return Date()
    }

    init(from context: DailyContext, userId: UUID) {
        self.id = context.id
        self.userId = userId
        self.date = DailyContextSyncRecord.dayFormatter.string(from: context.date)
        self.sleepHours = context.sleepHours
        self.sleepQuality = context.sleepQuality.rawValue
        self.stressLevel = context.stressLevel.rawValue
        self.energyLevel = context.energyLevel.rawValue
        self.restingHeartRate = context.restingHeartRate
        self.hrvScore = context.hrvScore
        self.readinessScore = context.readinessScore
        self.waterMl = context.waterIntakeMl
        self.calories = context.calories
        self.proteinGrams = context.proteinGrams
        self.carbsGrams = context.carbsGrams
        self.fatGrams = context.fatGrams
        self.sodiumMg = nil // Not in model yet
        self.weightKg = context.weightKg
        self.bodyFatPercentage = context.bodyFatPercentage
        self.createdAt = context.date
    }

    func toDailyContext() -> DailyContext {
        var context = DailyContext(
            id: id,
            date: dateValue,
            sleepHours: sleepHours ?? 0,
            sleepQuality: SleepQuality(rawValue: sleepQuality ?? "Fair") ?? .fair,
            stressLevel: StressLevel(rawValue: stressLevel ?? "Moderate") ?? .moderate,
            energyLevel: EnergyLevel(rawValue: energyLevel ?? "Moderate") ?? .moderate,
            restingHeartRate: restingHeartRate,
            hrvScore: hrvScore,
            readinessScore: readinessScore ?? 50
        )
        context.waterIntakeMl = waterMl
        context.calories = calories
        context.proteinGrams = proteinGrams
        context.carbsGrams = carbsGrams
        context.fatGrams = fatGrams
        context.weightKg = weightKg
        context.bodyFatPercentage = bodyFatPercentage
        return context
    }
}

/// Check-in record for Supabase
/// NOTE: date is sent as YYYY-MM-DD to match PostgreSQL `date` column type.
/// NOTE: updated_at is excluded from encoding (same as workouts) — Supabase trigger handles it.
///       Sending updated_at from the client while a trigger also sets it can cause upsert conflicts.
struct CheckInSyncRecord: Codable {
    let id: UUID
    let userId: UUID
    /// Stored as YYYY-MM-DD string so it is compatible with PostgreSQL `date` columns.
    let date: String
    let mood: String
    let energyLevel: String
    let soreness: String
    let motivation: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date  // decoded from cloud only; NOT sent on upload

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case mood
        case energyLevel = "energy_level"
        case soreness
        case motivation
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Date helpers (reuses DailyContextSyncRecord.dayFormatter)

    var dateValue: Date {
        if let d = DailyContextSyncRecord.dayFormatter.date(from: date) { return d }
        if let d = ISO8601DateFormatter().date(from: date) { return d }
        return Date()
    }

    // MARK: - Custom encode: exclude updated_at, send date as YYYY-MM-DD

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(date, forKey: .date)  // already YYYY-MM-DD string
        try container.encode(mood, forKey: .mood)
        try container.encode(energyLevel, forKey: .energyLevel)
        try container.encode(soreness, forKey: .soreness)
        try container.encode(motivation, forKey: .motivation)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        // NOTE: updated_at is intentionally NOT encoded — Supabase trigger manages it
    }

    init(from checkIn: CheckIn, userId: UUID) {
        self.id = checkIn.id
        self.userId = userId
        self.date = DailyContextSyncRecord.dayFormatter.string(from: checkIn.date)
        self.mood = checkIn.mood.rawValue
        self.energyLevel = checkIn.energyLevel.rawValue
        self.soreness = checkIn.soreness.rawValue
        self.motivation = checkIn.motivation.rawValue
        self.notes = checkIn.notes
        self.createdAt = checkIn.date
        self.updatedAt = Date()
    }

    func toCheckIn() -> CheckIn {
        CheckIn(
            id: id,
            date: dateValue,
            mood: Mood(rawValue: mood) ?? .okay,
            energyLevel: EnergyLevel(rawValue: energyLevel) ?? .moderate,
            soreness: SorenessLevel(rawValue: soreness) ?? .none,
            motivation: MotivationLevel(rawValue: motivation) ?? .moderate,
            notes: notes
        )
    }
}

/// Post-workout check-in record for Supabase
/// Schema requires: id, user_id, workout_id, feeling, note, date, created_at
struct PostWorkoutCheckInSyncRecord: Codable {
    let id: UUID
    let workoutId: UUID
    let userId: UUID
    let feeling: String
    let note: String?
    let date: Date  // FIXED: Added missing date field required by schema
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case userId = "user_id"
        case feeling
        case note
        case date
        case createdAt = "created_at"
    }

    init(id: UUID, workoutId: UUID, userId: UUID, feeling: String, note: String?) {
        self.id = id
        self.workoutId = workoutId
        self.userId = userId
        self.feeling = feeling
        self.note = note
        self.date = Date()  // FIXED: Set date to current timestamp
        self.createdAt = Date()
    }

    /// Debug helper to print JSON representation
    func debugPrintJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(self)
            if let json = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("☁️ SyncService: [DEBUG] PostWorkoutCheckIn JSON Payload:")
                #endif
                #if DEBUG
                print(json)
                #endif
            }
        } catch {
            #if DEBUG
            print("☁️ SyncService: [DEBUG] Failed to encode JSON: \(error)")
            #endif
        }
    }
}
