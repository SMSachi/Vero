//
//  ProfileView.swift
//  Vero
//
//  User profile - unified design system
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    // Animation states
    @State private var headerVisible = false
    @State private var contentVisible = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.sectionSpacing) {

                    // Header
                    ProfileHeader()
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 15)

                    // Stats
                    StatsSection()
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 15)

                    // Demo Controls
                    DemoSection(appState: appState)
                        .opacity(contentVisible ? 1 : 0)

                    // Settings
                    SettingsSection()
                        .opacity(contentVisible ? 1 : 0)

                    // About
                    AboutSection()
                        .opacity(contentVisible ? 1 : 0)
                }
                .padding(.top, AppSpacing.Layout.topPadding)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            contentVisible = true
        }
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    private var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: MockData.memberSince)
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.navy, AppColors.navy.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text(String(MockData.userName.prefix(1)))
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(MockData.userName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Member since \(memberSinceFormatted)")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Stats Section

struct StatsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your journey")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            HStack(spacing: AppSpacing.sm) {
                StatCard(
                    value: "\(MockData.totalWorkouts)",
                    label: "Workouts",
                    icon: "figure.run",
                    color: AppColors.navy
                )
                StatCard(
                    value: "\(MockData.currentStreak)",
                    label: "Streak",
                    icon: "flame.fill",
                    color: AppColors.coral
                )
                StatCard(
                    value: "\(MockData.longestStreak)",
                    label: "Best",
                    icon: "trophy.fill",
                    color: AppColors.olive
                )
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: AppSpacing.Icon.large, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(AppTypography.miniLabel)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

// MARK: - Demo Section

struct DemoSection: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Demo")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                ActionRow(
                    icon: "checkmark.circle.fill",
                    title: "Post-Workout Check-in",
                    subtitle: "Test the post-workout flow",
                    color: AppColors.olive
                ) {
                    appState.triggerPostWorkoutCheckIn()
                }

                Divider()
                    .padding(.leading, 56)

                ActionRow(
                    icon: "sunrise.fill",
                    title: "Next-Day Check-in",
                    subtitle: "Test morning recovery",
                    color: AppColors.coral
                ) {
                    appState.triggerNextDayCheckIn()
                }

                Divider()
                    .padding(.leading, 56)

                ActionRow(
                    icon: "arrow.counterclockwise",
                    title: "Reset Onboarding",
                    subtitle: "Go through setup again",
                    color: AppColors.navy
                ) {
                    appState.resetOnboarding()
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Settings")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                SettingsRowItem(icon: "bell.fill", title: "Notifications", color: .red)
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "heart.fill", title: "Health Data", color: .pink)
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "applewatch", title: "Watch", color: AppColors.navy)
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "gearshape.fill", title: "Preferences", color: .gray)
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("About")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                SettingsRowItem(icon: "questionmark.circle.fill", title: "Help", color: AppColors.olive)
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "doc.text.fill", title: "Privacy", color: .blue)
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "info.circle.fill", title: "About Vero", color: .purple)
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            // Version
            Text("Version 1.0.0")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.md)
        }
    }
}

// MARK: - Action Row

struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(isPressed ? AppColors.divider.opacity(0.5) : Color.clear)
        }
        .buttonStyle(RowButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Settings Row Item

struct SettingsRowItem: View {
    let icon: String
    let title: String
    let color: Color

    @State private var isPressed = false

    var body: some View {
        Button {
            // Action placeholder
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(isPressed ? AppColors.divider.opacity(0.5) : Color.clear)
        }
        .buttonStyle(RowButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Row Button Style

struct RowButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
            .animation(AppAnimation.smoothFast, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
