//
//  InsioApp.swift
//  Insio Health
//
//  Main app entry point with clean routing architecture.
//
//  ARCHITECTURE:
//  - Uses @State showMainApp for reliable SwiftUI view switching
//  - NotificationCenter bypasses SwiftUI's reactive system for singletons
//  - ZStack with transitions for smooth animation
//
//  AUTH FIX (PERMANENT):
//  - Use @State showMainApp (local state SwiftUI definitely observes)
//  - Use NotificationCenter to force transition (bypasses singleton issues)
//  - Use ZStack (not Group) for reliable view replacement
//
//  IF AUTH BREAKS AGAIN:
//  1. Check LoginView posts .authStateDidChange notification after sign-in
//  2. Check AppRootView listens with .onReceive
//  3. Ensure showMainApp is @State
//  4. Use ZStack, not Group
//

import SwiftUI
import SwiftData
import Combine
import UIKit

// MARK: - Notification for Auth State Change

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}

// MARK: - App Route

enum AppRoute: Equatable {
    case loading
    case onboarding
    case auth
    case main
}

@main
struct InsioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncService = SupabaseSyncService.shared
    @StateObject private var premiumManager = PremiumManager.shared

    /// Reference to persistence service to ensure it's initialized
    private let persistenceService = PersistenceService.shared

    init() {
        #if DEBUG
        print("🚀 InsioApp: init()")
        #endif

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
}

// MARK: - App Root View

/// Root view using @State + NotificationCenter for reliable auth transitions.
/// SwiftUI's reactive observation with singletons doesn't reliably trigger view replacement,
/// so we use NotificationCenter to force the transition.
struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showMainApp = false

    var body: some View {
        // .id() forces SwiftUI to DESTROY and RECREATE the entire ZStack when
        // showMainApp flips. This bypasses the simulator rendering bug where
        // SwiftUI updates the view graph (if/else) but never repaints the screen.
        // Using string IDs ("auth"/"main") instead of Bool so the identity is clear.
        //
        // IMPORTANT: .onAppear and .onChange are placed OUTSIDE .id() so they are
        // NOT recreated when the ID changes — they persist on the wrapper view.
        ZStack {
            if showMainApp {
                MainTabView()
                    .onAppear {
                        #if DEBUG
                        print("🏠 MainTabView APPEARED")
                        #endif
                    }
                    .onChange(of: authService.isAuthenticated) { _, isAuth in
                        if !isAuth { showMainApp = false }
                    }
            } else {
                authFlow
                    .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
                        #if DEBUG
                        print("🏠 notification → showMainApp = true")
                        #endif
                        showMainApp = true
                    }
                    .onChange(of: authService.isAuthenticated) { _, isAuth in
                        if isAuth { showMainApp = true }
                    }
            }
        }
        .id(showMainApp ? "main" : "auth")  // Forces full view-tree replacement on flip
        .onAppear {
            // Initial check: already authenticated (e.g. app relaunch with session)
            if authService.isAuthenticated { showMainApp = true }
        }
        .onChange(of: showMainApp) { _, isShowing in
            if isShowing {
                #if DEBUG
                print("🏠 showMainApp → true, calling onAuthenticationSuccess")
                #endif
                appState.onAuthenticationSuccess()
            }
        }
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

    /// Called when user successfully authenticates
    /// IMPORTANT: This must NOT block UI rendering - restore runs in background
    func onAuthenticationSuccess() {
        checkForPendingCheckIns()

        // CRITICAL: Use Task.detached to ensure this doesn't block main actor
        // The regular Task {} inherits @MainActor context and can block UI rendering
        Task.detached(priority: .utility) { [syncService] in
            await syncService.restoreUserData()
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
        workoutMonitor.checkForPendingCheckIns()

        if workoutMonitor.hasPendingPostWorkoutCheckIn,
           let workout = workoutMonitor.pendingWorkoutForCheckIn,
           workoutMonitor.shouldShowPostWorkoutCheckIn() {
            triggerPostWorkoutCheckIn(for: workout)
        }

        if workoutMonitor.hasPendingNextDayCheckIn,
           let workout = workoutMonitor.pendingWorkoutForNextDayCheckIn,
           workoutMonitor.shouldShowNextDayCheckIn() {
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
    }

    func triggerNextDayCheckIn(for workoutId: UUID? = nil) {
        guard !showNextDayCheckIn else { return }
        nextDayCheckInWorkoutId = workoutId
        showNextDayCheckIn = true
    }

    // MARK: - Check-In Completion

    func completePostWorkoutCheckIn(feeling: String, note: String?) {
        guard let workout = checkInWorkout else {
            showPostWorkoutCheckIn = false
            return
        }

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
        if let workout = checkInWorkout {
            workoutMonitor.postWorkoutCheckInSkipped(for: workout.id)
        }
        showPostWorkoutCheckIn = false
        checkInWorkout = nil
    }

    func skipNextDayCheckIn() {
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
