//
//  GoalSelectionView.swift
//  Vero
//
//  Goals selection - unified design system
//

import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject var state: OnboardingState

    @State private var headerVisible = false
    @State private var gridVisible = false
    @State private var footerVisible = false

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.Layout.cardSpacing),
        GridItem(.flexible(), spacing: AppSpacing.Layout.cardSpacing)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // FIXED HEADER
            VStack(alignment: .leading, spacing: 0) {
                // Back button
                Button {
                    state.previousStep()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.leading, -8)

                Spacer().frame(height: 8)

                // Title
                Text("What are your goals?")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer().frame(height: 8)

                // Subtitle
                Text("Select all that apply")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .padding(.top, 16)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 15)

            Spacer().frame(height: AppSpacing.Layout.sectionSpacing)

            // SCROLLABLE GOAL GRID
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: AppSpacing.Layout.cardSpacing) {
                    ForEach(FitnessGoal.allCases) { goal in
                        CompactGoalCard(
                            goal: goal,
                            isSelected: state.selectedGoals.contains(goal)
                        ) {
                            withAnimation(AppAnimation.springBouncy) {
                                if state.selectedGoals.contains(goal) {
                                    state.selectedGoals.remove(goal)
                                } else {
                                    state.selectedGoals.insert(goal)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.bottom, AppSpacing.Layout.sectionSpacing)
            }
            .opacity(gridVisible ? 1 : 0)
            .offset(y: gridVisible ? 0 : 15)

            // FIXED FOOTER
            VStack(spacing: AppSpacing.md) {
                // Selection indicator
                if !state.selectedGoals.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<min(state.selectedGoals.count, 4), id: \.self) { _ in
                            Circle()
                                .fill(AppColors.navy)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                PrimaryButton("Continue", isDisabled: state.selectedGoals.isEmpty) {
                    state.nextStep()
                }

                TextButton("Skip for now") {
                    state.nextStep()
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .padding(.bottom, AppSpacing.Layout.bottomMargin)
            .opacity(footerVisible ? 1 : 0)
            .offset(y: footerVisible ? 0 : 15)
        }
        .background(AppColors.background)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            gridVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.35)) {
            footerVisible = true
        }
    }
}

// MARK: - Compact Goal Card

private struct CompactGoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.navy : AppColors.navy.opacity(0.1))
                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                    Image(systemName: goal.icon)
                        .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                        .foregroundStyle(isSelected ? .white : AppColors.navy)
                }

                // Title
                Text(goal.rawValue)
                    .font(AppTypography.chipText)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // Subtitle
                Text(goal.subtitle)
                    .font(AppTypography.miniLabel)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? AppColors.navy.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.navy : AppColors.divider,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .standardShadow()
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Fitness Goal Extension

extension FitnessGoal {
    var subtitle: String {
        switch self {
        case .recovery: return "Rest & repair"
        case .endurance: return "Aerobic capacity"
        case .hardEffort: return "Push limits"
        case .strength: return "Power & muscle"
        case .mobility: return "Flexibility"
        case .conditioning: return "Heart health"
        case .generalFitness: return "Overall wellness"
        }
    }
}

#Preview {
    GoalSelectionView()
        .environmentObject(OnboardingState())
}
