//
//  NotificationSetupView.swift
//  Vero
//
//  Explain and request notification permissions
//

import SwiftUI

struct NotificationSetupView: View {
    @EnvironmentObject var state: OnboardingState
    @State private var showContent = false

    private let notificationTypes: [(icon: String, title: String, description: String, time: String?)] = [
        (
            "figure.cooldown",
            "Post-workout insights",
            "Get your workout interpretation right after you finish",
            nil
        ),
        (
            "sunrise.fill",
            "Next-day recovery",
            "Morning check-in with your recovery status",
            "8:00 AM"
        ),
        (
            "chart.line.uptrend.xyaxis",
            "Weekly trends",
            "Summary of your training patterns and progress",
            "Sundays"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                OnboardingBackButton()
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)

            Spacer()
                .frame(height: AppSpacing.xl)

            // Bell icon
            ZStack {
                Circle()
                    .fill(AppColors.navy.opacity(0.08))
                    .frame(width: 72, height: 72)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppColors.navy)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)

            Spacer()
                .frame(height: AppSpacing.lg)

            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Stay in the loop")
                    .font(AppTypography.displaySmall)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Timely notifications help you understand\nyour progress without opening the app.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .opacity(showContent ? 1 : 0)

            Spacer()
                .frame(height: AppSpacing.xl)

            // Notification types
            VStack(spacing: AppSpacing.sm) {
                ForEach(0..<notificationTypes.count, id: \.self) { index in
                    NotificationTypeCard(
                        icon: notificationTypes[index].icon,
                        title: notificationTypes[index].title,
                        description: notificationTypes[index].description,
                        time: notificationTypes[index].time
                    )
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .opacity(showContent ? 1 : 0)

            Spacer()

            // CTAs
            VStack(spacing: AppSpacing.xs) {
                PrimaryButton("Enable Notifications", icon: "bell.fill") {
                    // In real app, this would request notification permission
                    state.notificationsEnabled = true
                    state.nextStep()
                }

                TextButton("Maybe later") {
                    state.notificationsEnabled = false
                    state.nextStep()
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxl)
        }
        .onAppear {
            withAnimation(AppAnimation.entrance) {
                showContent = true
            }
        }
    }
}

// MARK: - Notification Type Card

struct NotificationTypeCard: View {
    let icon: String
    let title: String
    let description: String
    var time: String?

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.coral)
            }

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.textLineGap) {
                Text(title)
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            // Time badge
            if let time = time {
                Text(time)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.xxs)
                    .padding(.vertical, AppSpacing.xxxs)
                    .background(AppColors.divider)
                    .clipShape(Capsule())
            }
        }
        .cardPadding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
        .cardShadow()
    }
}

#Preview {
    NotificationSetupView()
        .environmentObject(OnboardingState())
}
