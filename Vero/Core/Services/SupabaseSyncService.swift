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
        print("☁️ SyncService: Initialized")
    }

    // MARK: - Full Sync

    /// Perform a full sync: push local → pull remote → merge
    func performFullSync() async {
        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("☁️ SyncService: ❌ Cannot sync - user not authenticated")
            syncError = "Please sign in to sync"
            return
        }

        guard SupabaseConfig.isConfigured else {
            print("☁️ SyncService: ❌ Supabase not configured")
            syncError = "Cloud sync not configured"
            return
        }

        print("☁️ SyncService: ══════════════════════════════════════")
        print("☁️ SyncService: FULL SYNC STARTED")
        print("☁️ SyncService: User: \(userId)")
        print("☁️ SyncService: ══════════════════════════════════════")

        isSyncing = true
        syncError = nil

        do {
            // Step 1: Push local data to cloud
            print("☁️ SyncService: 📤 PHASE 1: Pushing local data to cloud...")
            try await pushWorkouts(userId: userId)
            try await pushDailyContexts(userId: userId)
            try await pushCheckIns(userId: userId)

            // Step 2: Pull cloud data and merge with local
            print("☁️ SyncService: 📥 PHASE 2: Pulling cloud data...")
            try await pullWorkouts(userId: userId)
            try await pullDailyContexts(userId: userId)
            try await pullCheckIns(userId: userId)

            // Step 3: Update sync timestamp
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")

            // Step 4: Verify sync completed successfully
            let verification = await verifySyncStatus()

            isSyncing = false
            print("☁️ SyncService: ══════════════════════════════════════")
            print("☁️ SyncService: ✅ FULL SYNC COMPLETE")
            print("☁️ SyncService: ══════════════════════════════════════")
            print("☁️ SyncService: SYNC SUMMARY:")
            print("☁️ SyncService:   Workouts: \(verification.localWorkoutCount) local → \(verification.cloudWorkoutCount) cloud")
            print("☁️ SyncService:   Contexts: \(verification.localDailyContextCount) local → \(verification.cloudDailyContextCount) cloud")
            print("☁️ SyncService:   Check-ins: \(verification.localCheckInCount) local → \(verification.cloudCheckInCount) cloud")
            print("☁️ SyncService:   Status: \(verification.summary)")
            print("☁️ SyncService: ══════════════════════════════════════")

        } catch {
            isSyncing = false
            syncError = "Sync failed: \(error.localizedDescription)"
            print("☁️ SyncService: ❌ SYNC FAILED: \(error)")
            // App continues to work with local data
        }
    }

    // MARK: - Data Restore (On Login)

    /// Restore user data from cloud on login
    /// IMPORTANT: This is called from a detached task - must not block UI
    func restoreUserData() async {
        print("☁️ SyncService: restoreUserData() - entered")

        // CRITICAL: Yield immediately to allow UI to render first
        // This ensures MainTabView appears before we do heavy work
        await Task.yield()
        print("☁️ SyncService: restoreUserData() - yielded to main thread")

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("☁️ SyncService: ❌ Cannot restore - not authenticated")
            return
        }

        guard SupabaseConfig.isConfigured else {
            print("☁️ SyncService: ⚠️ Supabase not configured, skipping restore")
            return
        }

        print("☁️ SyncService: ══════════════════════════════════════")
        print("☁️ SyncService: DATA RESTORE STARTED (login)")
        print("☁️ SyncService: User ID: \(userId)")
        print("☁️ SyncService: ══════════════════════════════════════")

        isSyncing = true
        syncError = nil

        do {
            print("☁️ SyncService: [RESTORE] Step 1/3: Pulling workouts...")
            try await pullWorkouts(userId: userId)
            print("☁️ SyncService: [RESTORE] Step 1/3: ✅ Workouts done")

            print("☁️ SyncService: [RESTORE] Step 2/3: Pulling daily contexts...")
            try await pullDailyContexts(userId: userId)
            print("☁️ SyncService: [RESTORE] Step 2/3: ✅ Daily contexts done")

            print("☁️ SyncService: [RESTORE] Step 3/3: Pulling check-ins...")
            try await pullCheckIns(userId: userId)
            print("☁️ SyncService: [RESTORE] Step 3/3: ✅ Check-ins done")

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            isSyncing = false

            print("☁️ SyncService: ══════════════════════════════════════")
            print("☁️ SyncService: ✅ DATA RESTORE COMPLETE")
            print("☁️ SyncService: ══════════════════════════════════════")

        } catch {
            isSyncing = false
            syncError = "Restore failed: \(error.localizedDescription)"
            print("☁️ SyncService: ══════════════════════════════════════")
            print("☁️ SyncService: ❌ RESTORE FAILED: \(error)")
            print("☁️ SyncService: App continues with local data")
            print("☁️ SyncService: ══════════════════════════════════════")
            // App continues with local data - non-blocking failure
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - WORKOUTS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local workouts to Supabase
    private func pushWorkouts(userId: UUID) async throws {
        let localWorkouts = persistenceService.fetchRecentWorkouts(limit: 500)
        print("☁️ SyncService: [WORKOUTS] Found \(localWorkouts.count) local workouts to push")
        print("☁️ SyncService: [WORKOUTS] User ID for insert: \(userId)")

        guard !localWorkouts.isEmpty else {
            print("☁️ SyncService: [WORKOUTS] Nothing to push")
            return
        }

        var successCount = 0
        var failCount = 0

        for workout in localWorkouts {
            let record = WorkoutSyncRecord(from: workout, userId: userId)

            do {
                print("☁️ SyncService: [WORKOUTS] 📤 Pushing workout \(workout.id)...")

                try await supabase
                    .from("workouts")
                    .upsert(record, onConflict: "id")
                    .execute()

                successCount += 1
                print("☁️ SyncService: [WORKOUTS] ✅ Pushed: \(workout.id) (\(workout.type.rawValue))")

            } catch {
                failCount += 1
                print("☁️ SyncService: [WORKOUTS] ❌ Failed to push \(workout.id)")
                print("☁️ SyncService: [WORKOUTS] Error Type: \(type(of: error))")
                print("☁️ SyncService: [WORKOUTS] Error: \(error)")
                print("☁️ SyncService: [WORKOUTS] Localized: \(error.localizedDescription)")

                // Log full error details for RLS debugging
                let errorString = String(describing: error)
                if errorString.contains("permission") || errorString.contains("policy") ||
                   errorString.contains("RLS") || errorString.contains("denied") {
                    print("☁️ SyncService: [WORKOUTS] ⚠️ This looks like an RLS policy error!")
                }
                // Continue with other workouts - don't fail entire sync
            }
        }

        print("☁️ SyncService: [WORKOUTS] Push complete - Success: \(successCount), Failed: \(failCount)")
    }

    /// Pull workouts from Supabase and merge with local
    private func pullWorkouts(userId: UUID) async throws {
        print("☁️ SyncService: [WORKOUTS] Fetching from cloud...")

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
            print("☁️ SyncService: [WORKOUTS] ❌ Fetch failed: \(error.localizedDescription)")
            throw error
        }

        print("☁️ SyncService: [WORKOUTS] 📥 Received \(records.count) workouts from cloud")

        var newCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for record in records {
            let workout = record.toWorkout()

            // Check if exists locally
            if let existing = persistenceService.fetchPersistedWorkout(id: workout.id) {
                // Compare timestamps - cloud wins if newer
                let localUpdated = existing.updatedAt
                if record.updatedAt > localUpdated {
                    persistenceService.saveWorkout(workout)
                    updatedCount += 1
                    print("☁️ SyncService: [WORKOUTS] 🔄 Updated: \(workout.id) (cloud newer)")
                } else {
                    skippedCount += 1
                    print("☁️ SyncService: [WORKOUTS] ⏭️ Skipped: \(workout.id) (local same/newer)")
                }
            } else {
                // New workout from cloud - add locally
                persistenceService.saveWorkout(workout)
                newCount += 1
                print("☁️ SyncService: [WORKOUTS] ➕ Added: \(workout.id) (new from cloud)")
            }
        }

        print("☁️ SyncService: [WORKOUTS] Merge complete - New: \(newCount), Updated: \(updatedCount), Skipped: \(skippedCount)")
    }

    /// Sync a single workout (called after local save)
    func syncWorkout(_ workout: Workout) async {
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: SYNC WORKOUT ATTEMPT")
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: Workout ID: \(workout.id)")
        print("☁️ SyncService: Workout Type: \(workout.type.rawValue)")
        print("☁️ SyncService: Auth State: isAuthenticated=\(authService.isAuthenticated)")
        print("☁️ SyncService: User ID: \(authService.userId?.uuidString ?? "NIL")")
        print("☁️ SyncService: Supabase Configured: \(SupabaseConfig.isConfigured)")

        guard authService.isAuthenticated else {
            print("☁️ SyncService: ❌ ABORT - User not authenticated")
            return
        }

        guard let userId = authService.userId else {
            print("☁️ SyncService: ❌ ABORT - User ID is nil despite being authenticated")
            return
        }

        guard SupabaseConfig.isConfigured else {
            print("☁️ SyncService: ❌ ABORT - Supabase not configured")
            return
        }

        // Create the sync record
        let record = WorkoutSyncRecord(from: workout, userId: userId)

        // Log the payload
        print("☁️ SyncService: ──────────────────────────────────────────────────")
        print("☁️ SyncService: PAYLOAD TO UPLOAD:")
        print("☁️ SyncService: Table: workouts")
        print("☁️ SyncService: id: \(record.id)")
        print("☁️ SyncService: user_id: \(record.userId)")
        print("☁️ SyncService: type: \(record.type)")
        print("☁️ SyncService: start_date: \(record.startDate)")
        print("☁️ SyncService: end_date: \(record.endDate)")
        print("☁️ SyncService: duration: \(record.duration)")
        print("☁️ SyncService: calories: \(record.calories)")
        print("☁️ SyncService: intensity: \(record.intensity)")
        print("☁️ SyncService: average_heart_rate: \(record.averageHeartRate?.description ?? "nil")")
        print("☁️ SyncService: max_heart_rate: \(record.maxHeartRate?.description ?? "nil")")
        print("☁️ SyncService: created_at: \(record.createdAt)")
        print("☁️ SyncService: updated_at: \(record.updatedAt)")

        // Print actual JSON payload for debugging
        record.debugPrintJSON()
        print("☁️ SyncService: ──────────────────────────────────────────────────")

        do {
            print("☁️ SyncService: 🚀 Sending upsert request to Supabase...")

            try await supabase
                .from("workouts")
                .upsert(record, onConflict: "id")
                .execute()

            print("☁️ SyncService: ✅ SUCCESS - Workout synced to Supabase")

            // Verify the sync by reading back the record
            let verifyRecords: [WorkoutSyncRecord] = try await supabase
                .from("workouts")
                .select()
                .eq("id", value: workout.id.uuidString)
                .execute()
                .value

            if verifyRecords.count == 1 {
                print("☁️ SyncService: 🔍 VERIFIED - Workout confirmed in Supabase")
            } else {
                print("☁️ SyncService: ⚠️ VERIFY WARNING - Could not confirm workout in Supabase")
            }

            print("☁️ SyncService: ══════════════════════════════════════════════════")

        } catch {
            print("☁️ SyncService: ❌ SYNC FAILED")
            print("☁️ SyncService: Error Type: \(type(of: error))")
            print("☁️ SyncService: Error Description: \(error.localizedDescription)")
            print("☁️ SyncService: Full Error: \(error)")

            // Try to extract more details from the error
            if let nsError = error as NSError? {
                print("☁️ SyncService: NSError Domain: \(nsError.domain)")
                print("☁️ SyncService: NSError Code: \(nsError.code)")
                print("☁️ SyncService: NSError UserInfo: \(nsError.userInfo)")
            }

            // Log the raw error string for debugging
            let errorString = String(describing: error)
            print("☁️ SyncService: Raw Error String: \(errorString)")
            print("☁️ SyncService: ══════════════════════════════════════════════════")

            // Don't throw - local data is safe, sync will retry on next full sync
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - DAILY CONTEXTS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local daily contexts to Supabase
    private func pushDailyContexts(userId: UUID) async throws {
        let contexts = persistenceService.fetchRecentDailyContexts(limit: 100)
        print("☁️ SyncService: [DAILY_CONTEXTS] Found \(contexts.count) local contexts")

        guard !contexts.isEmpty else {
            print("☁️ SyncService: [DAILY_CONTEXTS] Nothing to push")
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
                print("☁️ SyncService: [DAILY_CONTEXTS] ✅ Pushed: \(context.id)")

            } catch {
                failCount += 1
                print("☁️ SyncService: [DAILY_CONTEXTS] ⚠️ Failed: \(context.id): \(error.localizedDescription)")
            }
        }

        print("☁️ SyncService: [DAILY_CONTEXTS] Push complete - Success: \(successCount), Failed: \(failCount)")
    }

    /// Pull daily contexts from Supabase and merge
    private func pullDailyContexts(userId: UUID) async throws {
        print("☁️ SyncService: [DAILY_CONTEXTS] Fetching from cloud...")

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
            print("☁️ SyncService: [DAILY_CONTEXTS] ❌ Fetch failed: \(error.localizedDescription)")
            throw error
        }

        print("☁️ SyncService: [DAILY_CONTEXTS] 📥 Received \(records.count) contexts from cloud")

        var newCount = 0
        var skippedCount = 0

        for record in records {
            let context = record.toDailyContext()

            // Check for duplicate by date (not just ID)
            if persistenceService.fetchDailyContext(for: context.date) == nil {
                persistenceService.saveDailyContext(context)
                newCount += 1
                print("☁️ SyncService: [DAILY_CONTEXTS] ➕ Added: \(context.id) for date \(context.date)")
            } else {
                skippedCount += 1
                print("☁️ SyncService: [DAILY_CONTEXTS] ⏭️ Skipped: \(context.id) (already exists for date)")
            }
        }

        print("☁️ SyncService: [DAILY_CONTEXTS] Merge complete - New: \(newCount), Skipped: \(skippedCount)")
    }

    /// Sync a single daily context
    func syncDailyContext(_ context: DailyContext) async {
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: SYNC DAILY CONTEXT")
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: Context ID: \(context.id)")
        print("☁️ SyncService: Date: \(context.date)")
        print("☁️ SyncService: Sleep Hours: \(context.sleepHours)")
        print("☁️ SyncService: Auth State: isAuthenticated=\(authService.isAuthenticated)")

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("☁️ SyncService: [DAILY_CONTEXTS] ❌ ABORT - Not authenticated")
            return
        }

        guard SupabaseConfig.isConfigured else {
            print("☁️ SyncService: [DAILY_CONTEXTS] ❌ ABORT - Supabase not configured")
            return
        }

        print("☁️ SyncService: [DAILY_CONTEXTS] User ID: \(userId)")

        let record = DailyContextSyncRecord(from: context, userId: userId)

        // Log payload
        print("☁️ SyncService: [DAILY_CONTEXTS] Payload:")
        print("☁️ SyncService: [DAILY_CONTEXTS] id: \(record.id)")
        print("☁️ SyncService: [DAILY_CONTEXTS] user_id: \(record.userId)")
        print("☁️ SyncService: [DAILY_CONTEXTS] date: \(record.date)")
        print("☁️ SyncService: [DAILY_CONTEXTS] sleep_hours: \(record.sleepHours)")
        print("☁️ SyncService: [DAILY_CONTEXTS] hrv_score: \(record.hrvScore?.description ?? "nil")")

        do {
            print("☁️ SyncService: [DAILY_CONTEXTS] 🚀 Sending upsert request...")

            try await supabase
                .from("daily_contexts")
                .upsert(record, onConflict: "id")
                .execute()

            print("☁️ SyncService: [DAILY_CONTEXTS] ✅ Synced: \(context.id)")
            print("☁️ SyncService: ══════════════════════════════════════════════════")

        } catch {
            print("☁️ SyncService: [DAILY_CONTEXTS] ❌ Sync failed")
            print("☁️ SyncService: [DAILY_CONTEXTS] Error: \(error)")
            print("☁️ SyncService: [DAILY_CONTEXTS] Localized: \(error.localizedDescription)")
            print("☁️ SyncService: ══════════════════════════════════════════════════")
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - CHECK-INS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Push all local check-ins to Supabase
    private func pushCheckIns(userId: UUID) async throws {
        let checkIns = persistenceService.fetchRecentCheckIns(limit: 100)
        print("☁️ SyncService: [CHECK_INS] Found \(checkIns.count) local check-ins")

        guard !checkIns.isEmpty else {
            print("☁️ SyncService: [CHECK_INS] Nothing to push")
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
                print("☁️ SyncService: [CHECK_INS] ✅ Pushed: \(checkIn.id)")

            } catch {
                failCount += 1
                print("☁️ SyncService: [CHECK_INS] ⚠️ Failed: \(checkIn.id): \(error.localizedDescription)")
            }
        }

        print("☁️ SyncService: [CHECK_INS] Push complete - Success: \(successCount), Failed: \(failCount)")
    }

    /// Pull check-ins from Supabase and merge
    private func pullCheckIns(userId: UUID) async throws {
        print("☁️ SyncService: [CHECK_INS] Fetching from cloud...")

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
            print("☁️ SyncService: [CHECK_INS] ❌ Fetch failed: \(error.localizedDescription)")
            throw error
        }

        print("☁️ SyncService: [CHECK_INS] 📥 Received \(records.count) check-ins from cloud")

        var newCount = 0
        var skippedCount = 0

        for record in records {
            let checkIn = record.toCheckIn()

            // Check for duplicate by ID
            if persistenceService.fetchCheckIn(id: checkIn.id) == nil {
                persistenceService.saveCheckIn(checkIn)
                newCount += 1
                print("☁️ SyncService: [CHECK_INS] ➕ Added: \(checkIn.id)")
            } else {
                skippedCount += 1
                print("☁️ SyncService: [CHECK_INS] ⏭️ Skipped: \(checkIn.id) (already exists)")
            }
        }

        print("☁️ SyncService: [CHECK_INS] Merge complete - New: \(newCount), Skipped: \(skippedCount)")
    }

    /// Sync a single check-in
    func syncCheckIn(_ checkIn: CheckIn) async {
        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("☁️ SyncService: [CHECK_INS] ⏸️ Not authenticated")
            return
        }

        guard SupabaseConfig.isConfigured else { return }

        print("☁️ SyncService: [CHECK_INS] 📤 Syncing: \(checkIn.id)")

        do {
            let record = CheckInSyncRecord(from: checkIn, userId: userId)

            try await supabase
                .from("check_ins")
                .upsert(record, onConflict: "id")
                .execute()

            print("☁️ SyncService: [CHECK_INS] ✅ Synced: \(checkIn.id)")

        } catch {
            print("☁️ SyncService: [CHECK_INS] ❌ Sync failed: \(error.localizedDescription)")
        }
    }

    // ══════════════════════════════════════════════════════════════
    // MARK: - POST-WORKOUT CHECK-INS SYNC
    // ══════════════════════════════════════════════════════════════

    /// Sync a post-workout check-in
    func syncPostWorkoutCheckIn(workoutId: UUID, feeling: String, note: String?) async {
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: SYNC POST-WORKOUT CHECK-IN")
        print("☁️ SyncService: ══════════════════════════════════════════════════")
        print("☁️ SyncService: Workout ID: \(workoutId)")
        print("☁️ SyncService: Feeling: \(feeling)")
        print("☁️ SyncService: Note: \(note ?? "nil")")
        print("☁️ SyncService: Auth State: isAuthenticated=\(authService.isAuthenticated)")

        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] ⏸️ Not authenticated")
            return
        }

        guard SupabaseConfig.isConfigured else {
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] ⏸️ Supabase not configured")
            return
        }

        print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] User ID: \(userId)")

        let record = PostWorkoutCheckInSyncRecord(
            id: UUID(),
            workoutId: workoutId,
            userId: userId,
            feeling: feeling,
            note: note
        )

        record.debugPrintJSON()

        do {
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] 🚀 Sending insert request...")

            try await supabase
                .from("post_workout_check_ins")
                .insert(record)
                .execute()

            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] ✅ Synced!")
            print("☁️ SyncService: ══════════════════════════════════════════════════")

        } catch {
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] ❌ Sync failed")
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] Error: \(error)")
            print("☁️ SyncService: [POST_WORKOUT_CHECK_INS] Localized: \(error.localizedDescription)")
            print("☁️ SyncService: ══════════════════════════════════════════════════")
        }
    }

    // MARK: - Sync Verification

    /// Verify that data has been successfully synced to Supabase
    /// This reads back from the cloud to confirm data was saved
    func verifySyncStatus() async -> SyncVerificationResult {
        guard authService.isAuthenticated,
              let userId = authService.userId else {
            print("🔍 SyncVerify: ❌ Not authenticated")
            return SyncVerificationResult(isAuthenticated: false)
        }

        guard SupabaseConfig.isConfigured else {
            print("🔍 SyncVerify: ❌ Supabase not configured")
            return SyncVerificationResult(isAuthenticated: true, isConfigured: false)
        }

        print("🔍 SyncVerify: ══════════════════════════════════════════════════")
        print("🔍 SyncVerify: SYNC VERIFICATION STARTED")
        print("🔍 SyncVerify: User ID: \(userId)")
        print("🔍 SyncVerify: ══════════════════════════════════════════════════")

        var result = SyncVerificationResult(isAuthenticated: true, isConfigured: true)

        // Count local data
        let localWorkouts = persistenceService.fetchRecentWorkouts(limit: 500)
        let localContexts = persistenceService.fetchRecentDailyContexts(limit: 100)
        let localCheckIns = persistenceService.fetchRecentCheckIns(limit: 100)

        result.localWorkoutCount = localWorkouts.count
        result.localDailyContextCount = localContexts.count
        result.localCheckInCount = localCheckIns.count

        print("🔍 SyncVerify: LOCAL DATA:")
        print("🔍 SyncVerify:   Workouts: \(result.localWorkoutCount)")
        print("🔍 SyncVerify:   Daily Contexts: \(result.localDailyContextCount)")
        print("🔍 SyncVerify:   Check-ins: \(result.localCheckInCount)")

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

            print("🔍 SyncVerify: CLOUD DATA:")
            print("🔍 SyncVerify:   Workouts: \(result.cloudWorkoutCount)")
            print("🔍 SyncVerify:   Daily Contexts: \(result.cloudDailyContextCount)")
            print("🔍 SyncVerify:   Check-ins: \(result.cloudCheckInCount)")

            // Calculate sync status
            let workoutsSynced = result.cloudWorkoutCount >= result.localWorkoutCount
            let contextsSynced = result.cloudDailyContextCount >= result.localDailyContextCount
            let checkInsSynced = result.cloudCheckInCount >= result.localCheckInCount

            print("🔍 SyncVerify: ──────────────────────────────────────────────────")
            print("🔍 SyncVerify: SYNC STATUS:")
            print("🔍 SyncVerify:   Workouts: \(workoutsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")
            print("🔍 SyncVerify:   Daily Contexts: \(contextsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")
            print("🔍 SyncVerify:   Check-ins: \(checkInsSynced ? "✅ SYNCED" : "⚠️ LOCAL > CLOUD")")

            if workoutsSynced && contextsSynced && checkInsSynced {
                print("🔍 SyncVerify: ✅ ALL DATA VERIFIED IN CLOUD")
            } else {
                print("🔍 SyncVerify: ⚠️ Some local data may not be synced yet")
                print("🔍 SyncVerify: Run performFullSync() to push pending data")
            }

        } catch {
            result.verificationSuccess = false
            result.error = error.localizedDescription
            print("🔍 SyncVerify: ❌ Verification failed: \(error.localizedDescription)")
        }

        print("🔍 SyncVerify: ══════════════════════════════════════════════════")

        return result
    }

    // MARK: - Clear State (Logout)

    func clearSyncState() {
        lastSyncDate = nil
        syncError = nil
        pendingSyncCount = 0
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        print("☁️ SyncService: State cleared (logout)")
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
        print("☁️ SyncService: [TIMEOUT] syncWorkout starting (timeout: \(timeout)s)")

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
                    print("☁️ SyncService: [TIMEOUT] syncWorkout completed within timeout ✅")
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    print("☁️ SyncService: [TIMEOUT] syncWorkout TIMED OUT after \(timeout)s ⚠️")
                    print("☁️ SyncService: [TIMEOUT] Local data is safe - will retry on next full sync")
                }
            }
        } catch {
            print("☁️ SyncService: [TIMEOUT] syncWorkout error: \(error)")
        }
    }

    /// Sync a post-workout check-in with timeout protection
    func syncPostWorkoutCheckInWithTimeout(
        workoutId: UUID,
        feeling: String,
        note: String?,
        timeout: TimeInterval = 10
    ) async {
        print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn starting (timeout: \(timeout)s)")

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
                    print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn completed within timeout ✅")
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn TIMED OUT after \(timeout)s ⚠️")
                }
            }
        } catch {
            print("☁️ SyncService: [TIMEOUT] syncPostWorkoutCheckIn error: \(error)")
        }
    }

    /// Sync daily context with timeout protection
    func syncDailyContextWithTimeout(_ context: DailyContext, timeout: TimeInterval = 10) async {
        print("☁️ SyncService: [TIMEOUT] syncDailyContext starting (timeout: \(timeout)s)")

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
                    print("☁️ SyncService: [TIMEOUT] syncDailyContext completed within timeout ✅")
                } catch is SyncTimeoutError {
                    group.cancelAll()
                    print("☁️ SyncService: [TIMEOUT] syncDailyContext TIMED OUT after \(timeout)s ⚠️")
                }
            }
        } catch {
            print("☁️ SyncService: [TIMEOUT] syncDailyContext error: \(error)")
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
    let updatedAt: Date

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
        self.updatedAt = Date()
    }

    /// Debug helper to print JSON representation
    func debugPrintJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(self)
            if let json = String(data: data, encoding: .utf8) {
                print("☁️ SyncService: [DEBUG] JSON Payload:")
                print(json)
            }
        } catch {
            print("☁️ SyncService: [DEBUG] Failed to encode JSON: \(error)")
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

/// Daily context record for Supabase
struct DailyContextSyncRecord: Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let sleepHours: Double
    let sleepQuality: String
    let stressLevel: String
    let energyLevel: String
    let restingHeartRate: Int?
    let hrvScore: Double?
    let readinessScore: Int
    let createdAt: Date
    let updatedAt: Date

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from context: DailyContext, userId: UUID) {
        self.id = context.id
        self.userId = userId
        self.date = context.date
        self.sleepHours = context.sleepHours
        self.sleepQuality = context.sleepQuality.rawValue
        self.stressLevel = context.stressLevel.rawValue
        self.energyLevel = context.energyLevel.rawValue
        self.restingHeartRate = context.restingHeartRate
        self.hrvScore = context.hrvScore
        self.readinessScore = context.readinessScore
        self.createdAt = context.date
        self.updatedAt = Date()
    }

    func toDailyContext() -> DailyContext {
        DailyContext(
            id: id,
            date: date,
            sleepHours: sleepHours,
            sleepQuality: SleepQuality(rawValue: sleepQuality) ?? .fair,
            stressLevel: StressLevel(rawValue: stressLevel) ?? .moderate,
            energyLevel: EnergyLevel(rawValue: energyLevel) ?? .moderate,
            restingHeartRate: restingHeartRate,
            hrvScore: hrvScore,
            readinessScore: readinessScore
        )
    }
}

/// Check-in record for Supabase
struct CheckInSyncRecord: Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let mood: String
    let energyLevel: String
    let soreness: String
    let motivation: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

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

    init(from checkIn: CheckIn, userId: UUID) {
        self.id = checkIn.id
        self.userId = userId
        self.date = checkIn.date
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
            date: date,
            mood: Mood(rawValue: mood) ?? .okay,
            energyLevel: EnergyLevel(rawValue: energyLevel) ?? .moderate,
            soreness: SorenessLevel(rawValue: soreness) ?? .none,
            motivation: MotivationLevel(rawValue: motivation) ?? .moderate,
            notes: notes
        )
    }
}

/// Post-workout check-in record for Supabase
struct PostWorkoutCheckInSyncRecord: Codable {
    let id: UUID
    let workoutId: UUID
    let userId: UUID
    let feeling: String
    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case userId = "user_id"
        case feeling
        case note
        case createdAt = "created_at"
    }

    init(id: UUID, workoutId: UUID, userId: UUID, feeling: String, note: String?) {
        self.id = id
        self.workoutId = workoutId
        self.userId = userId
        self.feeling = feeling
        self.note = note
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
                print("☁️ SyncService: [DEBUG] PostWorkoutCheckIn JSON Payload:")
                print(json)
            }
        } catch {
            print("☁️ SyncService: [DEBUG] Failed to encode JSON: \(error)")
        }
    }
}
