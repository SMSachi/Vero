//
//  HomeView.swift
//  Insio Health
//
//  Home dashboard - unified design system
//  Uses HomeViewModel to fetch real HealthKit data with mock fallback
//

import SwiftUI

// MARK: - Home Dashboard

struct HomeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var healthKitService = HealthKitService.shared

    @State private var navigateToWorkoutInsight = false
    @State private var showAddWorkout = false
    @State private var isConnectingHealth = false

    // Animation states
    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var contextVisible = false
    @State private var weeklyVisible = false
    @State private var recoveryVisible = false
    @State private var trendVisible = false

    var body: some View {
        // DEBUG: Log body evaluation
        let _ = print("🏠 HomeDashboardView: body EVALUATING")

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.sectionSpacing) {

                    // 1. HEADER
                    HomeHeader()
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 15)

                    // Show empty state when no real data
                    if viewModel.showEmptyState {
                        HomeEmptyState(
                            onConnectHealth: {
                                connectHealthKit()
                            },
                            onAddWorkout: {
                                showAddWorkout = true
                            },
                            isConnecting: isConnectingHealth,
                            healthKitStatus: healthKitService.authorizationStatus,
                            connectionState: healthKitService.connectionState
                        )
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: heroVisible ? 0 : 15)
                    } else {
                        // 2. HERO CARD
                        // Shows workout if recent (<18 hours), otherwise shows readiness
                        // Uses InterpretationEngine-generated summary for the one-liner
                        Group {
                            if viewModel.showWorkoutAsHero, let workout = viewModel.latestWorkout {
                                WorkoutHeroCard(
                                    workout: workout,
                                    interpretation: viewModel.workoutInterpretation
                                ) {
                                    navigateToWorkoutInsight = true
                                }
                            } else if let recovery = viewModel.recovery {
                                ReadinessHeroCard(recovery: recovery)
                            }
                        }
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: heroVisible ? 0 : 15)

                        // 3. CONTEXT CHIPS
                        // Shows sleep, water, and energy from HealthKit (or mock)
                        if let context = viewModel.dailyContext {
                            HomeContextRow(
                                context: context,
                                waterIntake: viewModel.waterIntake
                            )
                            .opacity(contextVisible ? 1 : 0)
                            .offset(y: contextVisible ? 0 : 12)
                        }

                        // 4. WEEKLY SUMMARY CARD
                        WeeklySummaryCard(
                            workoutsThisWeek: viewModel.workoutsThisWeek,
                            currentStreak: viewModel.currentStreak,
                            recentWorkouts: viewModel.recentWorkouts
                        )
                        .opacity(weeklyVisible ? 1 : 0)
                        .offset(y: weeklyVisible ? 0 : 12)

                        // 5. RECOVERY INSIGHT CARD
                        if let recovery = viewModel.recovery {
                            RecoveryInsightCard(
                                recovery: recovery,
                                dailyContext: viewModel.dailyContext
                            )
                            .opacity(recoveryVisible ? 1 : 0)
                            .offset(y: recoveryVisible ? 0 : 12)
                        }

                        // 6. TREND PREVIEW
                        TrendPreviewCard(hrvScore: viewModel.dailyContext?.hrvScore)
                            .opacity(trendVisible ? 1 : 0)
                            .offset(y: trendVisible ? 0 : 10)
                    }
                }
                .padding(.top, AppSpacing.Layout.topPadding)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToWorkoutInsight) {
                if let workout = viewModel.latestWorkout {
                    WorkoutInsightView(
                        workout: workout,
                        interpretation: viewModel.workoutInterpretation
                    )
                }
            }
        }
        .task {
            print("🏠 HomeDashboardView: Starting loadData task...")
            // Load HealthKit data when view appears
            await viewModel.loadData()
            print("🏠 HomeDashboardView: loadData task completed")

            // Notify AppState about the loaded workout (for check-in automation)
            if viewModel.hasRealData, let workout = viewModel.latestWorkout {
                appState.workoutWasSaved(workout)
            }
        }
        .onAppear {
            print("🏠 ══════════════════════════════════════════════════")
            print("🏠 HomeDashboardView: APPEARED")
            print("🏠 HomeDashboardView: isLoading = \(viewModel.isLoading)")
            print("🏠 HomeDashboardView: hasRealData = \(viewModel.hasRealData)")
            print("🏠 HomeDashboardView: showEmptyState = \(viewModel.showEmptyState)")
            print("🏠 ══════════════════════════════════════════════════")
            startEntranceAnimations()

            // Refresh analytics from local cache (picks up newly added workouts)
            viewModel.refreshAnalytics()
        }
        .sheet(isPresented: $showAddWorkout) {
            AddWorkoutView(onSave: { _ in
                viewModel.refreshAnalytics()
            })
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Re-check HealthKit status when returning from Settings
            if newPhase == .active && oldPhase == .inactive {
                print("🏠 HomeView: Scene became active - refreshing HealthKit status")
                Task {
                    await healthKitService.refreshAuthorizationStatus()

                    // If now authorized, reload data
                    if healthKitService.authorizationStatus == .authorized {
                        print("🏠 HomeView: HealthKit now authorized - reloading data")
                        await viewModel.loadData()
                    }
                }
            }
        }
    }

    private func connectHealthKit() {
        print("🏠 HomeView: connectHealthKit() called")
        isConnectingHealth = true

        Task {
            let success = await healthKitService.requestAuthorization()
            print("🏠 HomeView: Authorization result: \(success)")

            if success {
                print("🏠 HomeView: Authorization succeeded - loading data")
                await viewModel.loadData()
            }

            await MainActor.run {
                isConnectingHealth = false
            }
        }
    }

    private func startEntranceAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.15)) {
            heroVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.25)) {
            contextVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.35)) {
            weeklyVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.45)) {
            recoveryVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.55)) {
            trendVisible = true
        }
    }
}

// MARK: - 1. Home Header

struct HomeHeader: View {
    @EnvironmentObject var authService: AuthService

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Hey there"
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    /// Get user's display name from auth, or friendly fallback
    private var displayName: String {
        if authService.isAuthenticated {
            // Try full name from metadata (AnyJSON requires pattern matching)
            if let metadata = authService.currentUser?.userMetadata,
               let nameValue = metadata["full_name"],
               case .string(let fullName) = nameValue,
               !fullName.isEmpty {
                return fullName.components(separatedBy: " ").first ?? fullName
            }
            // Fall back to email prefix
            if let email = authService.currentUser?.email {
                return email.components(separatedBy: "@").first ?? "there"
            }
        }
        return "there"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString.uppercased())
                .font(AppTypography.miniLabel)
                .foregroundStyle(AppColors.textTertiary)
                .tracking(0.8)

            Text("\(greeting), \(displayName)")
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - 2. Workout Hero Card

struct WorkoutHeroCard: View {
    let workout: Workout
    var interpretation: WorkoutInterpretation? = nil
    let onTap: () -> Void

    /// One-liner summary from InterpretationEngine, or fallback to workout.interpretation
    private var oneLiner: String {
        // Use interpretation summary if available
        if let interp = interpretation {
            return interp.summaryText
        }

        // Fallback to workout's built-in interpretation
        let full = workout.interpretation
        if let dotIndex = full.firstIndex(of: ".") {
            return String(full[...dotIndex])
        }
        return full
    }

    /// Accent color based on interpretation sentiment or workout intensity
    private var accentColor: Color {
        if let interp = interpretation {
            switch interp.sentiment {
            case .positive: return AppColors.olive
            case .neutral: return AppColors.navy
            case .caution: return AppColors.coral
            }
        }

        switch workout.intensity {
        case .low: return AppColors.olive
        case .moderate: return AppColors.navy
        case .high: return AppColors.coral
        case .max: return AppColors.orange
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: workout.type.icon)
                        .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                    Text(workout.type.rawValue)
                        .font(AppTypography.labelMedium)
                }
                .foregroundStyle(accentColor)

                Text(oneLiner)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 16) {
                    MetricChip(value: workout.durationFormatted, icon: "clock")
                    if let avgHR = workout.averageHeartRate {
                        MetricChip(value: "\(avgHR)", icon: "heart.fill")
                    }
                    MetricChip(value: "\(workout.calories)", icon: "flame.fill")

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .standardCardWithMargin()
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct MetricChip: View {
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)

            Text(value)
                .font(AppTypography.cardSubtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

// MARK: - 2b. Readiness Hero Card

struct ReadinessHeroCard: View {
    let recovery: NextDayRecovery

    private var oneLiner: String {
        switch recovery.overallScore {
        case 85...: return "Fully recovered. Push if you want."
        case 70..<85: return "Ready for today."
        case 50..<70: return "Still recovering. Take it easy."
        default: return "Your body needs rest."
        }
    }

    private var scoreColor: Color {
        switch recovery.overallScore {
        case 70...: return AppColors.olive
        case 50..<70: return AppColors.coral
        default: return AppColors.recoveryLow
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: CGFloat(recovery.overallScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(recovery.overallScore)")
                    .font(AppTypography.statValue)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("READINESS")
                    .font(AppTypography.miniLabel)
                    .foregroundStyle(scoreColor)
                    .tracking(0.8)

                Text(oneLiner)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .standardCardWithMargin()
    }
}

// MARK: - 3. Context Chips Row

struct HomeContextRow: View {
    let context: DailyContext
    let waterIntake: Double

    var body: some View {
        HStack(spacing: 10) {
            ContextChip(
                icon: "moon.zzz.fill",
                value: String(format: "%.0f", context.sleepHours),
                unit: "hrs",
                color: .indigo
            )

            ContextChip(
                icon: "drop.fill",
                value: String(format: "%.1f", waterIntake),
                unit: "L",
                color: .blue
            )

            ContextChip(
                icon: "bolt.fill",
                value: context.energyLevel == .high || context.energyLevel == .peak ? "Good" : "Low",
                unit: "",
                color: AppColors.coral
            )
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

struct ContextChip: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: AppSpacing.Icon.small, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.cardSubtitle)
                .foregroundStyle(AppColors.textPrimary)

            if !unit.isEmpty {
                Text(unit)
                    .font(AppTypography.miniLabel)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }
}

// MARK: - 4. Weekly Summary Card (Honest Data)

struct WeeklySummaryCard: View {
    var workoutsThisWeek: Int
    var currentStreak: Int
    var recentWorkouts: [Workout]  // Pass workouts to avoid persistence calls during body

    // Real workout days from passed workouts (no persistence calls during body evaluation!)
    private var workoutDaysThisWeek: Set<Int> {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }

        var days: Set<Int> = []

        for workout in recentWorkouts {
            if let daysDiff = calendar.dateComponents([.day], from: weekStart, to: workout.startDate).day,
               daysDiff >= 0 && daysDiff < 7 {
                days.insert(daysDiff)
            }
        }
        return days
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert Sunday=1 to Monday=0 based index
        return weekday == 1 ? 6 : weekday - 2
    }

    private var hasEnoughDataForStats: Bool {
        workoutsThisWeek > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("This Week")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if hasEnoughDataForStats {
                    Text("View all")
                        .font(AppTypography.chipText)
                        .foregroundStyle(AppColors.navy)
                }
            }

            if hasEnoughDataForStats {
                // Stats row - only show real data
                HStack(spacing: 0) {
                    WeeklyStatItem(
                        value: "\(workoutsThisWeek)",
                        label: "Workouts",
                        icon: "figure.run",
                        color: AppColors.navy
                    )

                    Divider()
                        .frame(height: 36)
                        .padding(.horizontal, 12)

                    WeeklyStatItem(
                        value: currentStreak > 0 ? "\(currentStreak)" : "—",
                        label: "Day streak",
                        icon: "flame.fill",
                        color: currentStreak > 0 ? AppColors.orange : AppColors.textTertiary
                    )
                }

                // Activity bar - real data
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        let hasWorkout = workoutDaysThisWeek.contains(day)
                        let isToday = day == todayIndex

                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(hasWorkout ? AppColors.navy : AppColors.divider)
                                .frame(height: hasWorkout ? 24 : 12)

                            Text(dayLabel(for: day))
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? AppColors.navy : AppColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Empty state
                VStack(spacing: AppSpacing.sm) {
                    Text("No workouts this week yet")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("Log your first workout to start tracking")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .standardCardWithMargin()
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index]
    }
}

struct WeeklyStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)

                Text(value)
                    .font(AppTypography.statValue)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(label)
                .font(AppTypography.miniLabel)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 5. Recovery Insight Card (Honest Data)

struct RecoveryInsightCard: View {
    let recovery: NextDayRecovery
    var dailyContext: DailyContext?  // Pass context to avoid persistence calls during body

    // Check if we have real physiological data (no persistence calls during body evaluation!)
    private var hasRealRecoveryData: Bool {
        guard let context = dailyContext else { return false }
        return context.hrvScore != nil || context.sleepHours > 0
    }

    private var insight: String {
        if !hasRealRecoveryData {
            return "Log more workouts and connect Apple Health for recovery insights."
        }

        if recovery.overallScore >= 80 {
            return "Your recovery looks good based on available data."
        } else if recovery.overallScore >= 60 {
            return "Moderate recovery. Consider how you feel before intense sessions."
        } else {
            return "Recovery appears low. Focus on rest if possible."
        }
    }

    private var iconColor: Color {
        if !hasRealRecoveryData {
            return AppColors.textTertiary
        }
        return recovery.overallScore >= 60 ? AppColors.olive : AppColors.coral
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                Image(systemName: hasRealRecoveryData ? "leaf.fill" : "questionmark")
                    .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery Insight")
                    .font(AppTypography.statLabel)
                    .foregroundStyle(AppColors.textTertiary)

                Text(insight)
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .standardCardWithMargin()
    }
}

// MARK: - 6. Trend Preview Card (Honest Data)

struct TrendPreviewCard: View {
    var hrvScore: Double? = nil

    private var hasRealHRVData: Bool {
        hrvScore != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HRV Trend")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if hasRealHRVData {
                    HStack(spacing: 4) {
                        Text("View trends")
                            .font(AppTypography.chipText)
                            .foregroundStyle(AppColors.navy)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.navy)
                    }
                }
            }

            if let hrv = hrvScore {
                // Real HRV data display
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.0f", hrv))
                            .font(AppTypography.statValue)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("ms today")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()

                    // Simple status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(hrv >= 50 ? AppColors.olive : hrv >= 30 ? AppColors.orange : AppColors.coral)
                            .frame(width: 8, height: 8)

                        Text(hrv >= 50 ? "Good recovery" : hrv >= 30 ? "Moderate" : "Low")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            } else {
                // No HRV data - honest empty state
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No HRV data yet")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.textSecondary)

                            Text("Connect Apple Watch for HRV insights")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.xs)
            }
        }
        .standardCardWithMargin()
    }
}

// MARK: - Preview

#Preview {
    HomeDashboardView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
