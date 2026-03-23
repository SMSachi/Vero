//
//  TrendsView.swift
//  Insio Health
//
//  Trends screen - displays analyzed workout patterns and insights
//  using data from TrendAnalysisEngine.
//

import SwiftUI

// MARK: - Trends View

struct TrendsView: View {
    @StateObject private var viewModel = TrendsViewModel()

    // Animation states
    @State private var headerVisible = false
    @State private var insightsVisible = false
    @State private var calendarVisible = false
    @State private var chartsVisible = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.sectionSpacing) {

                    // Header
                    TrendsHeader(
                        selectedTimeframe: $viewModel.selectedTimeframe,
                        subtitle: viewModel.selectedTimeframe.subtitleText
                    )
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 15)

                    // Insight Cards or Empty State
                    if !viewModel.topInsights.isEmpty {
                        InsightCardsRow(insights: viewModel.topInsights)
                            .opacity(insightsVisible ? 1 : 0)
                            .offset(y: insightsVisible ? 0 : 15)
                    } else if !viewModel.isLoading && !viewModel.hasRealData {
                        TrendsEmptyState()
                            .opacity(insightsVisible ? 1 : 0)
                            .offset(y: insightsVisible ? 0 : 15)
                    }

                    // Activity Calendar
                    ActivityCalendarSection(
                        calendarData: viewModel.calendarData,
                        workoutCount: viewModel.workoutCount,
                        timeframeDays: viewModel.timeframeDays
                    )
                    .opacity(calendarVisible ? 1 : 0)
                    .offset(y: calendarVisible ? 0 : 15)

                    // Trend Charts
                    if !viewModel.metricTrends.isEmpty {
                        TrendChartsSection(trends: viewModel.metricTrends)
                            .opacity(chartsVisible ? 1 : 0)
                            .offset(y: chartsVisible ? 0 : 12)
                    }
                }
                .padding(.top, AppSpacing.Layout.topPadding)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.loadTrends()
        }
        .onAppear {
            startEntranceAnimations()
            // Refresh trends when returning to this tab (picks up newly added workouts)
            Task {
                await viewModel.refresh()
            }
        }
    }

    private func startEntranceAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.15)) {
            insightsVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.25)) {
            calendarVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.4)) {
            chartsVisible = true
        }
    }
}

// MARK: - Timeframe

enum TrendTimeframe: String, CaseIterable {
    case week = "7D"
    case twoWeeks = "14D"
    case month = "30D"

    var label: String {
        switch self {
        case .week: return "Past week"
        case .twoWeeks: return "Past 2 weeks"
        case .month: return "Past month"
        }
    }
}

// MARK: - Header

struct TrendsHeader: View {
    @Binding var selectedTimeframe: TrendTimeframe
    let subtitle: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.Layout.titleSpacing) {
                Text("Trends")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // Time filter
            Menu {
                ForEach(TrendTimeframe.allCases, id: \.self) { timeframe in
                    Button(timeframe.label) {
                        withAnimation(AppAnimation.springQuick) {
                            selectedTimeframe = timeframe
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedTimeframe.rawValue)
                        .font(AppTypography.labelMedium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(AppColors.navy)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(AppColors.navy.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Insight Cards Row

struct InsightCardsRow: View {
    let insights: [GeneratedInsight]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.Layout.cardSpacing) {
                ForEach(insights) { insight in
                    TrendInsightCard(insight: insight)
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct TrendInsightCard: View {
    let insight: GeneratedInsight

    private var color: Color {
        switch insight.color {
        case "olive": return AppColors.olive
        case "coral": return AppColors.coral
        case "navy": return AppColors.navy
        case "indigo": return .indigo
        default: return AppColors.navy
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: AppSpacing.Icon.circleSmall, height: AppSpacing.Icon.circleSmall)

                Image(systemName: insight.icon)
                    .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(insight.description)
                .font(AppTypography.cardSubtitle)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.Layout.cardPadding)
        .frame(width: 280)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

// MARK: - Empty State

struct EmptyInsightsPlaceholder: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)

            Text("Complete more workouts to see trends")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Activity Calendar Section

struct ActivityCalendarSection: View {
    let calendarData: [CalendarDayData]
    let workoutCount: Int
    let timeframeDays: Int

    private let calendar = Calendar.current

    private var calendarGrid: [[CalendarDayData?]] {
        var weeks: [[CalendarDayData?]] = []
        let today = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return weeks
        }

        for weekOffset in (-3...0).reversed() {
            var week: [CalendarDayData?] = []
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) else {
                continue
            }

            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    week.append(nil)
                    continue
                }
                let dayData = calendarData.first { calendar.isDate($0.date, inSameDayAs: date) }
                week.append(dayData)
            }
            weeks.append(week)
        }
        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    if workoutCount > 0 {
                        Text("\(workoutCount) workout\(workoutCount == 1 ? "" : "s") in \(timeframeDays) days")
                            .font(AppTypography.statLabel)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                HStack(spacing: AppSpacing.md) {
                    CalendarLegend(color: AppColors.olive, label: "Good")
                    CalendarLegend(color: AppColors.coral, label: "Hard")
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            // Calendar card
            VStack(spacing: AppSpacing.xs) {
                // Day headers
                // Note: Use enumerated() to avoid duplicate IDs (T appears twice, S appears twice)
                HStack(spacing: 4) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(AppTypography.miniLabel)
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Weeks
                VStack(spacing: 4) {
                    ForEach(Array(calendarGrid.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 4) {
                            ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, dayData in
                                if let data = dayData {
                                    CalendarDayView(data: data)
                                } else {
                                    // Placeholder for days outside our data range
                                    let today = Date()
                                    let placeholderDay = calendar.component(.day, from: today)
                                    CalendarDayViewPlaceholder(day: placeholderDay)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct CalendarDayView: View {
    let data: CalendarDayData

    private let calendar = Calendar.current

    private var day: Int {
        calendar.component(.day, from: data.date)
    }

    private var isToday: Bool {
        calendar.isDateInToday(data.date)
    }

    private var isFuture: Bool {
        data.date > Date()
    }

    private var feelingColor: Color {
        switch data.feeling {
        case .good: return AppColors.olive
        case .moderate: return AppColors.navy.opacity(0.5)
        case .hard: return AppColors.coral
        case .none: return .clear
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
                .frame(height: 36)

            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 11, weight: isToday ? .bold : .medium))
                    .foregroundStyle(textColor)

                if data.hasWorkout {
                    Circle()
                        .fill(feelingColor)
                        .frame(width: 6, height: 6)
                } else if !isFuture {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        if isToday {
            return AppColors.navy.opacity(0.1)
        }
        if data.hasWorkout {
            return feelingColor.opacity(0.1)
        }
        return Color.clear
    }

    private var textColor: Color {
        if isFuture {
            return AppColors.textTertiary.opacity(0.5)
        }
        if isToday {
            return AppColors.navy
        }
        return AppColors.textSecondary
    }
}

struct CalendarDayViewPlaceholder: View {
    let day: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
                .frame(height: 36)

            Text("\(day)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CalendarLegend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppTypography.statLabel)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}

// MARK: - Trend Charts Section

struct TrendChartsSection: View {
    let trends: [MetricTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.Layout.cardSpacing) {
            Text("Metrics")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: AppSpacing.Layout.cardSpacing) {
                ForEach(trends) { trend in
                    TrendChartRow(trend: trend)
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct TrendChartRow: View {
    let trend: MetricTrend

    private var color: Color {
        switch trend.color {
        case "olive": return AppColors.olive
        case "coral": return AppColors.coral
        case "navy": return AppColors.navy
        default: return AppColors.navy
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.title)
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textSecondary)

                Text(trend.currentValue)
                    .font(AppTypography.statValue)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: trend.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(trend.change)
                        .font(AppTypography.statLabel)
                }
                .foregroundStyle(trend.isPositive ? AppColors.olive : AppColors.coral)
            }
            .frame(width: 100, alignment: .leading)

            if !trend.dataPoints.isEmpty {
                TrendSparkline(data: trend.dataPoints, color: color)
                    .frame(height: 40)
            } else {
                Spacer()
                Text("No data")
                    .font(AppTypography.statLabel)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.Layout.cardPadding)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

struct TrendSparkline: View {
    let data: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let step = width / CGFloat(data.count - 1)

            ZStack {
                // Area fill
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    for (i, point) in data.enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: height - point * height))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.02)],
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
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // End dot
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(
                        x: CGFloat(data.count - 1) * step,
                        y: height - (data.last ?? 0) * height
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TrendsView()
}
