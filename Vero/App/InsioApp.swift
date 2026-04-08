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
        print("🚀 InsioApp: init()")

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
                    print("🚀 APP BODY: WindowGroup appeared")
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

    /// Local state that SwiftUI definitely observes
    @State private var showMainApp = false

    var body: some View {
        ZStack {
            if showMainApp {
                MainTabView()
                    .transition(.opacity)
                    .onAppear {
                        print("🧭 ✅ MainTabView APPEARED")
                        appState.onAuthenticationSuccess()
                    }
            } else {
                authFlow
                    .transition(.opacity)
            }
        }
        .id(showMainApp) // CRITICAL: Forces complete view replacement
        .animation(.easeInOut(duration: 0.3), value: showMainApp)
        .onAppear {
            showMainApp = authService.isAuthenticated
            print("🧭 AppRootView onAppear: showMainApp=\(showMainApp)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            print("🧭 NOTIFICATION RECEIVED - setting showMainApp=true")
            withAnimation {
                showMainApp = true
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

    // MARK: - Auth Helpers

    /// Called when user successfully authenticates
    /// IMPORTANT: This must NOT block UI rendering - restore runs in background
    func onAuthenticationSuccess() {
        print("🧭 ══════════════════════════════════════════════════")
        print("🧭 AppState: onAuthenticationSuccess() - STARTING")
        print("🧭 AppState: UI should render MainTabView NOW")
        print("🧭 AppState: Background restore will start after UI renders")
        print("🧭 ══════════════════════════════════════════════════")

        // Check for pending check-ins FIRST (quick, local operation)
        checkForPendingCheckIns()

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
    /// Called when MainTabView appears (after auth success) and on scene phase changes.
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

        // Trigger next-day check-in if pending (PART 6 fix)
        if workoutMonitor.hasPendingNextDayCheckIn,
           let workout = workoutMonitor.pendingWorkoutForNextDayCheckIn,
           workoutMonitor.shouldShowNextDayCheckIn() {
            print("📱 AppState: ⚠️ TRIGGERING next-day check-in for workout \(workout.id)")
            // Small delay to let UI settle first
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
        // Prevent duplicate triggers
        guard !showPostWorkoutCheckIn else {
            print("📱 AppState: Post-workout check-in already showing, skipping duplicate trigger")
            return
        }
        checkInWorkout = workout
        showPostWorkoutCheckIn = true
    }

    func triggerNextDayCheckIn(for workoutId: UUID? = nil) {
        // Prevent duplicate triggers
        guard !showNextDayCheckIn else {
            print("📱 AppState: Next-day check-in already showing, skipping duplicate trigger")
            return
        }
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
        .onAppear {
            print("🧭 SplashLoadingView: appeared")
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
