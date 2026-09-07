//
//  WellPatternApp.swift
//  WellPattern Health
//
//  Main app entry point.
//
//  ROUTING:
//  AppRootView reads authService.isAuthenticated directly in a plain if/else.
//  No showMain state, no onChange, no ZStack, no .id(), no NotificationCenter.
//  AuthService.signIn() sets isAuthenticated inside withAnimation(nil) so the
//  SwiftUI render that removes AuthContainerView happens in a nil-animation
//  transaction — instant removal, onDisappear fires synchronously.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct WellPatternApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncService = SupabaseSyncService.shared
    @StateObject private var premiumManager = PremiumManager.shared

    /// Reference to persistence service to ensure it's initialized
    private let persistenceService = PersistenceService.shared

    init() {
        #if DEBUG
        print("🚀 WellPatternApp: init()")
        #endif

        // ── Migrate UserDefaults keys from legacy Insio branding ─────────────
        // Must run before PremiumManager or UserGoalService read their keys.
        WellPatternApp.migrateUserDefaultsKeys()

        // ── Fix A: Root white background ──────────────────────────────────────
        // UINavigationController paints .systemBackground (white) before SwiftUI
        // backgrounds apply. Setting UINavigationBar appearance here reaches every
        // NavigationStack in the app.
        let bgColor = UIColor(red: 0.975, green: 0.965, blue: 0.945, alpha: 1)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = bgColor
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // ── Fix B: Eager Supabase client init ────────────────────────────────
        // SupabaseClient is a static let (lazy by default in Swift). Without this,
        // it initializes on the FIRST sign-in call, adding several seconds of delay
        // right as the user taps "Sign in". Touch it now so it's ready.
        _ = SupabaseConfig.client

        // Start free trial on first launch
        Task { @MainActor in
            PremiumManager.shared.startFreeTrial()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(premiumManager)
                .modelContainer(persistenceService.container)
                .onAppear {
                    Task { @MainActor in
                        PremiumManager.shared.checkTrialStatus()
                    }
                }
        }
    }

    // Idempotent one-time migration: reads old Insio-prefixed keys, writes to
    // WellPattern-prefixed keys, then deletes old keys. Safe to call on every launch.
    private static func migrateUserDefaultsKeys() {
        let migrations: [(old: String, new: String)] = [
            ("insio_subscription_tier",  "wellpattern_subscription_tier"),
            ("insio_premium_expiration", "wellpattern_premium_expiration"),
            ("insio_premium_product_id", "wellpattern_premium_product_id"),
            ("insio_trial_status",       "wellpattern_trial_status"),
            ("insio_trial_start_date",   "wellpattern_trial_start_date"),
            ("insio_user_primary_goal",  "wellpattern_user_primary_goal"),
            ("insio_user_selected_goals","wellpattern_user_selected_goals"),
        ]
        let defaults = UserDefaults.standard
        for (old, new) in migrations {
            guard let value = defaults.object(forKey: old) else { continue }
            if defaults.object(forKey: new) == nil {
                defaults.set(value, forKey: new)
            }
            defaults.removeObject(forKey: old)
        }
    }
}

// MARK: - App Root View

/// Root view with single-source-of-truth routing.
///
/// Direct if/else on authService.isAuthenticated — no showMain state needed.
/// AuthService.signIn() and handleSession() set isAuthenticated inside
/// withAnimation(nil), so every re-render triggered by that change runs in a
/// nil-animation transaction. SwiftUI removes AuthContainerView instantly;
/// onDisappear fires synchronously in the same render pass.
struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        #if DEBUG
        let _ = print("🏠 AppRootView body — isAuthenticated=\(authService.isAuthenticated) → branch: \(authService.isAuthenticated ? "MAIN" : "AUTH")")
        #endif

        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .onAppear {
                        #if DEBUG
                        print("🏠 MainTabView APPEARED")
                        #endif
                        appState.onAuthenticationSuccess()
                    }
            } else {
                authFlow
                    .transition(.identity)
            }
        }
        .animation(nil, value: authService.isAuthenticated)
    }

    @ViewBuilder
    private var authFlow: some View {
        if authService.isLoading {
            SplashLoadingView()
        } else if !appState.hasSeenOnboarding {
            OnboardingContainerView()
        } else {
            AuthContainerView()
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {

    // MARK: - Persisted State

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    /// Whether user has seen onboarding (even if skipped)
    @Published var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        }
    }

    /// Whether user accepted terms and privacy policy
    @Published var hasAcceptedTerms: Bool {
        didSet {
            UserDefaults.standard.set(hasAcceptedTerms, forKey: "hasAcceptedTerms")
        }
    }

    // MARK: - UI State

    @Published var showPostWorkoutCheckIn = false
    @Published var showNextDayCheckIn = false
    @Published var selectedWorkoutForSummary: Workout?

    /// The workout being checked in (for post-workout check-in)
    @Published var checkInWorkout: Workout?

    /// The workout ID for the next-day check-in (yesterday's workout)
    @Published var nextDayCheckInWorkoutId: UUID?

    // MARK: - Services

    /// WorkoutMonitor for automated check-in triggers
    let workoutMonitor = WorkoutMonitor.shared

    /// Auth service reference
    private let authService = AuthService.shared

    /// Sync service reference
    private let syncService = SupabaseSyncService.shared

    // MARK: - Initialization

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        self.hasAcceptedTerms = UserDefaults.standard.bool(forKey: "hasAcceptedTerms")
    }

    // MARK: - Auth Helpers

    /// Called when user successfully authenticates (false→true transition only).
    /// Clears stale data from any previous account, then restores current user's data.
    func onAuthenticationSuccess() {
        workoutMonitor.clearAllPending()

        // Detect account switch: compare current user ID to who was last signed in.
        // On a switch, wipe local data so Account B never sees Account A's workouts.
        let currentUserId = authService.currentUser?.id.uuidString
        let lastUserId = UserDefaults.standard.string(forKey: "lastSignedInUserId")

        if currentUserId != lastUserId {
            #if DEBUG
            print("🔔 [AUTH] Account switch — clearing stale local data")
            print("🔔 [AUTH] previous: \(lastUserId ?? "none") → current: \(currentUserId ?? "none")")
            #endif
            PersistenceService.shared.clearAllData()
            NutritionService.shared.deleteAllEntries()
            UserGoalService.shared.clearGoals()
            syncService.clearSyncState()
            workoutMonitor.resetCompletedTracking()
        } else {
            #if DEBUG
            let count = PersistenceService.shared.fetchRecentWorkouts(limit: 500).count
            print("🔔 [AUTH] Same user re-auth — keeping \(count) local workouts")
            #endif
        }

        if let uid = currentUserId {
            UserDefaults.standard.set(uid, forKey: "lastSignedInUserId")
        }

        // Restore current user's cloud data in background — must not block main actor.
        Task.detached(priority: .utility) { [syncService] in
            await syncService.restoreUserData()

            #if DEBUG
            await MainActor.run {
                let restored = PersistenceService.shared.fetchRecentWorkouts(limit: 500).count
                print("🔔 [AUTH] restoreUserData complete — \(restored) workouts after restore")
            }
            #endif
        }
    }

    /// Sign out
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            #if DEBUG
            print("AppState: Sign out error - \(error)")
            #endif
        }

        // Clear all local SwiftData records so Account B cannot see Account A's data
        PersistenceService.shared.clearAllData()
        NutritionService.shared.deleteAllEntries()
        UserGoalService.shared.clearGoals()

        // Clear sync state
        syncService.clearSyncState()

        // Clear ALL workout monitor state including completed check-in IDs.
        // clearAllPending() only clears in-memory state; resetCompletedTracking()
        // also wipes the UserDefaults-backed completedPostWorkoutIds and
        // completedNextDayIds so Account B cannot inherit Account A's tracking.
        workoutMonitor.clearAllPending()
        workoutMonitor.resetCompletedTracking()

        // Clear the account-switch guard so the next sign-in always runs a fresh restore.
        UserDefaults.standard.removeObject(forKey: "lastSignedInUserId")

        #if DEBUG
        // Verify the local store is fully empty after sign-out
        let remainingWorkouts = PersistenceService.shared.fetchRecentWorkouts(limit: 500).count
        let remainingContexts = PersistenceService.shared.fetchRecentDailyContexts(limit: 100).count
        let remainingCheckIns = PersistenceService.shared.fetchRecentCheckIns(limit: 100).count
        print("🔒 [SIGN-OUT] Cache clear verification:")
        print("🔒 [SIGN-OUT]   Workouts remaining  : \(remainingWorkouts)  (expected 0)")
        print("🔒 [SIGN-OUT]   Contexts remaining  : \(remainingContexts)  (expected 0)")
        print("🔒 [SIGN-OUT]   Check-ins remaining : \(remainingCheckIns) (expected 0)")
        if remainingWorkouts > 0 || remainingContexts > 0 || remainingCheckIns > 0 {
            print("🔒 [SIGN-OUT] ⚠️ WARNING: local data was NOT fully cleared — account isolation at risk!")
        } else {
            print("🔒 [SIGN-OUT] ✅ Local store fully cleared — account isolation confirmed")
        }
        #endif

        showPostWorkoutCheckIn = false
        showNextDayCheckIn = false
        checkInWorkout = nil
    }

    // MARK: - Onboarding

    /// Mark onboarding as seen (whether completed or skipped)
    func markOnboardingSeen() {
        hasSeenOnboarding = true
    }

    /// Complete onboarding fully
    func completeOnboarding() {
        hasCompletedOnboarding = true
        hasSeenOnboarding = true
    }

    /// Skip onboarding and go to auth
    func skipOnboarding() {
        hasSeenOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        hasSeenOnboarding = false
    }

    // MARK: - Automated Check-In

    /// Check for pending check-ins on app activation.
    /// Called when MainTabView appears (after auth success) and on scene phase changes.
    func checkForPendingCheckIns() {
        guard authService.isAuthenticated else { return }

        #if DEBUG
        print("🔔 [CHECK-IN] checkForPendingCheckIns — showPost=\(showPostWorkoutCheckIn) showNext=\(showNextDayCheckIn)")
        #endif

        workoutMonitor.checkForPendingCheckIns()

        #if DEBUG
        print("🔔 [CHECK-IN] after monitor check — hasPendingPost=\(workoutMonitor.hasPendingPostWorkoutCheckIn) hasPendingNext=\(workoutMonitor.hasPendingNextDayCheckIn)")
        #endif

        if workoutMonitor.hasPendingPostWorkoutCheckIn,
           let workout = workoutMonitor.pendingWorkoutForCheckIn,
           workoutMonitor.shouldShowPostWorkoutCheckIn() {
            triggerPostWorkoutCheckIn(for: workout)
        }

        if workoutMonitor.hasPendingNextDayCheckIn,
           let workout = workoutMonitor.pendingWorkoutForNextDayCheckIn,
           workoutMonitor.shouldShowNextDayCheckIn() {
            #if DEBUG
            print("🔔 [CHECK-IN] next-day pending — scheduling trigger in 0.5 s")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.triggerNextDayCheckIn(for: workout.id)
            }
        }
    }

    /// Notify that a workout was saved
    func workoutWasSaved(_ workout: Workout) {
        workoutMonitor.workoutSaved(workout)

        if workoutMonitor.hasPendingPostWorkoutCheckIn,
           workoutMonitor.shouldShowPostWorkoutCheckIn() {
            triggerPostWorkoutCheckIn(for: workout)
        }
    }

    // MARK: - Check-In Triggers

    func triggerPostWorkoutCheckIn(for workout: Workout) {
        guard !showPostWorkoutCheckIn else { return }
        checkInWorkout = workout
        showPostWorkoutCheckIn = true
        #if DEBUG
        print("🔔 [CHECK-IN] Post-workout check-in sheet PRESENTED for workout: \(workout.id)")
        #endif
    }

    func triggerNextDayCheckIn(for workoutId: UUID? = nil) {
        guard !showNextDayCheckIn else { return }
        nextDayCheckInWorkoutId = workoutId
        showNextDayCheckIn = true
        #if DEBUG
        print("🔔 [CHECK-IN] Next-day check-in sheet PRESENTED (workoutId: \(workoutId?.uuidString ?? "nil"))")
        #endif
    }

    // MARK: - Check-In Completion

    func completePostWorkoutCheckIn(feeling: String, note: String?) {
        guard let workout = checkInWorkout else {
            showPostWorkoutCheckIn = false
            return
        }

        #if DEBUG
        print("🔔 [CHECK-IN] Post-workout check-in DISMISSED (completed, feeling: \(feeling))")
        #endif

        // Local save first (immediate)
        PersistenceService.shared.savePostWorkoutCheckIn(
            workoutId: workout.id,
            feeling: feeling,
            note: note
        )

        workoutMonitor.postWorkoutCheckInCompleted(for: workout.id)

        // Dismiss UI immediately
        showPostWorkoutCheckIn = false
        checkInWorkout = nil

        // Background sync (non-blocking)
        if authService.isAuthenticated {
            Task.detached(priority: .utility) { [syncService] in
                await syncService.syncPostWorkoutCheckInWithTimeout(
                    workoutId: workout.id,
                    feeling: feeling,
                    note: note
                )
            }
        }
    }

    func completeNextDayCheckIn(bodyFeeling: String) {
        #if DEBUG
        print("🔔 [CHECK-IN] Next-day check-in DISMISSED (completed, feeling: \(bodyFeeling))")
        #endif

        let workoutId = nextDayCheckInWorkoutId

        // Local save first (immediate)
        PersistenceService.shared.saveNextDayCheckIn(
            recoveryId: nil,
            workoutId: workoutId,
            bodyFeeling: bodyFeeling
        )

        if let workoutId = workoutId {
            workoutMonitor.nextDayCheckInCompleted(for: workoutId)
        }

        // Dismiss UI immediately
        showNextDayCheckIn = false
        nextDayCheckInWorkoutId = nil
    }

    func skipPostWorkoutCheckIn() {
        #if DEBUG
        print("🔔 [CHECK-IN] Post-workout check-in DISMISSED (skipped)")
        #endif
        if let workout = checkInWorkout {
            workoutMonitor.postWorkoutCheckInSkipped(for: workout.id)
        }
        showPostWorkoutCheckIn = false
        checkInWorkout = nil
    }

    func skipNextDayCheckIn() {
        #if DEBUG
        print("🔔 [CHECK-IN] Next-day check-in DISMISSED (skipped)")
        #endif
        if let workoutId = nextDayCheckInWorkoutId {
            workoutMonitor.nextDayCheckInSkipped(for: workoutId)
        }
        showNextDayCheckIn = false
        nextDayCheckInWorkoutId = nil
    }
}

// MARK: - Splash Loading View

struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                // Logo
                ZStack {
                    Circle()
                        .fill(AppColors.navy.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(AppColors.navy)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.navy))
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
