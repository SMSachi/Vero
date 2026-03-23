//
//  OnboardingCoordinator.swift
//  Insio Health
//
//  Manages onboarding flow state and navigation
//

import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case cinematicIntro
    case whatInsioDoes
    case healthPermission
    case goalSelection
    case contextPreferences
    case notificationSetup
    case complete

    var progress: Double {
        switch self {
        case .cinematicIntro: return 0
        case .whatInsioDoes: return 0.15
        case .healthPermission: return 0.30
        case .goalSelection: return 0.50
        case .contextPreferences: return 0.70
        case .notificationSetup: return 0.85
        case .complete: return 1.0
        }
    }

    var showsProgress: Bool {
        switch self {
        case .cinematicIntro, .complete: return false
        default: return true
        }
    }

    var showsBackButton: Bool {
        switch self {
        case .cinematicIntro, .whatInsioDoes, .complete: return false
        default: return true
        }
    }
}

// MARK: - Onboarding State

@MainActor
class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .cinematicIntro

    // User selections
    @Published var selectedGoals: Set<UserGoal> = []
    @Published var primaryGoal: UserGoal? = nil
    @Published var trackWaterIntake: Bool = true
    @Published var trackNutrition: Bool = false
    @Published var trackNotes: Bool = true
    @Published var trackStressEnergy: Bool = true
    @Published var notificationsEnabled: Bool = true

    /// Whether to show weight-related UI based on user's goal
    var shouldShowWeightUI: Bool {
        primaryGoal?.showsWeightUI ?? selectedGoals.contains(.weightLoss)
    }

    // Reference to app state for completion
    weak var appState: AppState?

    func nextStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            let allSteps = OnboardingStep.allCases
            if let currentIndex = allSteps.firstIndex(of: currentStep),
               currentIndex < allSteps.count - 1 {
                currentStep = allSteps[currentIndex + 1]
            }
        }
    }

    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let allSteps = OnboardingStep.allCases
            if let currentIndex = allSteps.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = allSteps[currentIndex - 1]
            }
        }
    }

    func completeOnboarding() {
        // Save user goals to persistent service
        UserGoalService.shared.setSelectedGoals(selectedGoals, primaryGoal: primaryGoal)

        appState?.completeOnboarding()
    }
}

// MARK: - User Goal

/// Primary user goal - determines which UI elements and insights are shown.
/// CRITICAL: Weight UI is ONLY shown when goal == .weightLoss
enum UserGoal: String, CaseIterable, Identifiable, Codable {
    case performance = "Performance"
    case consistency = "Consistency"
    case recovery = "Recovery"
    case weightLoss = "Weight Loss"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .performance: return "flame.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .recovery: return "heart.circle.fill"
        case .weightLoss: return "scalemass.fill"
        }
    }

    var description: String {
        switch self {
        case .performance: return "Maximize workout performance and output"
        case .consistency: return "Build lasting workout habits"
        case .recovery: return "Optimize rest and prevent overtraining"
        case .weightLoss: return "Track weight and body composition"
        }
    }

    /// Whether weight-related UI should be shown for this goal
    var showsWeightUI: Bool {
        self == .weightLoss
    }
}

/// Legacy alias for backward compatibility
typealias FitnessGoal = UserGoal

// MARK: - Onboarding Container View

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var state = OnboardingState()

    var body: some View {
        ZStack {
            // Background
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with Skip button
                HStack {
                    // Back button (when applicable)
                    if state.currentStep.showsBackButton {
                        OnboardingBackButton()
                    }

                    Spacer()

                    // Skip button (always visible except on complete screen)
                    if state.currentStep != .complete {
                        Button {
                            skipOnboarding()
                        } label: {
                            Text("Skip")
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.sm)
                .frame(height: 44)

                // Progress bar (when applicable)
                if state.currentStep.showsProgress {
                    OnboardingProgressBar(progress: state.currentStep.progress)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Content
                Group {
                    switch state.currentStep {
                    case .cinematicIntro:
                        CinematicIntroView()
                    case .whatInsioDoes:
                        WhatInsioDoesView()
                    case .healthPermission:
                        HealthPermissionIntroView()
                    case .goalSelection:
                        GoalSelectionView()
                    case .contextPreferences:
                        ContextPreferencesView()
                    case .notificationSetup:
                        NotificationSetupView()
                    case .complete:
                        OnboardingCompleteView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
            }
        }
        .environmentObject(state)
        .onAppear {
            print("🧭 OnboardingContainerView: appeared")
            state.appState = appState
        }
    }

    private func skipOnboarding() {
        print("🧭 OnboardingContainerView: Skip tapped - routing to auth")
        appState.skipOnboarding()
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.divider)
                    .frame(height: 4)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.navy)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Back Button

struct OnboardingBackButton: View {
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        Button {
            state.previousStep()
        } label: {
            HStack(spacing: AppSpacing.xxxs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(AppTypography.buttonSmall)
            }
            .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Previews

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
}
