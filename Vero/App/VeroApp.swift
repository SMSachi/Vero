//
//  VeroApp.swift
//  Vero
//
//  Main app entry point with onboarding and root navigation
//

import SwiftUI

@main
struct VeroApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var showPostWorkoutCheckIn = false
    @Published var showNextDayCheckIn = false
    @Published var selectedWorkoutForSummary: Workout?

    // Demo state
    @Published var checkInWorkout: Workout = MockData.detailedWorkout

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }

    func resetOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = false
        }
    }

    // Demo triggers
    func triggerPostWorkoutCheckIn(for workout: Workout = MockData.detailedWorkout) {
        checkInWorkout = workout
        showPostWorkoutCheckIn = true
    }

    func triggerNextDayCheckIn() {
        showNextDayCheckIn = true
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
