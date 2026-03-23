//
//  ProfileView.swift
//  Insio Health
//
//  User profile - unified design system
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SupabaseSyncService
    @StateObject private var premiumManager = PremiumManager.shared

    // Animation states
    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var showSignOutConfirmation = false

    // Settings sheets
    @State private var showNotificationSettings = false
    @State private var showHealthDataSettings = false
    @State private var showWatchSettings = false
    @State private var showPreferences = false
    @State private var showPaywall = false
    @State private var showAccountDeletion = false

    // Stats (loaded in onAppear to avoid blocking body evaluation)
    @State private var totalWorkouts: Int = 0
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var latestWorkout: Workout? = nil

    // Real stats service
    private let persistenceService = PersistenceService.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.sectionSpacing) {

                    // Header
                    ProfileHeader(
                        userName: displayName,
                        memberSince: memberSinceDate,
                        isAuthenticated: authService.isAuthenticated
                    )
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 15)

                    // Premium Section
                    PremiumSection(
                        currentTier: premiumManager.currentTier,
                        isInTrial: premiumManager.isInTrial,
                        trialDaysRemaining: premiumManager.trialDaysRemaining,
                        onShowPaywall: { showPaywall = true }
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 15)

                    // Account Section
                    AccountSection(
                        isAuthenticated: authService.isAuthenticated,
                        isSyncing: syncService.isSyncing,
                        lastSyncDate: syncService.lastSyncDate,
                        onSignOut: { showSignOutConfirmation = true },
                        onSync: performSync,
                        onDeleteAccount: { showAccountDeletion = true }
                    )
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 15)

                    // Stats (values loaded in onAppear)
                    StatsSection(
                        totalWorkouts: totalWorkouts,
                        currentStreak: currentStreak,
                        longestStreak: longestStreak
                    )
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 15)

                    // Demo Controls (only show in debug)
                    #if DEBUG
                    DemoSection(appState: appState, latestWorkout: latestWorkout)
                        .opacity(contentVisible ? 1 : 0)
                    #endif

                    // Settings
                    SettingsSection(
                        showNotificationSettings: $showNotificationSettings,
                        showHealthDataSettings: $showHealthDataSettings,
                        showWatchSettings: $showWatchSettings,
                        showPreferences: $showPreferences
                    )
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
            loadStats()
            startAnimations()
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await appState.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out? Your data will remain on this device.")
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showHealthDataSettings) {
            HealthDataSettingsView()
        }
        .sheet(isPresented: $showWatchSettings) {
            WatchSettingsView()
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showAccountDeletion) {
            AccountDeletionView()
        }
    }

    private var displayName: String {
        if authService.isAuthenticated {
            // Try to get name from user metadata (AnyJSON requires pattern matching)
            if let metadata = authService.currentUser?.userMetadata,
               let nameValue = metadata["full_name"],
               case .string(let fullName) = nameValue,
               !fullName.isEmpty {
                return fullName
            }
            // Fall back to email
            if let email = authService.currentUser?.email {
                return email.components(separatedBy: "@").first ?? email
            }
        }
        return "Guest"
    }

    private var memberSinceDate: Date {
        // Try to get user creation date from auth
        if authService.isAuthenticated,
           let createdAt = authService.currentUser?.createdAt {
            return createdAt
        }
        // Default to app install date (approximated by first launch)
        return UserDefaults.standard.object(forKey: "firstLaunchDate") as? Date ?? Date()
    }

    private func loadStats() {
        // Load stats in onAppear to avoid blocking body evaluation
        totalWorkouts = persistenceService.fetchRecentWorkouts(limit: 1000).count
        currentStreak = persistenceService.calculateCurrentStreak()
        longestStreak = persistenceService.calculateLongestStreak()
        latestWorkout = persistenceService.fetchLatestWorkout()
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            contentVisible = true
        }
    }

    private func performSync() {
        Task {
            await syncService.performFullSync()
        }
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    let userName: String
    let memberSince: Date
    let isAuthenticated: Bool

    private var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: memberSince)
    }

    private var initials: String {
        let components = userName.split(separator: " ")
        if components.count > 1 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        }
        return String(userName.prefix(1)).uppercased()
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

                Text(initials)
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    if isAuthenticated {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.olive)
                    }
                    Text("Member since \(memberSinceFormatted)")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Premium Section

struct PremiumSection: View {
    let currentTier: SubscriptionTier
    let isInTrial: Bool
    let trialDaysRemaining: Int?
    let onShowPaywall: () -> Void

    private var isPaid: Bool { currentTier != .free }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Subscription")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            Button(action: onShowPaywall) {
                HStack(spacing: AppSpacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: tierColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                        Image(systemName: tierIcon)
                            .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(tierTitle)
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppColors.textPrimary)

                            TierBadge(tier: currentTier)
                        }

                        if isInTrial, let days = trialDaysRemaining {
                            Text("\(days) days left in trial")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                        } else {
                            Text(tierSubtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    if currentTier == .free {
                        Text("Upgrade")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.navy)
                            .clipShape(Capsule())
                    } else if currentTier == .plus {
                        Text("Upgrade to Pro")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(AppColors.navy)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColors.navyTint)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }

    private var tierTitle: String {
        switch currentTier {
        case .free: return "Upgrade to Premium"
        case .plus: return "Insio Plus"
        case .pro: return "Insio Pro"
        }
    }

    private var tierSubtitle: String {
        switch currentTier {
        case .free: return "Unlock AI insights & more"
        case .plus: return "Weekly AI insights active"
        case .pro: return "All features unlocked"
        }
    }

    private var tierIcon: String {
        switch currentTier {
        case .free: return "sparkles"
        case .plus: return "star.fill"
        case .pro: return "crown.fill"
        }
    }

    private var tierColors: [Color] {
        switch currentTier {
        case .free: return [AppColors.textSecondary, AppColors.textSecondary.opacity(0.7)]
        case .plus: return [AppColors.olive, AppColors.olive.opacity(0.7)]
        case .pro: return [AppColors.navy, AppColors.navy.opacity(0.7)]
        }
    }
}

// MARK: - Account Section

struct AccountSection: View {
    let isAuthenticated: Bool
    let isSyncing: Bool
    let lastSyncDate: Date?
    let onSignOut: () -> Void
    let onSync: () -> Void
    var onDeleteAccount: (() -> Void)? = nil

    private var lastSyncFormatted: String? {
        guard let date = lastSyncDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Account")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                if isAuthenticated {
                    // Sync row
                    Button(action: onSync) {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.olive.opacity(0.12))
                                    .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.olive))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                                        .foregroundStyle(AppColors.olive)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isSyncing ? "Syncing..." : "Sync Now")
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.textPrimary)

                                if let lastSync = lastSyncFormatted {
                                    Text("Last synced \(lastSync)")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                } else {
                                    Text("Sync your data to the cloud")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .disabled(isSyncing)

                    Divider()
                        .padding(.leading, 56)

                    // Sign out row
                    Button(action: onSignOut) {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.coral.opacity(0.12))
                                    .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                                    .foregroundStyle(AppColors.coral)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign Out")
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.textPrimary)

                                Text("Your data remains on this device")
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
                    }

                    // Delete account row
                    if let onDelete = onDeleteAccount {
                        Divider()
                            .padding(.leading, 56)

                        Button(action: onDelete) {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.error.opacity(0.12))
                                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                                    Image(systemName: "trash.fill")
                                        .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                                        .foregroundStyle(AppColors.error)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete Account")
                                        .font(AppTypography.cardTitle)
                                        .foregroundStyle(AppColors.error)

                                    Text("Permanently delete your account and data")
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
                        }
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

// MARK: - Stats Section

struct StatsSection: View {
    let totalWorkouts: Int
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your journey")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            HStack(spacing: AppSpacing.sm) {
                StatCard(
                    value: "\(totalWorkouts)",
                    label: "Workouts",
                    icon: "figure.run",
                    color: AppColors.navy
                )
                StatCard(
                    value: "\(currentStreak)",
                    label: "Streak",
                    icon: "flame.fill",
                    color: AppColors.coral
                )
                StatCard(
                    value: "\(longestStreak)",
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
    let latestWorkout: Workout?  // Passed in to avoid persistence calls during body

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
                    subtitle: latestWorkout != nil ? "Test with latest workout" : "No workout available",
                    color: latestWorkout != nil ? AppColors.olive : AppColors.textTertiary
                ) {
                    if let workout = latestWorkout {
                        appState.triggerPostWorkoutCheckIn(for: workout)
                    }
                }
                .disabled(latestWorkout == nil)

                Divider()
                    .padding(.leading, 56)

                ActionRow(
                    icon: "sunrise.fill",
                    title: "Next-Day Check-in",
                    subtitle: latestWorkout != nil ? "Test morning recovery" : "No workout available",
                    color: latestWorkout != nil ? AppColors.coral : AppColors.textTertiary
                ) {
                    if let workout = latestWorkout {
                        appState.triggerNextDayCheckIn(for: workout.id)
                    }
                }
                .disabled(latestWorkout == nil)

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
    @Binding var showNotificationSettings: Bool
    @Binding var showHealthDataSettings: Bool
    @Binding var showWatchSettings: Bool
    @Binding var showPreferences: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Settings")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                SettingsRowItem(icon: "bell.fill", title: "Notifications", color: .red) {
                    showNotificationSettings = true
                }
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "heart.fill", title: "Health Data", color: .pink) {
                    showHealthDataSettings = true
                }
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "applewatch", title: "Watch", color: AppColors.navy) {
                    showWatchSettings = true
                }
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "gearshape.fill", title: "Preferences", color: .gray) {
                    showPreferences = true
                }
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
    @State private var showHelp = false
    @State private var showPrivacy = false
    @State private var showAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("About")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: 0) {
                SettingsRowItem(icon: "questionmark.circle.fill", title: "Help", color: AppColors.olive) {
                    showHelp = true
                }
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "doc.text.fill", title: "Privacy", color: .blue) {
                    showPrivacy = true
                }
                Divider().padding(.leading, 56)
                SettingsRowItem(icon: "info.circle.fill", title: "About Insio", color: .purple) {
                    showAbout = true
                }
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
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyView()
        }
        .sheet(isPresented: $showAbout) {
            AboutInsioView()
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
        .environmentObject(AuthService.shared)
        .environmentObject(SupabaseSyncService.shared)
}
