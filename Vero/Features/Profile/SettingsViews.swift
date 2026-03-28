//
//  SettingsViews.swift
//  Insio Health
//
//  Settings screens for notifications, health data, watch, and preferences.
//

import SwiftUI
import UserNotifications

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("postWorkoutReminder") private var postWorkoutReminder = true
    @AppStorage("morningCheckIn") private var morningCheckIn = true
    @AppStorage("weeklyReport") private var weeklyReport = true
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional: return AppColors.olive
        case .denied: return AppColors.coral
        default: return AppColors.textTertiary
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .authorized: return "Enabled"
        case .provisional: return "Provisional"
        case .denied: return "Denied"
        case .notDetermined: return "Not Enabled"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var isEnabled: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: isEnabled ? "bell.badge.fill" : "bell.slash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(statusColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(AppTypography.cardTitle)
                            Text(statusText)
                                .font(AppTypography.caption)
                                .foregroundStyle(statusColor)
                        }

                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.xs)
                } footer: {
                    if authorizationStatus == .denied {
                        Text("Notifications are disabled. Open Settings to enable them.")
                            .foregroundStyle(AppColors.coral)
                    } else if isEnabled {
                        Text("You'll receive reminders for check-ins and updates.")
                    } else {
                        Text("Enable notifications to get reminders for post-workout check-ins.")
                    }
                }

                // Actions Section
                if !isEnabled {
                    Section {
                        if authorizationStatus == .notDetermined {
                            Button {
                                requestNotificationPermission()
                            } label: {
                                HStack {
                                    Text(isRequesting ? "Requesting..." : "Enable Notifications")
                                        .foregroundStyle(AppColors.navy)
                                    Spacer()
                                    if isRequesting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(isRequesting)
                        }

                        if authorizationStatus == .denied {
                            Button("Open Settings") {
                                openNotificationSettings()
                            }
                        }
                    }
                }

                // Reminder Preferences Section
                Section {
                    Toggle(isOn: $postWorkoutReminder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Post-Workout Check-in")
                            Text("Reminder to log how you felt")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    Toggle(isOn: $morningCheckIn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Morning Recovery")
                            Text("Next-day recovery check-in")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    Toggle(isOn: $weeklyReport) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Summary")
                            Text("Your training overview")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("Reminder Preferences")
                } footer: {
                    Text("Push notifications for these reminders coming in a future update. Your preferences are saved.")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        isRequesting = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            DispatchQueue.main.async {
                checkNotificationStatus()
                isRequesting = false
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Health Data Settings

struct HealthDataSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var healthKitService = HealthKitService.shared
    @State private var isRequesting = false
    @State private var showingDebugInfo = false

    /// Explicit connection state for clear user feedback
    private var connectionState: HealthKitService.ConnectionState {
        healthKitService.connectionState
    }

    private var statusColor: Color {
        switch connectionState {
        case .connectedWithData: return AppColors.olive
        case .connectedNoData: return AppColors.orange
        case .denied: return AppColors.coral
        case .notConnected, .unavailable: return AppColors.textTertiary
        }
    }

    private var statusText: String {
        switch connectionState {
        case .connectedWithData: return "Connected"
        case .connectedNoData: return "Connected - No Workouts"
        case .denied: return "Access Denied"
        case .notConnected: return "Not Connected"
        case .unavailable: return healthKitService.isSimulator ? "Unavailable (Simulator)" : "Unavailable"
        }
    }

    private var statusIcon: String {
        connectionState.icon
    }

    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: statusIcon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(statusColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                                .font(AppTypography.cardTitle)
                            Text(statusText)
                                .font(AppTypography.caption)
                                .foregroundStyle(statusColor)
                        }

                        Spacer()

                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                } footer: {
                    statusFooterText
                }

                // Simulator Warning Section
                if healthKitService.isSimulator && healthKitService.authorizationStatus == .unavailable {
                    Section {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 24))
                                .foregroundStyle(AppColors.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Running on Simulator")
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.textPrimary)

                                Text("Health data is only available on a real device. Use a physical iPhone to test HealthKit features.")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                }

                // Actions Section
                if connectionState != .unavailable {
                    Section {
                        // Connect button
                        if !connectionState.isConnected {
                            Button {
                                requestHealthAccess()
                            } label: {
                                HStack {
                                    Image(systemName: "heart.text.square.fill")
                                        .foregroundStyle(AppColors.navy)
                                    Text(isRequesting ? "Requesting Access..." : "Connect Apple Health")
                                        .foregroundStyle(AppColors.navy)
                                    Spacer()
                                    if isRequesting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppColors.textTertiary)
                                    }
                                }
                            }
                            .disabled(isRequesting)
                        }

                        // Open Settings if denied
                        if connectionState == .denied {
                            Button {
                                openHealthSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                        .foregroundStyle(AppColors.textSecondary)
                                    Text("Open Health Settings")
                                        .foregroundStyle(AppColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                            }
                        }

                        // Refresh status button
                        Button {
                            refreshStatus()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(AppColors.textSecondary)
                                Text("Refresh Status")
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                            }
                        }
                        .disabled(isRequesting)

                        // Open Health app
                        Button {
                            openHealthApp()
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Open Health App")
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                }

                // Data Types Section
                Section {
                    DataTypeRow(icon: "figure.run", title: "Workouts", status: "Read", isConnected: connectionState.isConnected)
                    DataTypeRow(icon: "heart.fill", title: "Heart Rate", status: "Read", isConnected: connectionState.isConnected)
                    DataTypeRow(icon: "bed.double.fill", title: "Sleep Analysis", status: "Read", isConnected: connectionState.isConnected)
                    DataTypeRow(icon: "waveform.path.ecg", title: "HRV", status: "Read", isConnected: connectionState.isConnected)
                    DataTypeRow(icon: "drop.fill", title: "Water Intake", status: "Read", isConnected: connectionState.isConnected)
                } header: {
                    Text("Data Types")
                } footer: {
                    Text("Insio requests read-only access to these data types. You can customize permissions in the Health app.")
                }

                // Debug Section (tap to show)
                Section {
                    Button {
                        showingDebugInfo.toggle()
                    } label: {
                        HStack {
                            Text("Debug Info")
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Image(systemName: showingDebugInfo ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    if showingDebugInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            debugRow("Status", healthKitService.authorizationStatus.rawValue)
                            debugRow("HealthKit Available", healthKitService.isHealthKitAvailable ? "Yes" : "No")
                            debugRow("Verified Read Access", healthKitService.hasVerifiedReadAccess ? "Yes" : "No")
                            debugRow("Is Simulator", healthKitService.isSimulator ? "Yes" : "No")
                            if let error = healthKitService.lastError {
                                debugRow("Last Error", error)
                            }
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .navigationTitle("Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("🏥 HealthDataSettingsView: onAppear - checking status")
                healthKitService.checkAuthorizationStatus()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Re-check authorization when returning from Settings
                if newPhase == .active && oldPhase == .inactive {
                    print("🏥 HealthDataSettingsView: Scene became active - refreshing status")
                    refreshStatus()
                }
            }
        }
    }

    @ViewBuilder
    private var statusFooterText: some View {
        switch connectionState {
        case .connectedWithData:
            Text("Your health data is being synced. Insio reads your data but never writes to Apple Health.")
        case .connectedNoData:
            VStack(alignment: .leading, spacing: 4) {
                Text("Connected to Apple Health, but no workout data found yet.")
                    .foregroundStyle(AppColors.orange)
                Text("Complete a workout on your Apple Watch or iPhone to see data here.")
            }
            .foregroundStyle(AppColors.textSecondary)
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Text("Access was denied. To enable:")
                    .foregroundStyle(AppColors.coral)
                Text("1. Open Settings app")
                Text("2. Go to Privacy & Security > Health > Insio")
                Text("3. Enable the data types you want to share")
            }
            .foregroundStyle(AppColors.textSecondary)
        case .notConnected:
            Text("Connect Apple Health to automatically import your workouts and health metrics.")
        case .unavailable:
            if healthKitService.isSimulator {
                Text("HealthKit is not available on the iOS Simulator. Test on a real device.")
                    .foregroundStyle(AppColors.orange)
            } else {
                Text("HealthKit is not available on this device.")
                    .foregroundStyle(AppColors.coral)
            }
        }
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private func requestHealthAccess() {
        print("🏥 HealthDataSettingsView: requestHealthAccess() called")
        isRequesting = true

        Task {
            let success = await healthKitService.requestAuthorization()
            print("🏥 HealthDataSettingsView: Authorization result: \(success)")

            await MainActor.run {
                isRequesting = false
            }
        }
    }

    private func refreshStatus() {
        print("🏥 HealthDataSettingsView: refreshStatus() called")
        isRequesting = true

        Task {
            await healthKitService.refreshAuthorizationStatus()

            await MainActor.run {
                isRequesting = false
            }
        }
    }

    private func openHealthSettings() {
        // Open the app's settings page where Health permissions can be changed
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

struct DataTypeRow: View {
    let icon: String
    let title: String
    let status: String
    var isConnected: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isConnected ? AppColors.navy : AppColors.textTertiary)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(isConnected ? AppColors.textPrimary : AppColors.textSecondary)
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.olive)
            } else {
                Text(status)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

// MARK: - Watch Settings

struct WatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppColors.navy.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: "applewatch")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(AppColors.navy)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Watch Integration")
                                .font(AppTypography.cardTitle)
                            Text("Via Apple Health")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                } footer: {
                    Text("Insio imports workouts through Apple Health. No dedicated Watch app is required.")
                }

                Section {
                    WatchFeatureRow(
                        icon: "figure.run",
                        title: "Automatic Workout Import",
                        description: "Workouts recorded on your Apple Watch appear in Insio automatically."
                    )

                    WatchFeatureRow(
                        icon: "heart.fill",
                        title: "Heart Rate Data",
                        description: "Heart rate metrics from your Watch workouts are included for deeper insights."
                    )

                    WatchFeatureRow(
                        icon: "bed.double.fill",
                        title: "Sleep Tracking",
                        description: "Sleep data from your Watch helps calculate your recovery readiness."
                    )
                } header: {
                    Text("What Syncs")
                }

                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("To get the most from Insio:")
                            .font(AppTypography.cardSubtitle)
                            .foregroundStyle(AppColors.textPrimary)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            BulletPoint(text: "Ensure your Apple Watch is paired in the Watch app")
                            BulletPoint(text: "Grant Insio access to Apple Health data")
                            BulletPoint(text: "Complete workouts using the Workout app on your Watch")
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                } header: {
                    Text("Setup Tips")
                }
            }
            .navigationTitle("Apple Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WatchFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.navy)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textPrimary)
                Text(description)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColors.navy)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Preferences

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("showCalories") private var showCalories = true
    @AppStorage("showHeartRate") private var showHeartRate = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Use Metric Units", isOn: $useMetricUnits)
                } header: {
                    Text("Units")
                } footer: {
                    Text("Coming soon - unit conversion will be applied in a future update.")
                        .foregroundStyle(AppColors.coral)
                }

                Section {
                    Toggle("Show Calories", isOn: $showCalories)
                    Toggle("Show Heart Rate", isOn: $showHeartRate)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Coming soon - display options will be applied in a future update.")
                        .foregroundStyle(AppColors.coral)
                }

                Section {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Coming soon in a future update.")
                        .foregroundStyle(AppColors.coral)
                }
                .disabled(true)
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Goal Settings View

struct GoalSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var goalService = UserGoalService.shared
    @State private var selectedGoal: UserGoal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(UserGoal.allCases) { goal in
                        Button {
                            selectedGoal = goal
                            goalService.setPrimaryGoal(goal)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(goalColor(for: goal).opacity(0.12))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: goal.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(goalColor(for: goal))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.rawValue)
                                        .font(AppTypography.cardTitle)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text(goal.description)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppColors.olive)
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select Your Primary Goal")
                } footer: {
                    Text("Your goal helps personalize workout insights and recovery recommendations. Weight tracking is only shown when \"Weight Loss\" is selected.")
                }
            }
            .navigationTitle("Fitness Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedGoal = goalService.primaryGoal
            }
        }
    }

    private func goalColor(for goal: UserGoal) -> Color {
        switch goal {
        case .performance: return AppColors.coral
        case .consistency: return AppColors.olive
        case .recovery: return AppColors.navy
        case .weightLoss: return AppColors.orange
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Getting Started") {
                    HelpRow(title: "Connect Apple Health", description: "Go to Settings > Health Data to connect your health data.")
                    HelpRow(title: "Add a Workout", description: "Tap the + button on the Workouts tab to manually log a workout.")
                    HelpRow(title: "Check-ins", description: "After workouts, Insio asks how you feel to improve future insights.")
                }

                Section("Features") {
                    HelpRow(title: "Workout Insights", description: "Tap any workout to see personalized analysis and recommendations.")
                    HelpRow(title: "Trends", description: "View your fitness patterns over time on the Trends tab.")
                    HelpRow(title: "Recovery", description: "Your daily readiness score helps you train smarter.")
                }

                Section("Support") {
                    Link(destination: URL(string: "mailto:support@insiohealth.com")!) {
                        HStack {
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "envelope")
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HelpRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.cardTitle)
            Text(description)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Privacy View

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Privacy Policy")
                        .font(AppTypography.screenTitle)

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        PrivacySection(
                            title: "Your Data Stays Yours",
                            content: "Insio is designed with privacy first. Your health data is stored locally on your device and optionally synced to your personal cloud account."
                        )

                        PrivacySection(
                            title: "What We Collect",
                            content: "We only access the health data you explicitly authorize through Apple Health. This includes workouts, heart rate, sleep, and HRV data."
                        )

                        PrivacySection(
                            title: "How We Use It",
                            content: "Your health data is used solely to provide personalized workout insights and recovery recommendations. We do not sell or share your data."
                        )

                        PrivacySection(
                            title: "Cloud Sync",
                            content: "If you create an account, your data is encrypted and stored in your personal Supabase database. You can delete your account and all associated data at any time."
                        )

                        PrivacySection(
                            title: "Analytics",
                            content: "We may collect anonymous usage analytics to improve the app. This data cannot be tied back to you personally."
                        )
                    }
                }
                .padding(AppSpacing.Layout.horizontalMargin)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(content)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Terms of Service")
                        .font(AppTypography.screenTitle)

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        PrivacySection(
                            title: "Acceptance of Terms",
                            content: "By downloading or using Insio, you agree to these Terms of Service. If you do not agree, please do not use the app."
                        )

                        PrivacySection(
                            title: "Use of the Service",
                            content: "Insio provides fitness tracking and workout insights. The app is intended for personal, non-commercial use. You must be at least 13 years old to use this service."
                        )

                        PrivacySection(
                            title: "Health Information",
                            content: "Insio is not a medical device and does not provide medical advice. The insights and recommendations are for informational purposes only. Always consult a healthcare professional before starting any fitness program."
                        )

                        PrivacySection(
                            title: "Account Responsibility",
                            content: "You are responsible for maintaining the confidentiality of your account. You agree to notify us immediately of any unauthorized use of your account."
                        )

                        PrivacySection(
                            title: "Subscription & Billing",
                            content: "Premium features require a subscription. Subscriptions auto-renew unless cancelled at least 24 hours before the renewal date. You can manage subscriptions in your App Store settings."
                        )

                        PrivacySection(
                            title: "Limitation of Liability",
                            content: "Insio is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the app, including but not limited to fitness-related injuries."
                        )

                        PrivacySection(
                            title: "Changes to Terms",
                            content: "We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the new terms."
                        )

                        PrivacySection(
                            title: "Contact",
                            content: "For questions about these Terms of Service, contact us at support@insiohealth.com."
                        )
                    }
                }
                .padding(AppSpacing.Layout.horizontalMargin)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - About Insio View

struct AboutInsioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacy = false
    @State private var showTerms = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Logo
                    ZStack {
                        Circle()
                            .fill(AppColors.navy.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(AppColors.navy)
                    }
                    .padding(.top, AppSpacing.xl)

                    VStack(spacing: AppSpacing.sm) {
                        Text("Insio")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Version 1.0.0")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    VStack(spacing: AppSpacing.md) {
                        Text("Your personal fitness companion that helps you understand your workouts, track recovery, and train smarter.")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)

                        Text("Built with SwiftUI and powered by Apple Health.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    // Legal Links (in-app)
                    VStack(spacing: AppSpacing.sm) {
                        Button {
                            showPrivacy = true
                        } label: {
                            HStack {
                                Text("Privacy Policy")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(AppColors.navy)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        }

                        Button {
                            showTerms = true
                        } label: {
                            HStack {
                                Text("Terms of Service")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(AppColors.navy)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                        }
                    }
                    .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

                    Spacer().frame(height: AppSpacing.xl)
                }
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyView()
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
        }
    }
}

// MARK: - Previews

#Preview("Notifications") {
    NotificationSettingsView()
}

#Preview("Health Data") {
    HealthDataSettingsView()
}

#Preview("Preferences") {
    PreferencesView()
}
