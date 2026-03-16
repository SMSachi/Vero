//
//  ContextPreferencesView.swift
//  Vero
//
//  Daily context - unified design system
//

import SwiftUI

struct ContextPreferencesView: View {
    @EnvironmentObject var state: OnboardingState

    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var footerVisible = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HEADER (fixed)
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
                    Text("Daily context")
                        .font(AppTypography.screenTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer().frame(height: 8)

                    // Subtitle
                    Text("What would you like to track?")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.top, 16)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 15)

                // CENTERED CARD GROUP
                Spacer()

                VStack(spacing: AppSpacing.Layout.cardSpacing) {
                    ContextToggleCard(
                        icon: "drop.fill",
                        iconColor: .blue,
                        title: "Water intake",
                        description: "Track daily hydration",
                        isOn: $state.trackWaterIntake
                    )

                    ContextToggleCard(
                        icon: "fork.knife",
                        iconColor: AppColors.orange,
                        title: "Nutrition",
                        description: "Log meals and nutrients",
                        isOn: $state.trackNutrition
                    )

                    ContextToggleCard(
                        icon: "bolt.fill",
                        iconColor: AppColors.coral,
                        title: "Stress & energy",
                        description: "Quick mood check-ins",
                        isOn: $state.trackStressEnergy
                    )

                    ContextToggleCard(
                        icon: "note.text",
                        iconColor: AppColors.olive,
                        title: "Notes",
                        description: "Add context to your day",
                        isOn: $state.trackNotes
                    )
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .opacity(cardsVisible ? 1 : 0)
                .offset(y: cardsVisible ? 0 : 15)

                Spacer()

                // FOOTER (fixed)
                VStack(spacing: AppSpacing.Layout.cardSpacing) {
                    // Info note
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                            .foregroundStyle(AppColors.coral)

                        Text("You can change these anytime in Settings")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    PrimaryButton("Continue") {
                        state.nextStep()
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.bottom, AppSpacing.Layout.bottomMargin)
                .opacity(footerVisible ? 1 : 0)
                .offset(y: footerVisible ? 0 : 15)
            }
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
            cardsVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.4)) {
            footerVisible = true
        }
    }
}

// MARK: - Context Toggle Card

private struct ContextToggleCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(AppAnimation.springBouncy) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isOn ? iconColor : iconColor.opacity(0.12))
                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.Icon.large, weight: .medium))
                        .foregroundStyle(isOn ? .white : iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(description)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Toggle indicator
                ZStack {
                    Circle()
                        .fill(isOn ? AppColors.navy : AppColors.divider)
                        .frame(width: 24, height: 24)

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(isOn ? iconColor.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(
                        isOn ? iconColor.opacity(0.3) : AppColors.divider,
                        lineWidth: isOn ? 2 : 1
                    )
            )
            .standardShadow()
        }
        .buttonStyle(BounceButtonStyle())
    }
}

#Preview {
    ContextPreferencesView()
        .environmentObject(OnboardingState())
}
