//
//  WhatVeroDoesView.swift
//  Vero
//
//  How it works - unified design system
//

import SwiftUI

struct WhatVeroDoesView: View {
    @EnvironmentObject var state: OnboardingState

    private let steps: [(icon: String, title: String, description: String, color: Color)] = [
        (
            "waveform.path.ecg",
            "We read your workouts",
            "Heart rate, duration, intensity—we see what your body experienced.",
            AppColors.navy
        ),
        (
            "hand.tap.fill",
            "You share quick context",
            "A simple check-in about sleep, energy, and how you feel.",
            AppColors.olive
        ),
        (
            "lightbulb.fill",
            "We explain what it means",
            "Why today felt harder. Why recovery is slower. What to do next.",
            AppColors.coral
        )
    ]

    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var ctaVisible = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HEADER SECTION
                VStack(spacing: AppSpacing.Layout.titleSpacing) {
                    Text("How it works")
                        .font(AppTypography.screenTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Understanding your effort in three steps")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 15)

                Spacer().frame(height: 32)

                // CARDS SECTION
                VStack(spacing: AppSpacing.Layout.cardSpacing + 4) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        LargeStepCard(
                            icon: step.icon,
                            title: step.title,
                            description: step.description,
                            accentColor: step.color
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .opacity(cardsVisible ? 1 : 0)
                .offset(y: cardsVisible ? 0 : 15)

                Spacer()

                // BOTTOM CTA
                VStack(spacing: AppSpacing.md) {
                    PrimaryButton("Continue", icon: "arrow.right") {
                        state.nextStep()
                    }

                    Text("Takes about 2 minutes")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.bottom, AppSpacing.Layout.bottomMargin)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 15)
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
            ctaVisible = true
        }
    }
}

// MARK: - Large Step Card

private struct LargeStepCard: View {
    let icon: String
    let title: String
    let description: String
    var accentColor: Color = AppColors.navy

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: AppSpacing.Icon.circleLarge, height: AppSpacing.Icon.circleLarge)

                Image(systemName: icon)
                    .font(.system(size: AppSpacing.Icon.xlarge, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.Layout.cardPadding + 4)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

#Preview {
    WhatVeroDoesView()
        .environmentObject(OnboardingState())
}
