//
//  EmptyStateView.swift
//  Insio Health
//
//  Premium empty state components - intentional and polished.
//

import SwiftUI

// MARK: - Generic Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var secondaryMessage: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.navy.opacity(0.12), AppColors.navy.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppColors.navy)
            }

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let secondary = secondaryMessage {
                    Text(secondary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xs)
                }
            }

            // Action buttons
            if actionTitle != nil || secondaryActionTitle != nil {
                VStack(spacing: AppSpacing.sm) {
                    if let actionTitle = actionTitle, let action = action {
                        Button(action: action) {
                            Text(actionTitle)
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(.white)
                                .frame(minWidth: 160)
                                .padding(.horizontal, AppSpacing.xl)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.navy)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(BounceButtonStyle())
                    }

                    if let secondaryTitle = secondaryActionTitle, let secondaryAction = secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(AppColors.navy)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
        }
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workouts Empty State

struct WorkoutsEmptyState: View {
    var onAddWorkout: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                icon: "figure.run",
                title: "Your workouts will appear here",
                message: "Complete a workout on your Apple Watch, or add one manually to start tracking your fitness journey.",
                secondaryMessage: "Insio syncs automatically with Apple Health",
                actionTitle: "Add Workout",
                action: onAddWorkout
            )
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        .padding(.top, AppSpacing.lg)
    }
}

// MARK: - Home Empty State

struct HomeEmptyState: View {
    var onConnectHealth: (() -> Void)? = nil
    var onAddWorkout: (() -> Void)? = nil
    var isConnecting: Bool = false
    var healthKitStatus: HealthKitService.AuthorizationStatus = .notDetermined
    var connectionState: HealthKitService.ConnectionState = .notConnected

    private var icon: String {
        switch connectionState {
        case .unavailable:
            return "exclamationmark.triangle"
        case .denied:
            return "xmark.circle"
        case .connectedNoData:
            return "checkmark.circle"
        default:
            return "heart.text.square"
        }
    }

    private var title: String {
        switch connectionState {
        case .unavailable:
            return "HealthKit Unavailable"
        case .denied:
            return "Health Access Denied"
        case .connectedNoData:
            return "No Workouts Found"
        default:
            return "Welcome to Insio"
        }
    }

    private var message: String {
        switch connectionState {
        case .unavailable:
            #if targetEnvironment(simulator)
            return "Health data is only available on a real device. You can still add workouts manually."
            #else
            return "Apple Health is not available on this device. You can still add workouts manually."
            #endif
        case .denied:
            return "Insio needs access to Apple Health to show your workouts. You can grant access in Settings, or add workouts manually."
        case .connectedNoData:
            return "Apple Health is connected but no workout data found yet. Complete a workout or add one manually to get started."
        default:
            return "Connect Apple Health to see your workouts and recovery insights, or add a workout manually to get started."
        }
    }

    private var secondaryMessage: String? {
        switch connectionState {
        case .unavailable, .denied:
            return nil
        case .connectedNoData:
            return "Workouts from your Apple Watch will appear here"
        default:
            return "Your data stays private and secure"
        }
    }

    private var buttonTitle: String {
        if isConnecting {
            return "Connecting..."
        }

        switch connectionState {
        case .denied:
            return "Open Settings"
        case .unavailable:
            return "Add Workout"
        case .connectedNoData:
            return "Add Workout"
        default:
            return "Connect Apple Health"
        }
    }

    private var showSecondaryButton: Bool {
        connectionState == .notConnected || connectionState == .denied
    }

    private var iconBackgroundColor: Color {
        switch connectionState {
        case .denied: return AppColors.coral
        case .connectedNoData: return AppColors.orange
        default: return AppColors.navy
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.lg) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    iconBackgroundColor.opacity(0.12),
                                    iconBackgroundColor.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)

                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(iconBackgroundColor)
                }

                VStack(spacing: AppSpacing.sm) {
                    Text(title)
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(message)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if let secondary = secondaryMessage {
                        Text(secondary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppSpacing.xs)
                    }
                }

                // Action buttons
                VStack(spacing: AppSpacing.sm) {
                    Button {
                        if connectionState == .denied {
                            // Open Settings
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } else if connectionState == .unavailable || connectionState == .connectedNoData {
                            // Just add workout
                            onAddWorkout?()
                        } else {
                            onConnectHealth?()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }

                            Text(buttonTitle)
                                .font(AppTypography.labelMedium)
                        }
                        .foregroundStyle(.white)
                        .frame(minWidth: 160)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(connectionState == .denied ? AppColors.coral : AppColors.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(BounceButtonStyle())
                    .disabled(isConnecting)

                    if showSecondaryButton {
                        Button {
                            onAddWorkout?()
                        } label: {
                            Text("Add Workout Instead")
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(AppColors.navy)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.vertical, AppSpacing.xxl)
            .padding(.horizontal, AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Trends Empty State

struct TrendsEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Trends coming soon",
                message: "Complete a few workouts to start seeing patterns in your fitness data.",
                secondaryMessage: "We need at least 3 workouts to show meaningful trends"
            )
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        .padding(.top, AppSpacing.lg)
    }
}

// MARK: - Preview

#Preview("Workouts Empty") {
    ScrollView {
        WorkoutsEmptyState(onAddWorkout: {})
    }
    .background(AppColors.background)
}

#Preview("Home Empty") {
    ScrollView {
        HomeEmptyState(onConnectHealth: {}, onAddWorkout: {})
    }
    .background(AppColors.background)
}

#Preview("Trends Empty") {
    ScrollView {
        TrendsEmptyState()
    }
    .background(AppColors.background)
}
