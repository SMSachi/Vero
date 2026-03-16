//
//  HomeView.swift
//  Vero
//
//  Home dashboard - unified design system
//

import SwiftUI

// MARK: - Home Dashboard

struct HomeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var navigateToWorkoutInsight = false

    // Animation states
    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var contextVisible = false
    @State private var weeklyVisible = false
    @State private var recoveryVisible = false
    @State private var trendVisible = false

    private let latestWorkout = MockData.detailedWorkout
    private let recovery = MockData.todayRecovery
    private let context = MockData.todayContext

    private var showWorkoutAsHero: Bool {
        let hoursSinceWorkout = -latestWorkout.endDate.timeIntervalSinceNow / 3600
        return hoursSinceWorkout < 18
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.sectionSpacing) {

                    // 1. HEADER
                    HomeHeader()
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 15)

                    // 2. HERO CARD
                    Group {
                        if showWorkoutAsHero {
                            WorkoutHeroCard(workout: latestWorkout) {
                                navigateToWorkoutInsight = true
                            }
                        } else {
                            ReadinessHeroCard(recovery: recovery)
                        }
                    }
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 15)

                    // 3. CONTEXT CHIPS
                    HomeContextRow(context: context)
                        .opacity(contextVisible ? 1 : 0)
                        .offset(y: contextVisible ? 0 : 12)

                    // 4. WEEKLY SUMMARY CARD
                    WeeklySummaryCard()
                        .opacity(weeklyVisible ? 1 : 0)
                        .offset(y: weeklyVisible ? 0 : 12)

                    // 5. RECOVERY INSIGHT CARD
                    RecoveryInsightCard(recovery: recovery)
                        .opacity(recoveryVisible ? 1 : 0)
                        .offset(y: recoveryVisible ? 0 : 12)

                    // 6. TREND PREVIEW
                    TrendPreviewCard()
                        .opacity(trendVisible ? 1 : 0)
                        .offset(y: trendVisible ? 0 : 10)
                }
                .padding(.top, AppSpacing.Layout.topPadding)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToWorkoutInsight) {
                WorkoutInsightView(workout: latestWorkout)
            }
        }
        .onAppear {
            startEntranceAnimations()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString.uppercased())
                .font(AppTypography.miniLabel)
                .foregroundStyle(AppColors.textTertiary)
                .tracking(0.8)

            Text("\(greeting), \(MockData.userName)")
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
    let onTap: () -> Void

    private var oneLiner: String {
        let full = workout.interpretation
        if let dotIndex = full.firstIndex(of: ".") {
            return String(full[...dotIndex])
        }
        return full
    }

    private var accentColor: Color {
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
                    MetricChip(value: "\(workout.averageHeartRate)", icon: "heart.fill")
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
                value: String(format: "%.1f", MockData.todayWaterIntake),
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

// MARK: - 4. Weekly Summary Card

struct WeeklySummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("This Week")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("View all")
                    .font(AppTypography.chipText)
                    .foregroundStyle(AppColors.navy)
            }

            // Stats row
            HStack(spacing: 0) {
                WeeklyStatItem(
                    value: "\(MockData.workoutsThisWeek)",
                    label: "Workouts",
                    icon: "figure.run",
                    color: AppColors.navy
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 12)

                WeeklyStatItem(
                    value: "\(MockData.currentStreak)",
                    label: "Day streak",
                    icon: "flame.fill",
                    color: AppColors.orange
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 12)

                WeeklyStatItem(
                    value: "4.2",
                    label: "Avg hours",
                    icon: "clock.fill",
                    color: AppColors.olive
                )
            }

            // Activity bar
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    let hasWorkout = [0, 2, 4, 5].contains(day)
                    let isToday = day == 4

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

// MARK: - 5. Recovery Insight Card

struct RecoveryInsightCard: View {
    let recovery: NextDayRecovery

    private var insight: String {
        if recovery.overallScore >= 80 {
            return "Your recovery is excellent this week. Great sleep consistency."
        } else if recovery.overallScore >= 60 {
            return "Recovery is moderate. Consider lighter sessions today."
        } else {
            return "Recovery is low. Focus on rest and hydration."
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.olive.opacity(0.12))
                    .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                Image(systemName: "leaf.fill")
                    .font(.system(size: AppSpacing.Icon.medium, weight: .medium))
                    .foregroundStyle(AppColors.olive)
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

// MARK: - 6. Trend Preview Card

struct TrendPreviewCard: View {
    private let data: [CGFloat] = [0.4, 0.6, 0.5, 0.7, 0.65, 0.8, 0.75]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HRV Trend")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    Text("+12%")
                        .font(AppTypography.statLabel)
                }
                .foregroundStyle(AppColors.olive)
            }

            // Mini sparkline
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index == data.count - 1 ? AppColors.navy : AppColors.navy.opacity(0.3))
                        .frame(height: 8 + value * 32)
                }
            }
            .frame(height: 44)

            HStack {
                Text("48ms avg")
                    .font(AppTypography.chipText)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

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
        .standardCardWithMargin()
    }
}

// MARK: - Preview

#Preview {
    HomeDashboardView()
        .environmentObject(AppState())
}
