//
//  OnboardingCoordinator.swift
//  Vero
//
//  Manages onboarding flow state and navigation
//

import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case cinematicIntro
    case whatVeroDoes
    case healthPermission
    case goalSelection
    case contextPreferences
    case notificationSetup
    case complete

    var progress: Double {
        switch self {
        case .cinematicIntro: return 0
        case .whatVeroDoes: return 0.15
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
        case .cinematicIntro, .whatVeroDoes, .complete: return false
        default: return true
        }
    }
}

// MARK: - Onboarding State

@MainActor
class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .cinematicIntro

    // User selections
    @Published var selectedGoals: Set<FitnessGoal> = []
    @Published var trackWaterIntake: Bool = true
    @Published var trackNutrition: Bool = false
    @Published var trackNotes: Bool = true
    @Published var trackStressEnergy: Bool = true
    @Published var notificationsEnabled: Bool = true

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
        appState?.completeOnboarding()
    }
}

// MARK: - Fitness Goal

enum FitnessGoal: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case endurance = "Endurance"
    case hardEffort = "Hard effort"
    case strength = "Strength"
    case mobility = "Mobility"
    case conditioning = "Conditioning"
    case generalFitness = "General fitness"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recovery: return "arrow.trianglehead.2.clockwise"
        case .endurance: return "figure.run"
        case .hardEffort: return "flame.fill"
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.flexibility"
        case .conditioning: return "heart.circle.fill"
        case .generalFitness: return "figure.mixed.cardio"
        }
    }
}

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
                // Progress bar (when applicable)
                if state.currentStep.showsProgress {
                    OnboardingProgressBar(progress: state.currentStep.progress)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, AppSpacing.sm)
                }

                // Content
                Group {
                    switch state.currentStep {
                    case .cinematicIntro:
                        CinematicIntroView()
                    case .whatVeroDoes:
                        WhatVeroDoesView()
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
            state.appState = appState
        }
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
