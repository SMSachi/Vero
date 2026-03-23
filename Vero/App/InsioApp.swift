//
//  InsioApp.swift
//  Insio Health
//
//  Main app entry point with clean routing architecture.
//
//  ARCHITECTURE:
//  - AppRoute enum is THE SINGLE SOURCE OF TRUTH for navigation
//  - No guest mode - authentication is required
//  - Flow: splash → onboarding (new users) → auth → main
//  - Onboarding can be skipped → goes to auth
//

import SwiftUI
import SwiftData
import Combine

@main
struct InsioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncService = SupabaseSyncService.shared
    @StateObject private var premiumManager = PremiumManager.shared

    /// Reference to persistence service to ensure it's initialized
    private let persistenceService = PersistenceService.shared

    /// Force view refresh counter - increment this to force SwiftUI to recreate views
    @State private var forceRefreshID = UUID()

    init() {
        print("🚀 InsioApp: init()")

        // Start free trial on first launch
        Task { @MainActor in
            PremiumManager.shared.startFreeTrial()
        }
    }

    var body: some Scene {
        WindowGroup {
            // NEW APPROACH: Main content is always mounted, auth is shown as modal
            AuthGateView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(premiumManager)
                .modelContainer(persistenceService.container)
                .onAppear {
                    print("🚀 APP BODY: WindowGroup appeared - isAuthenticated=\(authService.isAuthenticated)")
                    Task { @MainActor in
                        PremiumManager.shared.checkTrialStatus()
                    }
                }
        }
    }
}

// MARK: - Auth Gate View (NEW RELIABLE APPROACH)

/// Uses fullScreenCover for auth instead of view replacement.
/// This is more reliable because the main view is always mounted,
/// and auth is just a modal that dismisses when authenticated.
struct AuthGateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    /// Controls whether to show auth modal
    @State private var showAuthModal = false

    /// Controls whether to show onboarding modal
    @State private var showOnboardingModal = false

    var body: some View {
        // Main content is ALWAYS the root - no conditional switching
        MainTabView()
            .onAppear {
                print("🚀 AuthGateView: MainTabView mounted")
                // Check if we need to show auth or onboarding
                updateModals()
            }
            // Show onboarding as fullScreenCover
            .fullScreenCover(isPresented: $showOnboardingModal) {
                OnboardingContainerView()
                    .environmentObject(appState)
                    .onDisappear {
                        print("🚀 AuthGateView: Onboarding dismissed")
                        // After onboarding, check if we need auth
                        updateModals()
                    }
            }
            // Show auth as fullScreenCover (this dismisses automatically when isAuthenticated changes)
            .fullScreenCover(isPresented: $showAuthModal) {
                AuthContainerView()
                    .environmentObject(appState)
                    .environmentObject(authService)
                    .onDisappear {
                        print("🚀 AuthGateView: Auth modal dismissed")
                        if authService.isAuthenticated {
                            appState.onAuthenticationSuccess()
                        }
                    }
            }
            // CRITICAL: Watch for auth state changes to dismiss modal
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                print("🚀 AuthGateView: isAuthenticated changed to \(isAuthenticated)")
                if isAuthenticated {
                    // Dismiss auth modal when authenticated
                    withAnimation {
                        showAuthModal = false
                    }
                } else {
                    // Show auth modal when not authenticated (after onboarding)
                    if appState.hasSeenOnboarding {
                        withAnimation {
                            showAuthModal = true
                        }
                    }
                }
            }
            .onChange(of: appState.hasSeenOnboarding) { _, hasSeen in
                print("🚀 AuthGateView: hasSeenOnboarding changed to \(hasSeen)")
                updateModals()
            }
    }

    private func updateModals() {
        print("🚀 AuthGateView: updateModals - isAuthenticated=\(authService.isAuthenticated), hasSeenOnboarding=\(appState.hasSeenOnboarding)")

        // If not authenticated
        if !authService.isAuthenticated {
            // First check if onboarding is needed
            if !appState.hasSeenOnboarding {
                showOnboardingModal = true
                showAuthModal = false
            } else {
                // Onboarding done, show auth
                showOnboardingModal = false
                showAuthModal = true
            }
        } else {
            // Authenticated - hide all modals
            showOnboardingModal = false
            showAuthModal = false
        }

        print("🚀 AuthGateView: showOnboardingModal=\(showOnboardingModal), showAuthModal=\(showAuthModal)")
    }
}

// MARK: - App Route (Single Source of Truth)

/// The single source of truth for app routing.
/// This enum determines what screen is shown.
enum AppRoute: String {
    case splash = "splash"           // Initial loading state (max 2 seconds)
    case onboarding = "onboarding"   // First-time user onboarding
    case auth = "auth"               // Sign in / Sign up
    case main = "main"               // Authenticated user - main app
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {

    // MARK: - Persisted State

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
            print("🧭 AppState: hasCompletedOnboarding changed to \(hasCompletedOnboarding)")
        }
    }

    /// Whether user has seen onboarding (even if skipped)
    @Published var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
            print("🧭 AppState: hasSeenOnboarding changed to \(hasSeenOnboarding)")
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

        print("🧭 AppState: init - hasCompletedOnboarding=\(hasCompletedOnboarding), hasSeenOnboarding=\(hasSeenOnboarding)")
    }

    // MARK: - Route Computation

    /// Compute the current route based on app state.
    /// This is THE SINGLE SOURCE OF TRUTH for routing.
    func computeRoute(isAuthLoading: Bool, isAuthenticated: Bool) -> AppRoute {
        // 1. If auth is still loading, show splash (but with timeout protection)
        if isAuthLoading {
            return .splash
        }

        // 2. If user is authenticated, go to main app
        if isAuthenticated {
            return .main
        }

        // 3. If user hasn't seen onboarding yet, show onboarding
        if !hasSeenOnboarding {
            return .onboarding
        }

        // 4. Otherwise, show auth
        return .auth
    }

    // MARK: - Auth Helpers

    /// Called when user successfully authenticates
    /// IMPORTANT: This must NOT block UI rendering - restore runs in background
    func onAuthenticationSuccess() {
        print("🧭 ══════════════════════════════════════════════════")
        print("🧭 AppState: onAuthenticationSuccess() - STARTING")
        print("🧭 AppState: UI should render MainTabView NOW")
        print("🧭 AppState: Background restore will start after UI renders")
        print("🧭 ══════════════════════════════════════════════════")

        // CRITICAL: Use Task.detached to ensure this doesn't block main actor
        // The regular Task {} inherits @MainActor context and can block UI rendering
        Task.detached(priority: .utility) { [syncService] in
            print("🧭 AppState: [BACKGROUND] Starting restoreUserData...")

            // This runs off main actor - syncService methods will hop to main when needed
            await syncService.restoreUserData()

            print("🧭 AppState: [BACKGROUND] restoreUserData completed")
        }

        print("🧭 AppState: onAuthenticationSuccess() - RETURNED (non-blocking)")
    }

    /// Sign out
    func signOut() async {
        print("🧭 AppState: signOut")
        do {
            try await authService.signOut()
        } catch {
            print("🧭 AppState: Sign out error - \(error)")
        }

        // Clear sync state
        syncService.clearSyncState()

        // Clear check-in monitor state
        workoutMonitor.clearAllPending()

        // Reset check-in UI state
        showPostWorkoutCheckIn = false
        showNextDayCheckIn = false
        checkInWorkout = nil

        print("🧭 AppState: Sign out complete")
    }

    // MARK: - Onboarding

    /// Mark onboarding as seen (whether completed or skipped)
    func markOnboardingSeen() {
        print("🧭 AppState: markOnboardingSeen")
        hasSeenOnboarding = true
    }

    /// Complete onboarding fully
    func completeOnboarding() {
        print("🧭 AppState: completeOnboarding")
        hasCompletedOnboarding = true
        hasSeenOnboarding = true
    }

    /// Skip onboarding and go to auth
    func skipOnboarding() {
        print("🧭 AppState: skipOnboarding - routing to auth")
        hasSeenOnboarding = true
        // Don't set hasCompletedOnboarding - they skipped
    }

    func resetOnboarding() {
        print("🧭 AppState: resetOnboarding")
        hasCompletedOnboarding = false
        hasSeenOnboarding = false
    }

    // MARK: - Automated Check-In

    /// Check for pending check-ins on app activation.
    func checkForPendingCheckIns() {
        print("📱 AppState: checkForPendingCheckIns() called")
        workoutMonitor.checkForPendingCheckIns()

        print("📱 AppState: hasPendingPostWorkout = \(workoutMonitor.hasPendingPostWorkoutCheckIn)")
        print("📱 AppState: hasPendingNextDay = \(workoutMonitor.hasPendingNextDayCheckIn)")

        // Trigger post-workout check-in if pending
        if workoutMonitor.hasPendingPostWorkoutCheckIn,
           let workout = workoutMonitor.pendingWorkoutForCheckIn,
           workoutMonitor.shouldShowPostWorkoutCheckIn() {
            print("📱 AppState: ⚠️ TRIGGERING post-workout check-in for workout \(workout.id)")
            triggerPostWorkoutCheckIn(for: workout)
        }

        // Trigger next-day check-in if pending
        if workoutMonitor.hasPendingNextDayCheckIn,
           let workout = workoutMonitor.pendingWorkoutForNextDayCheckIn,
           workoutMonitor.shouldShowNextDayCheckIn() {
            print("📱 AppState: ⚠️ TRIGGERING next-day check-in for workout \(workout.id)")
            triggerNextDayCheckIn(for: workout.id)
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
        checkInWorkout = workout
        showPostWorkoutCheckIn = true
    }

    func triggerNextDayCheckIn(for workoutId: UUID? = nil) {
        nextDayCheckInWorkoutId = workoutId
        showNextDayCheckIn = true
    }

    // MARK: - Check-In Completion

    func completePostWorkoutCheckIn(feeling: String, note: String?) {
        guard let workout = checkInWorkout else {
            showPostWorkoutCheckIn = false
            return
        }

        print("📱 AppState: Saving post-workout check-in for \(workout.id)")

        PersistenceService.shared.savePostWorkoutCheckIn(
            workoutId: workout.id,
            feeling: feeling,
            note: note
        )

        workoutMonitor.postWorkoutCheckInCompleted(for: workout.id)

        if authService.isAuthenticated {
            Task {
                await syncService.syncPostWorkoutCheckIn(
                    workoutId: workout.id,
                    feeling: feeling,
                    note: note
                )
            }
        }

        showPostWorkoutCheckIn = false
    }

    func completeNextDayCheckIn(bodyFeeling: String) {
        PersistenceService.shared.saveNextDayCheckIn(
            recoveryId: nil,
            workoutId: nextDayCheckInWorkoutId,
            bodyFeeling: bodyFeeling
        )

        if let workoutId = nextDayCheckInWorkoutId {
            workoutMonitor.nextDayCheckInCompleted(for: workoutId)
        }

        showNextDayCheckIn = false
    }

    func skipPostWorkoutCheckIn() {
        if let workout = checkInWorkout {
            workoutMonitor.postWorkoutCheckInSkipped(for: workout.id)
        }
        showPostWorkoutCheckIn = false
    }

    func skipNextDayCheckIn() {
        if let workoutId = nextDayCheckInWorkoutId {
            workoutMonitor.nextDayCheckInSkipped(for: workoutId)
        }
        showNextDayCheckIn = false
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    /// Timeout protection - force exit splash after 2 seconds
    @State private var splashTimeout = false
    @State private var timeoutStarted = false

    /// Current route - stored as @State for reliable SwiftUI updates
    @State private var currentRoute: AppRoute = .splash

    var body: some View {
        // DEBUG: Log every body evaluation
        let _ = print("🧭 RootView: body EVALUATING - currentRoute = \(currentRoute.rawValue)")

        // NUCLEAR FIX: Use switch + .id() to FORCE complete view replacement
        // The .id() modifier destroys and recreates the entire view when route changes
        Group {
            switch currentRoute {
            case .splash:
                SplashLoadingView()
                    .onAppear {
                        print("🧭 SplashLoadingView: onAppear")
                        startTimeoutProtection()
                    }

            case .onboarding:
                OnboardingContainerView()
                    .onAppear {
                        print("🧭 OnboardingContainerView: onAppear")
                    }

            case .auth:
                AuthContainerView()
                    .onAppear {
                        print("🧭 AuthContainerView: onAppear")
                    }
                    .onDisappear {
                        print("🧭 AuthContainerView: onDisappear")
                    }

            case .main:
                MainTabView()
                    .onAppear {
                        print("🧭 ✅✅✅ MainTabView: onAppear - MAIN APP VISIBLE ✅✅✅")
                    }
            }
        }
        // CRITICAL: .id() forces SwiftUI to DESTROY and RECREATE the view when route changes
        // This is the nuclear option - it guarantees the old view is completely removed
        .id(currentRoute)
        // CRITICAL: Update route when auth state changes
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            print("🧭 RootView: ⚡⚡⚡ isAuthenticated CHANGED to \(isAuthenticated) ⚡⚡⚡")

            // STEP 1: Dismiss keyboard FIRST - this is critical
            dismissKeyboard()

            // STEP 2: Force window to resign first responder
            forceWindowRefresh()

            // STEP 3: Update route with animation to force SwiftUI to redraw
            withAnimation(.easeInOut(duration: 0.3)) {
                updateRoute(reason: "isAuthenticated changed to \(isAuthenticated)")
            }

            if isAuthenticated {
                // STEP 4: Call success handler after a brief delay to let animation complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🧭 RootView: Post-render - calling onAuthenticationSuccess")
                    appState.onAuthenticationSuccess()
                }
            }
        }
        .onChange(of: authService.isLoading) { _, isLoading in
            print("🧭 RootView: isLoading changed to \(isLoading)")
            updateRoute(reason: "isLoading changed to \(isLoading)")
        }
        .onChange(of: appState.hasSeenOnboarding) { _, hasSeen in
            print("🧭 RootView: hasSeenOnboarding changed to \(hasSeen)")
            updateRoute(reason: "hasSeenOnboarding changed to \(hasSeen)")
        }
        .onChange(of: splashTimeout) { _, timeout in
            if timeout {
                print("🧭 RootView: splashTimeout triggered")
                updateRoute(reason: "splashTimeout triggered")
            }
        }
        .onAppear {
            print("🧭 ══════════════════════════════════════════════════")
            print("🧭 RootView [v2]: APPEARED - NEW CODE RUNNING")
            print("🧭 RootView [v2]: isLoading=\(authService.isLoading)")
            print("🧭 RootView [v2]: isAuthenticated=\(authService.isAuthenticated)")
            print("🧭 RootView [v2]: hasSeenOnboarding=\(appState.hasSeenOnboarding)")
            print("🧭 ══════════════════════════════════════════════════")
            // Compute initial route
            updateRoute(reason: "onAppear")
        }
    }

    /// Update the current route based on app state
    /// This is called whenever any relevant state changes
    private func updateRoute(reason: String) {
        let effectiveIsLoading = splashTimeout ? false : authService.isLoading
        let newRoute = appState.computeRoute(
            isAuthLoading: effectiveIsLoading,
            isAuthenticated: authService.isAuthenticated
        )

        if newRoute != currentRoute {
            print("🧭 ══════════════════════════════════════════════════")
            print("🧭 ROUTE TRANSITION: \(currentRoute.rawValue) → \(newRoute.rawValue)")
            print("🧭 Reason: \(reason)")
            print("🧭 State: isLoading=\(authService.isLoading), isAuthenticated=\(authService.isAuthenticated)")
            print("🧭 ══════════════════════════════════════════════════")

            // Direct assignment - the .id(currentRoute) modifier handles view replacement
            currentRoute = newRoute
            print("🧭 ✅ currentRoute @State UPDATED to: \(currentRoute.rawValue)")
        } else {
            print("🧭 RootView: Route unchanged (\(currentRoute.rawValue)) - \(reason)")
        }
    }

    /// Dismiss keyboard aggressively
    private func dismissKeyboard() {
        // Method 1: Standard resignFirstResponder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Method 2: End editing on all windows
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.endEditing(true)
                }
            }
        }

        print("🧭 RootView: Keyboard dismissed")
    }

    /// Force window to refresh its layout
    private func forceWindowRefresh() {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    // Force layout pass
                    window.layoutIfNeeded()
                    // Force redraw
                    window.setNeedsLayout()
                    window.setNeedsDisplay()
                }
            }
        }
        print("🧭 RootView: Window refresh forced")
    }

    /// Start 2-second timeout protection for splash screen
    private func startTimeoutProtection() {
        guard !timeoutStarted else { return }
        timeoutStarted = true

        print("🧭 RootView: Starting 2-second splash timeout protection")

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                if authService.isLoading && !splashTimeout {
                    print("🧭 ⚠️ RootView: SPLASH TIMEOUT - forcing exit from splash")
                    splashTimeout = true
                }
            }
        }
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
        .onAppear {
            print("🧭 SplashLoadingView: appeared")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
