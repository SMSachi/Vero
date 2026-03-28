//
//  TrendsView.swift
//  Vero
//
//  TRENDS DASHBOARD - Matches Home Design System Exactly
//
//  Design Philosophy:
//    - Same visual language as Home
//    - Off-white background, white cards
//    - Burnt orange primary accent
//    - Subtle tinted backgrounds per metric
//    - Premium, calm, cohesive
//

import SwiftUI

// MARK: - Trends View

struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()
    @StateObject private var goalService = UserGoalService.shared

    @State private var animateCards = false
    @State private var selectedMetric: TrendMetricType?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ═══════════════════════════════════════════════════
                    // HEADER + TIME FILTER (Same style as Home)
                    // ═══════════════════════════════════════════════════
                    TrendsHeaderView(
                        selectedTimeframe: $viewModel.selectedTimeframe
                    )
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // INSIGHT CARD (Small, subtle, NOT a hero)
                    // ═══════════════════════════════════════════════════
                    if let insight = viewModel.topInsights.first {
                        TrendInsightCard(insight: insight)
                            .padding(.horizontal, 20)
                    }

                    // ═══════════════════════════════════════════════════
                    // METRIC CARDS GRID (Matches Home layout)
                    // ═══════════════════════════════════════════════════
                    VStack(spacing: 12) {
                        // Row 1: Heart Rate (larger) + Sleep
                        HStack(spacing: 12) {
                            HeartRateCard(
                                trend: viewModel.metricTrends.first { $0.title.contains("Heart") },
                                animate: animateCards,
                                onTap: { selectedMetric = .heartRate }
                            )
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1.1, contentMode: .fit)

                            SleepTrendCard(
                                trend: viewModel.metricTrends.first { $0.title.contains("Sleep") },
                                animate: animateCards,
                                onTap: { selectedMetric = .sleep }
                            )
                            .frame(width: 140)
                        }

                        // Row 2: Hydration + Weight/Workouts
                        HStack(spacing: 12) {
                            HydrationTrendCard(
                                animate: animateCards,
                                onTap: { selectedMetric = .hydration }
                            )

                            if goalService.shouldShowWeightUI {
                                WeightTrendCard(
                                    trend: viewModel.metricTrends.first { $0.title.contains("Weight") },
                                    onTap: { selectedMetric = .weight }
                                )
                            } else {
                                WorkoutsTrendCard(
                                    workoutCount: viewModel.workoutCount,
                                    timeframeDays: viewModel.timeframeDays,
                                    animate: animateCards,
                                    onTap: { selectedMetric = .workouts }
                                )
                            }
                        }
                        .frame(height: 100)
                    }
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // ACTIVITY CALENDAR
                    // ═══════════════════════════════════════════════════
                    ActivityCalendarCard(
                        calendarData: viewModel.calendarData,
                        workoutCount: viewModel.workoutCount,
                        animate: animateCards
                    )
                    .padding(.horizontal, 20)

                    // ═══════════════════════════════════════════════════
                    // ALL METRICS LIST
                    // ═══════════════════════════════════════════════════
                    if !viewModel.metricTrends.isEmpty {
                        MetricsList(
                            trends: viewModel.metricTrends,
                            onTap: { metric in selectedMetric = metric }
                        )
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 12)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedMetric) { metric in
                MetricDetailView(metricType: metric, trends: viewModel.metricTrends)
            }
        }
        .task {
            await viewModel.loadTrends()
        }
        .onAppear {
            Task { await viewModel.refresh() }
            // Trigger animations (same timing as Home)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateCards = true
                }
            }
        }
    }
}

// MARK: - Metric Type for Navigation

enum TrendMetricType: String, Identifiable, Hashable {
    case heartRate = "Heart Rate"
    case sleep = "Sleep"
    case hydration = "Hydration"
    case weight = "Weight"
    case workouts = "Workouts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .sleep: return "moon.zzz.fill"
        case .hydration: return "drop.fill"
        case .weight: return "scalemass.fill"
        case .workouts: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .heartRate: return AppColors.coral
        case .sleep: return AppColors.olive
        case .hydration: return AppColors.waterAccent
        case .weight: return AppColors.navy
        case .workouts: return AppColors.burntOrange
        }
    }
}

// MARK: - Timeframe

enum TrendTimeframe: String, CaseIterable {
    case week = "Week"
    case twoWeeks = "2 Weeks"
    case month = "Month"
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - HEADER (Matches Home typography)
// ═══════════════════════════════════════════════════════════════════════════════

private struct TrendsHeaderView: View {
    @Binding var selectedTimeframe: TrendTimeframe

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title (same as Home would have)
            Text("Trends")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            // Time filter pills
            HStack(spacing: 8) {
                ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                    TimeFilterPill(
                        label: timeframe.rawValue,
                        isSelected: selectedTimeframe == timeframe,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTimeframe = timeframe
                            }
                        }
                    )
                }
                Spacer()
            }
        }
        .padding(.top, 8)
    }
}

private struct TimeFilterPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(AppColors.navy)
                        : AnyShapeStyle(AppColors.divider.opacity(0.5))
                )
                .clipShape(Capsule())
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - INSIGHT CARD (Small, subtle - matches Home card style)
// ═══════════════════════════════════════════════════════════════════════════════

private struct TrendInsightCard: View {
    let insight: GeneratedInsight

    private var accentColor: Color {
        switch insight.color {
        case "olive": return AppColors.olive
        case "coral": return AppColors.coral
        case "navy": return AppColors.navy
        default: return AppColors.burntOrange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Accent bar (subtle orange by default)
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)

            // Icon with tinted background
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: insight.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            // Text
            Text(insight.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - METRIC CARDS (Same style as Home cards)
// ═══════════════════════════════════════════════════════════════════════════════

// Heart Rate - Warm coral tint (larger card)
private struct HeartRateCard: View {
    let trend: MetricTrend?
    let animate: Bool
    let onTap: () -> Void

    private var value: String {
        trend?.currentValue.replacingOccurrences(of: " bpm", with: "") ?? "—"
    }

    private var change: String {
        trend?.change ?? ""
    }

    private var isPositive: Bool {
        trend?.isPositive ?? true
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Header (matches Home WorkoutsCard)
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.coral)

                    Text("HEART RATE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    Spacer()
                }

                Spacer()

                // Value (same typography as Home)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("bpm")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }

                // Change badge (same style as Home streak badge)
                if !change.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(change)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.coral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.coral.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Mini sparkline
                if let data = trend?.dataPoints, !data.isEmpty {
                    TrendSparkline(data: data, color: AppColors.coral, animate: animate)
                        .frame(height: 24)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                // Subtle warm tint gradient (like Home cards)
                LinearGradient(
                    colors: [Color.white, AppColors.coral.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
            // Accent line at top (like Home WorkoutsCard)
            .overlay(
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.coral)
                        .frame(width: 40, height: 3)
                        .padding(.top, 12)
                    Spacer()
                }
            )
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// Sleep - Olive/green tint (narrower card)
private struct SleepTrendCard: View {
    let trend: MetricTrend?
    let animate: Bool
    let onTap: () -> Void

    private var value: String {
        trend?.currentValue.replacingOccurrences(of: " hrs", with: "") ?? "—"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Icon
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.olive)

                Spacer()

                // Value (matches Home SleepCard)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("h")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text("avg sleep")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.olive)

                // Mini sparkline
                if let data = trend?.dataPoints, !data.isEmpty {
                    TrendSparkline(data: data, color: AppColors.olive, animate: animate)
                        .frame(height: 20)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                // Subtle olive tint (matches Home)
                LinearGradient(
                    colors: [Color.white, AppColors.olive.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// Hydration - Blue tint (same as Home HydrationCard)
private struct HydrationTrendCard: View {
    let animate: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with blue tint background (same as Home)
                ZStack {
                    Circle()
                        .fill(AppColors.waterAccent.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.waterAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("HYDRATION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    Text("View trends")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.waterAccent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// Weight - Navy tint (same style as Home)
private struct WeightTrendCard: View {
    let trend: MetricTrend?
    let onTap: () -> Void

    private var value: String {
        trend?.currentValue ?? "—"
    }

    private var change: String {
        trend?.change ?? ""
    }

    private var isGoodTrend: Bool {
        // For weight loss, negative change is positive
        !(trend?.isPositive ?? false)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEIGHT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    if !change.isEmpty {
                        Text(change)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isGoodTrend ? AppColors.olive : AppColors.coral)
                    }
                }

                Spacer()

                // Mini trend indicator
                if let data = trend?.dataPoints, !data.isEmpty {
                    MiniSparkline(data: data, isPositive: isGoodTrend)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// Workouts - Orange tint (matches Home primary accent)
private struct WorkoutsTrendCard: View {
    let workoutCount: Int
    let timeframeDays: Int
    let animate: Bool
    let onTap: () -> Void

    private var averagePerWeek: Double {
        guard timeframeDays > 0 else { return 0 }
        return Double(workoutCount) / Double(timeframeDays) * 7
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with orange tint (same as Home)
                ZStack {
                    Circle()
                        .fill(AppColors.burntOrange.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "figure.run")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.burntOrange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUTS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textTertiary)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(workoutCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("total")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                // Weekly average (accent color)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", averagePerWeek))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.burntOrange)
                    Text("/week")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - SPARKLINES (Subtle, animated)
// ═══════════════════════════════════════════════════════════════════════════════

private struct TrendSparkline: View {
    let data: [CGFloat]
    let color: Color
    let animate: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let step = data.count > 1 ? width / CGFloat(data.count - 1) : width

            ZStack {
                // Area fill (very subtle)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    for (i, point) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = height - point * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(animate ? 0.2 : 0), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .animation(.easeOut(duration: 1.0), value: animate)

                // Line
                Path { path in
                    for (i, point) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = height - point * height
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .animation(.easeOut(duration: 1.2), value: animate)
            }
        }
    }
}

private struct MiniSparkline: View {
    let data: [CGFloat]
    let isPositive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.divider.opacity(0.5))
                .frame(width: 50, height: 30)

            Path { path in
                let width: CGFloat = 42
                let height: CGFloat = 22
                let step = width / CGFloat(max(data.count - 1, 1))

                for (i, point) in data.enumerated() {
                    let x = 4 + CGFloat(i) * step
                    let y = 4 + height - point * height
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                isPositive ? AppColors.olive : AppColors.coral,
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - ACTIVITY CALENDAR (Matches Home WeeklyTracker style)
// ═══════════════════════════════════════════════════════════════════════════════

private struct ActivityCalendarCard: View {
    let calendarData: [CalendarDayData]
    let workoutCount: Int
    let animate: Bool

    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let calendar = Calendar.current

    private var recentDays: [CalendarDayData?] {
        var result: [CalendarDayData?] = []
        let today = Date()

        for i in (0..<14).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let data = calendarData.first { calendar.isDate($0.date, inSameDayAs: date) }
                result.append(data ?? CalendarDayData(date: date, hasWorkout: false, workoutType: nil, feeling: .none))
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVITY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textTertiary)

                    Text("\(workoutCount) workouts")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                // Legend
                HStack(spacing: 12) {
                    LegendDot(color: AppColors.olive, label: "Good")
                    LegendDot(color: AppColors.coral, label: "Hard")
                }
            }

            // Calendar grid (2 weeks)
            VStack(spacing: 6) {
                // Day headers
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(days[i])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Week rows
                ForEach(0..<2, id: \.self) { week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let index = week * 7 + day
                            if index < recentDays.count, let dayData = recentDays[index] {
                                CalendarDayDot(
                                    data: dayData,
                                    animate: animate,
                                    delay: Double(index) * 0.03
                                )
                            } else {
                                Circle()
                                    .fill(AppColors.divider.opacity(0.3))
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

private struct CalendarDayDot: View {
    let data: CalendarDayData
    let animate: Bool
    let delay: Double

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(data.date)
    }

    private var feelingColor: Color {
        switch data.feeling {
        case .good: return AppColors.olive
        case .moderate: return AppColors.navy.opacity(0.4)
        case .hard: return AppColors.coral
        case .none: return AppColors.divider
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(data.hasWorkout ? feelingColor : AppColors.divider.opacity(0.4))
                .frame(width: 24, height: 24)
                .scaleEffect(animate && data.hasWorkout ? 1 : 0.6)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay), value: animate)

            if isToday {
                Circle()
                    .stroke(AppColors.navy, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }

            Text("\(calendar.component(.day, from: data.date))")
                .font(.system(size: 9, weight: isToday ? .bold : .medium))
                .foregroundStyle(data.hasWorkout ? .white : AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - METRICS LIST (Same card style as above)
// ═══════════════════════════════════════════════════════════════════════════════

private struct MetricsList: View {
    let trends: [MetricTrend]
    let onTap: (TrendMetricType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL METRICS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(trends) { trend in
                    MetricListRow(trend: trend, onTap: {
                        if let type = metricType(for: trend) {
                            onTap(type)
                        }
                    })
                }
            }
        }
    }

    private func metricType(for trend: MetricTrend) -> TrendMetricType? {
        if trend.title.contains("Heart") { return .heartRate }
        if trend.title.contains("Sleep") { return .sleep }
        if trend.title.contains("Weight") { return .weight }
        return nil
    }
}

private struct MetricListRow: View {
    let trend: MetricTrend
    let onTap: () -> Void

    private var accentColor: Color {
        switch trend.color {
        case "olive": return AppColors.olive
        case "coral": return AppColors.coral
        case "navy": return AppColors.navy
        default: return AppColors.burntOrange
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 8) {
                        Text(trend.currentValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)

                        if !trend.change.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(trend.change)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(trend.isPositive ? AppColors.olive : AppColors.coral)
                        }
                    }
                }

                Spacer()

                // Mini sparkline
                if !trend.dataPoints.isEmpty {
                    MiniSparkline(data: trend.dataPoints, isPositive: trend.isPositive)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(TrendCardButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - METRIC DETAIL VIEW
// ═══════════════════════════════════════════════════════════════════════════════

struct MetricDetailView: View {
    let metricType: TrendMetricType
    let trends: [MetricTrend]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe: TrendTimeframe = .month
    @State private var data: MetricDetailData?
    @State private var isLoading = true
    @State private var animateContent = false

    private let dataService = MetricDataService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // ═══════════════════════════════════════════════════
                // TOP: Header with current/average value
                // ═══════════════════════════════════════════════════
                MetricDetailHeader(
                    metricType: metricType,
                    data: data,
                    animate: animateContent
                )
                .padding(.top, 16)

                // Timeframe selector
                TimeframePicker(
                    selectedTimeframe: $selectedTimeframe,
                    onChange: { loadData() }
                )
                .padding(.horizontal, 20)

                if isLoading {
                    ProgressView()
                        .frame(height: 200)
                } else if let data = data {
                    if data.hasData {
                        // ═══════════════════════════════════════════════════
                        // MIDDLE: Chart
                        // ═══════════════════════════════════════════════════
                        MetricChartCard(
                            data: data,
                            metricType: metricType,
                            animate: animateContent
                        )
                        .padding(.horizontal, 20)

                        // ═══════════════════════════════════════════════════
                        // BOTTOM: Stats + Insight
                        // ═══════════════════════════════════════════════════
                        MetricStatsCard(data: data, metricType: metricType)
                            .padding(.horizontal, 20)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                        MetricInsightCard(data: data, metricType: metricType)
                            .padding(.horizontal, 20)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                    } else {
                        // Empty state
                        MetricEmptyState(metricType: metricType, insight: data.insight)
                            .padding(.horizontal, 20)
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.navy)
                }
            }
        }
        .onAppear {
            print("📊 MetricDetailView: Appeared for \(metricType.rawValue)")
            loadData()
            // Animate content in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
        .onChange(of: selectedTimeframe) { _, _ in
            loadData()
        }
    }

    private func loadData() {
        print("📊 MetricDetailView: Loading data for \(metricType.rawValue), timeframe=\(selectedTimeframe.rawValue)")
        isLoading = true

        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let days = selectedTimeframe.days

            switch metricType {
            case .hydration:
                data = dataService.fetchHydrationData(days: days)
            case .sleep:
                data = dataService.fetchSleepData(days: days)
            case .weight:
                data = dataService.fetchWeightData(days: days)
            case .heartRate:
                data = dataService.fetchHeartRateData(days: days)
            case .workouts:
                data = dataService.fetchWorkoutsData(days: days)
            }

            isLoading = false
            print("📊 MetricDetailView: Data loaded - hasData=\(data?.hasData ?? false), entries=\(data?.entryCount ?? 0)")
        }
    }
}

// MARK: - Metric Detail Header

private struct MetricDetailHeader: View {
    let metricType: TrendMetricType
    let data: MetricDetailData?
    let animate: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(metricType.color.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: metricType.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(metricType.color)
            }
            .scaleEffect(animate ? 1 : 0.8)
            .opacity(animate ? 1 : 0)

            // Title
            Text(metricType.rawValue)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            // Current value (large)
            if let data = data, data.hasData {
                Text(data.currentValue)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(metricType.color)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)

                // Date range label
                Text(data.dateRange)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animate)
    }
}

// MARK: - Timeframe Picker

private struct TimeframePicker: View {
    @Binding var selectedTimeframe: TrendTimeframe
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeframe = timeframe
                    }
                    onChange()
                } label: {
                    Text(timeframe.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedTimeframe == timeframe ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedTimeframe == timeframe
                                ? AnyShapeStyle(AppColors.navy)
                                : AnyShapeStyle(AppColors.divider.opacity(0.5))
                        )
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
    }
}

// MARK: - Metric Chart Card

private struct MetricChartCard: View {
    let data: MetricDetailData
    let metricType: TrendMetricType
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("TREND")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()

                // Change badge
                HStack(spacing: 4) {
                    Image(systemName: data.isPositiveChange ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(data.changeLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(data.isPositiveChange ? AppColors.olive : AppColors.coral)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((data.isPositiveChange ? AppColors.olive : AppColors.coral).opacity(0.12))
                .clipShape(Capsule())
            }

            // Chart
            if !data.chartData.isEmpty {
                DetailChart(data: data.chartData, color: metricType.color)
                    .frame(height: 180)

                // X-axis labels
                if data.chartLabels.count >= 2 {
                    HStack {
                        Text(data.chartLabels.first ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                        Spacer()
                        if data.chartLabels.count > 2 {
                            Text(data.chartLabels[data.chartLabels.count / 2])
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.textTertiary)
                            Spacer()
                        }
                        Text(data.chartLabels.last ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animate)
    }
}

// MARK: - Metric Stats Card

private struct MetricStatsCard: View {
    let data: MetricDetailData
    let metricType: TrendMetricType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 12) {
                // Current value stat
                TrendStatCard(
                    label: metricType == .workouts ? "Total" : "Current",
                    value: data.currentValue,
                    color: metricType.color
                )

                // Average stat
                TrendStatCard(
                    label: metricType == .workouts ? "Per Week" : "Average",
                    value: data.averageValue,
                    color: AppColors.navy
                )

                // Goal progress if available
                if let percentOfGoal = data.percentOfGoal, let goalLabel = data.goalLabel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goalLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.divider.opacity(0.5))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(metricType.color)
                                    .frame(width: geo.size.width * min(percentOfGoal / 100, 1), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(min(percentOfGoal, 100)))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(metricType.color)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(metricType.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: data.entryCount)
    }
}

// MARK: - Metric Insight Card

private struct MetricInsightCard: View {
    let data: MetricDetailData
    let metricType: TrendMetricType

    var body: some View {
        HStack(spacing: 12) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(metricType.color)
                .frame(width: 4)

            // Lightbulb icon
            ZStack {
                Circle()
                    .fill(metricType.color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(metricType.color)
            }

            // Insight text
            VStack(alignment: .leading, spacing: 4) {
                Text("INSIGHT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppColors.textTertiary)

                Text(data.insight)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(4)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: data.entryCount)
    }
}

// MARK: - Metric Empty State

private struct MetricEmptyState: View {
    let metricType: TrendMetricType
    let insight: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            // Empty illustration
            ZStack {
                Circle()
                    .fill(metricType.color.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: metricType.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(metricType.color.opacity(0.4))
            }

            VStack(spacing: 8) {
                Text("No \(metricType.rawValue) Data")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(insight)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

private struct DetailChart: View {
    let data: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let step = data.count > 1 ? width / CGFloat(data.count - 1) : width

            ZStack {
                // Grid lines
                ForEach(0..<5) { i in
                    let y = height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(AppColors.divider.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }

                // Area fill
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    for (i, point) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = height - point * height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    for (i, point) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = height - point * height
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                // End dot
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .position(
                        x: CGFloat(data.count - 1) * step,
                        y: height - (data.last ?? 0) * height
                    )
            }
        }
    }
}

private struct TrendStatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - BUTTON STYLE (Same as Home)
// ═══════════════════════════════════════════════════════════════════════════════

private struct TrendCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    TrendsView()
}
