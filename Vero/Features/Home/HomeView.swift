//
//  HomeView.swift
//  Vero
//
//  BOLD HOME DASHBOARD - Unique, Expressive, Show-off Worthy
//
//  Design Philosophy:
//    - Premium but exciting
//    - Controlled bold color
//    - Screenshot-worthy UI
//    - NOT generic Apple Health style
//

import SwiftUI

// MARK: - Home Dashboard

struct HomeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var goalService = UserGoalService.shared
    @StateObject private var healthKitService = HealthKitService.shared

    @State private var navigateToWorkoutInsight = false
    @State private var showAddWorkout = false
    @State private var showDailyLog = false
    @State private var showWaterLog = false
    @State private var showSleepLog = false
    @State private var showWeightLog = false
    @State private var animateProgress = false

    private var displayName: String {
        if authService.isAuthenticated {
            if let metadata = authService.currentUser?.userMetadata,
               let nameValue = metadata["full_name"],
               case .string(let fullName) = nameValue,
               !fullName.isEmpty {
                // Get first name only
                return fullName.components(separatedBy: " ").first ?? fullName
            }
            if let email = authService.currentUser?.email {
                return email.components(separatedBy: "@").first ?? email
            }
        }
        return "there"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // ═══════════════════════════════════════════════════
                    // GREETING HEADER
                    // ═══════════════════════════════════════════════════
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(greeting), \(displayName)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // PART 1: HERO (Brand Moment)
                    // ═══════════════════════════════════════════════════
                    HeroCard(
                        workoutsThisWeek: viewModel.workoutsThisWeek,
                        streak: viewModel.currentStreak,
                        hasWorkout: viewModel.latestWorkout != nil,
                        onTap: {
                            if viewModel.latestWorkout != nil {
                                navigateToWorkoutInsight = true
                            } else {
                                showAddWorkout = true
                            }
                        }
                    )
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // PART 2: ASYMMETRICAL GRID
                    // ═══════════════════════════════════════════════════
                    VStack(spacing: 8) {
                        // Row 1: Workouts (LARGER) + Sleep
                        HStack(spacing: 8) {
                            WorkoutsCard(
                                count: viewModel.workoutsThisWeek,
                                streak: viewModel.currentStreak,
                                animate: animateProgress,
                                onTap: { showAddWorkout = true }
                            )
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1.2, contentMode: .fit)

                            SleepCard(
                                hours: viewModel.dailyContext?.sleepHours,
                                animate: animateProgress,
                                onTap: { showSleepLog = true }
                            )
                            .frame(width: 130)
                        }

                        // Row 2: Hydration + Weight (smaller)
                        HStack(spacing: 8) {
                            HydrationCard(
                                liters: viewModel.waterIntake,
                                animate: animateProgress,
                                onTap: { showWaterLog = true }
                            )

                            if goalService.shouldShowWeightUI {
                                WeightCard(
                                    currentWeight: viewModel.dailyContext?.weightKg,
                                    weeklyDelta: viewModel.weeklyWeightDelta,
                                    onTap: { showWeightLog = true }
                                )
                            } else {
                                ReadinessCard(
                                    score: viewModel.recovery?.overallScore,
                                    animate: animateProgress,
                                    onTap: { showDailyLog = true }
                                )
                            }
                        }
                        .frame(height: 88)
                    }
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // PART 6: WEEKLY TRACKER (Upgraded)
                    // ═══════════════════════════════════════════════════
                    WeeklyTracker(
                        workoutsThisWeek: viewModel.workoutsThisWeek,
                        workoutDays: viewModel.workoutDaysThisWeek,
                        animate: animateProgress
                    )
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // PART 5: SINGLE STRONG CTA
                    // ═══════════════════════════════════════════════════
                    PrimaryCTA(
                        onLogWorkout: { showAddWorkout = true },
                        onLogDaily: { showDailyLog = true }
                    )
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 12)
                }
                .padding(.top, 20)
            }
            .scrollContentBackground(.hidden)
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
        .background(AppColors.background.ignoresSafeArea(.all))
        .task {
            await viewModel.loadData()
        }
        .onAppear {
            print("🏠 HomeDashboardView: APPEARED")
            viewModel.refreshAnalytics()
            // Trigger animations after slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateProgress = true
                }
            }
        }
        .sheet(isPresented: $showAddWorkout) {
            AddWorkoutView(onSave: { _ in
                viewModel.refreshAnalytics()
            })
        }
        .sheet(isPresented: $showDailyLog) {
            DailyContextInputView(onSave: {
                viewModel.refreshAnalytics()
            })
        }
        .sheet(isPresented: $showWaterLog) {
            WaterLoggingView(onSave: {
                viewModel.refreshAnalytics()
            })
        }
        .sheet(isPresented: $showSleepLog) {
            SleepLoggingView(onSave: {
                viewModel.refreshAnalytics()
            })
        }
        .sheet(isPresented: $showWeightLog) {
            WeightLoggingView(onSave: {
                viewModel.refreshAnalytics()
            })
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase == .inactive {
                Task {
                    await healthKitService.refreshAuthorizationStatus()
                    if healthKitService.authorizationStatus == .authorized {
                        await viewModel.loadData()
                    }
                }
                // Re-trigger animations
                animateProgress = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        animateProgress = true
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PART 1: HERO CARD (Bold Brand Moment)
// ═══════════════════════════════════════════════════════════════════════════════

private struct HeroCard: View {
    let workoutsThisWeek: Int
    let streak: Int
    let hasWorkout: Bool
    let onTap: () -> Void

    private var headline: String {
        switch workoutsThisWeek {
        case 0: return "Ready to Start"
        case 1: return "First Step"
        case 2: return "Building Up"
        case 3: return "Momentum"
        case 4: return "Strong Week"
        case 5: return "Crushing It"
        case 6...: return "On Fire"
        default: return "Your Week"
        }
    }

    private var supportingText: String {
        if workoutsThisWeek == 0 {
            return "Tap to log your first workout"
        }
        var parts: [String] = []
        parts.append("\(workoutsThisWeek) workout\(workoutsThisWeek == 1 ? "" : "s")")
        if streak > 1 {
            parts.append("\(streak) day streak")
        }
        if workoutsThisWeek >= 5 {
            parts.append("peak week")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background with gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.burntOrange,
                                AppColors.burntOrange.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle texture overlay
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Label
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    // Large statement
                    Text(headline)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    // Supporting line
                    HStack(spacing: 5) {
                        if streak > 1 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                        }
                        Text(supportingText)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                // Arrow indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(18)
            }
            .frame(height: 140)
            .shadow(color: AppColors.burntOrange.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PART 2 & 3: METRIC CARDS (Asymmetric + Color Identity)
// ═══════════════════════════════════════════════════════════════════════════════

private struct WorkoutsCard: View {
    let count: Int
    let streak: Int
    let animate: Bool
    let onTap: () -> Void

    private let goal = 5
    private var progress: Double { min(Double(count) / Double(goal), 1.0) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Header with icon
                HStack {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.burntOrange)

                    Text("WORKOUTS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    Spacer()
                }

                Spacer()

                // Value
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("/\(goal)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }

                // Streak badge
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(streak)d streak")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.burntOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.burntOrange.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Animated progress bar
                AnimatedProgressBar(
                    progress: progress,
                    color: AppColors.burntOrange,
                    animate: animate
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
            // Orange accent line at top
            .overlay(
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.burntOrange)
                        .frame(width: 40, height: 3)
                        .padding(.top, 12)
                    Spacer()
                }
            )
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

private struct SleepCard: View {
    let hours: Double?
    let animate: Bool
    let onTap: () -> Void

    private var display: String {
        guard let h = hours, h > 0 else { return "—" }
        return String(format: "%.1f", h)
    }

    private var progress: Double {
        guard let h = hours, h > 0 else { return 0 }
        return min(h / 8.0, 1.0)
    }

    private var quality: String {
        guard let h = hours else { return "Log sleep" }
        switch h {
        case 7.5...: return "Great"
        case 6.5..<7.5: return "Good"
        case 5..<6.5: return "Low"
        default: return "Poor"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Icon + label row (matches WorkoutsCard hierarchy)
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.olive)
                    Text("SLEEP")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Value
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(display)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("h")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text(quality)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.olive)

                // Progress
                AnimatedProgressBar(
                    progress: progress,
                    color: AppColors.olive,
                    animate: animate
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.white, AppColors.olive.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

private struct HydrationCard: View {
    let liters: Double  // Always stored in liters
    let animate: Bool
    let onTap: () -> Void
    @ObservedObject private var units = UnitPreferences.shared

    private var goal: Double {
        units.isMetric ? 2.5 : 85.0  // 2.5L or 85oz
    }

    private var displayValue: Double {
        units.displayVolume(liters)
    }

    private var display: String {
        guard liters > 0 else { return "—" }
        return units.formatVolumeValue(liters)
    }

    private var progress: Double {
        guard liters > 0 else { return 0 }
        return min(displayValue / goal, 1.0)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon with blue tint background — compact so label has room
                ZStack {
                    Circle()
                        .fill(AppColors.waterAccent.opacity(0.15))
                        .frame(width: 30, height: 30)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.waterAccent)
                }

                // Label + value — highest priority, no truncation
                VStack(alignment: .leading, spacing: 2) {
                    Text("HYDRATION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(display)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(units.volumeUnit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                // Circular progress — reduced to free up label space
                ZStack {
                    Circle()
                        .stroke(AppColors.divider, lineWidth: 3)
                        .frame(width: 34, height: 34)

                    Circle()
                        .trim(from: 0, to: animate ? progress : 0)
                        .stroke(AppColors.waterAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: animate)

                    Text("\(Int(progress * 100))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.waterAccent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

private struct WeightCard: View {
    let currentWeight: Double?  // Always stored in kg
    let weeklyDelta: Double?    // Always stored in kg
    let onTap: () -> Void
    @ObservedObject private var units = UnitPreferences.shared

    private var deltaDisplay: String {
        guard let delta = weeklyDelta, delta != 0 else { return "" }
        let displayDelta = units.displayWeight(abs(delta))
        let sign = delta > 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", displayDelta))"
    }

    private var weightDisplay: String {
        guard let w = currentWeight, w > 0 else { return "—" }
        return units.formatWeightValue(w)
    }

    private var trendColor: Color {
        guard let delta = weeklyDelta else { return AppColors.textTertiary }
        return delta <= 0 ? AppColors.olive : AppColors.coral
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Text column — high priority so value never truncates
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEIGHT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(weightDisplay)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(units.weightUnit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }

                    if !deltaDisplay.isEmpty {
                        Text(deltaDisplay)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(trendColor)
                            .lineLimit(1)
                    } else if currentWeight == nil {
                        Text("Tap to log")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                // Mini sparkline — lower priority, shrinks on tight screens
                MiniSparkline(trend: weeklyDelta ?? 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

private struct ReadinessCard: View {
    let score: Int?
    let animate: Bool
    let onTap: () -> Void

    private var display: String {
        guard let s = score, s > 0 else { return "—" }
        return "\(s)"
    }

    private var progress: Double {
        guard let s = score, s > 0 else { return 0 }
        return Double(s) / 100.0
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("READINESS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(display)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        if score != nil {
                            Text("%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(AppColors.divider, lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: animate ? progress : 0)
                        .stroke(AppColors.olive, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: animate)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(BoldCardButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PART 4: ANIMATED PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════════

private struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    let animate: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.divider)
                    .frame(height: 6)

                // Fill with gradient
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * (animate ? progress : 0), height: 6)
                    .animation(.easeOut(duration: 1.0), value: animate)
            }
        }
        .frame(height: 6)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - MINI SPARKLINE (Weight Card)
// ═══════════════════════════════════════════════════════════════════════════════

private struct MiniSparkline: View {
    let trend: Double

    var body: some View {
        // Simple trend indicator
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.divider.opacity(0.5))
                .frame(width: 50, height: 30)

            // Trend line
            Path { path in
                let startY: CGFloat = trend >= 0 ? 10 : 20
                let endY: CGFloat = trend >= 0 ? 20 : 10
                path.move(to: CGPoint(x: 8, y: startY))
                path.addCurve(
                    to: CGPoint(x: 42, y: endY),
                    control1: CGPoint(x: 20, y: startY),
                    control2: CGPoint(x: 30, y: endY)
                )
            }
            .stroke(
                trend <= 0 ? AppColors.olive : AppColors.coral,
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PART 6: WEEKLY TRACKER (Upgraded)
// ═══════════════════════════════════════════════════════════════════════════════

private struct WeeklyTracker: View {
    let workoutsThisWeek: Int
    /// Actual weekday indices (0=Mon…6=Sun) that had workouts this week.
    /// Drives per-day dot rendering rather than a sequential fill.
    let workoutDays: Set<Int>
    let animate: Bool

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    private var currentDayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()

                Text("\(workoutsThisWeek) of 5")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Days row — dots light up for actual workout days, not sequential
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    let completed = workoutDays.contains(index)
                    let isToday = index == currentDayIndex
                    // Days in the future (beyond today) are dimmed
                    let isFuture = index > currentDayIndex
                    let dotColor: Color = completed
                        ? AppColors.burntOrange
                        : (isFuture ? AppColors.divider.opacity(0.5) : AppColors.divider)

                    VStack(spacing: 6) {
                        // Day label
                        Text(days[index])
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(
                                isToday ? AppColors.navy
                                    : isFuture ? AppColors.textTertiary.opacity(0.5)
                                    : AppColors.textTertiary
                            )

                        // Dot with animation
                        ZStack {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 10, height: 10)
                                .scaleEffect(animate && completed ? 1.0 : (animate ? 0.7 : 0.5))
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.08),
                                    value: animate
                                )

                            // Today ring
                            if isToday {
                                Circle()
                                    .stroke(AppColors.navy, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .frame(height: 22)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - PART 5: PRIMARY CTA
// ═══════════════════════════════════════════════════════════════════════════════

private struct PrimaryCTA: View {
    let onLogWorkout: () -> Void
    let onLogDaily: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Primary: Log Workout (Bold orange)
            Button(action: onLogWorkout) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))

                    Text("Log Workout")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppColors.burntOrange, AppColors.burntOrange.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppColors.burntOrange.opacity(0.3), radius: 8, y: 4)
            }

            // Secondary: Daily Log — labeled so purpose is obvious
            Button(action: onLogDaily) {
                VStack(spacing: 2) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Daily")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(AppColors.navy)
                .frame(width: 52, height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - BUTTON STYLE
// ═══════════════════════════════════════════════════════════════════════════════

private struct BoldCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    HomeDashboardView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
