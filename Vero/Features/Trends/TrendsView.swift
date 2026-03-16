//
//  TrendsView.swift
//  Vero
//
//  Trends screen - unified design system
//

import SwiftUI

// MARK: - Trends View

struct TrendsView: View {
    @State private var selectedTimeframe: TrendTimeframe = .month

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
                    TrendsHeader(selectedTimeframe: $selectedTimeframe)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 15)

                    // Insight Cards
                    InsightCardsRow()
                        .opacity(insightsVisible ? 1 : 0)
                        .offset(y: insightsVisible ? 0 : 15)

                    // Activity Calendar
                    ActivityCalendarSection()
                        .opacity(calendarVisible ? 1 : 0)
                        .offset(y: calendarVisible ? 0 : 15)

                    // Trend Charts
                    TrendChartsSection()
                        .opacity(chartsVisible ? 1 : 0)
                        .offset(y: chartsVisible ? 0 : 12)
                }
                .padding(.top, AppSpacing.Layout.topPadding)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
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

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.Layout.titleSpacing) {
                Text("Trends")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Your patterns this month")
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
    private let insights: [TrendInsightItem] = [
        TrendInsightItem(
            icon: "arrow.down.right",
            color: AppColors.olive,
            text: "You recover faster after strength workouts."
        ),
        TrendInsightItem(
            icon: "moon.zzz.fill",
            color: .indigo,
            text: "Your sleep strongly predicts workout difficulty."
        ),
        TrendInsightItem(
            icon: "flame.fill",
            color: AppColors.coral,
            text: "High intensity days need 48hrs recovery."
        )
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.Layout.cardSpacing) {
                ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                    TrendInsightCard(insight: insight)
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct TrendInsightItem {
    let icon: String
    let color: Color
    let text: String
}

struct TrendInsightCard: View {
    let insight: TrendInsightItem

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(insight.color.opacity(0.12))
                    .frame(width: AppSpacing.Icon.circleSmall, height: AppSpacing.Icon.circleSmall)

                Image(systemName: insight.icon)
                    .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                    .foregroundStyle(insight.color)
            }

            Text(insight.text)
                .font(AppTypography.cardSubtitle)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.Layout.cardPadding)
        .frame(width: 260)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

// MARK: - Activity Calendar Section

struct ActivityCalendarSection: View {
    private let calendar = Calendar.current
    private let today = Date()

    private var calendarData: [[CalendarDay]] {
        var weeks: [[CalendarDay]] = []
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        for weekOffset in (-3...0).reversed() {
            var week: [CalendarDay] = []
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek)!

            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let dayNum = calendar.component(.day, from: date)
                let isToday = calendar.isDateInToday(date)
                let isFuture = date > today

                let workout = mockWorkoutFor(weekOffset: weekOffset, dayOffset: dayOffset, isFuture: isFuture)

                week.append(CalendarDay(
                    day: dayNum,
                    isToday: isToday,
                    isFuture: isFuture,
                    workout: workout
                ))
            }
            weeks.append(week)
        }
        return weeks
    }

    private func mockWorkoutFor(weekOffset: Int, dayOffset: Int, isFuture: Bool) -> CalendarWorkout? {
        guard !isFuture else { return nil }

        let patterns: [Int: (WorkoutType, CalendarWorkout.Feeling)] = [
            1: (.run, .good),
            3: (.strength, .moderate),
            5: (.run, .good),
            6: (.hiit, .hard)
        ]

        if weekOffset == 0 && dayOffset > calendar.component(.weekday, from: today) - 1 {
            return nil
        }

        if let pattern = patterns[dayOffset] {
            if weekOffset == -2 && dayOffset == 3 { return nil }
            if weekOffset == -1 && dayOffset == 6 { return nil }
            return CalendarWorkout(type: pattern.0, feeling: pattern.1)
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section header
            HStack {
                Text("Activity")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

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
                HStack(spacing: 4) {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(AppTypography.miniLabel)
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Weeks
                VStack(spacing: 4) {
                    ForEach(Array(calendarData.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 4) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                CalendarDayView(day: day)
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

struct CalendarDay {
    let day: Int
    let isToday: Bool
    let isFuture: Bool
    let workout: CalendarWorkout?
}

struct CalendarWorkout {
    let type: WorkoutType
    let feeling: Feeling

    enum Feeling {
        case good, moderate, hard

        var color: Color {
            switch self {
            case .good: return AppColors.olive
            case .moderate: return AppColors.navy.opacity(0.5)
            case .hard: return AppColors.coral
            }
        }
    }
}

struct CalendarDayView: View {
    let day: CalendarDay

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
                .frame(height: 36)

            VStack(spacing: 1) {
                Text("\(day.day)")
                    .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(textColor)

                if let workout = day.workout {
                    Circle()
                        .fill(workout.feeling.color)
                        .frame(width: 6, height: 6)
                } else if !day.isFuture {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        if day.isToday {
            return AppColors.navy.opacity(0.1)
        }
        if day.workout != nil {
            return day.workout!.feeling.color.opacity(0.1)
        }
        return Color.clear
    }

    private var textColor: Color {
        if day.isFuture {
            return AppColors.textTertiary.opacity(0.5)
        }
        if day.isToday {
            return AppColors.navy
        }
        return AppColors.textSecondary
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
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.Layout.cardSpacing) {
            Text("Metrics")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

            VStack(spacing: AppSpacing.Layout.cardSpacing) {
                TrendChartRow(
                    title: "HRV Trend",
                    value: "48ms",
                    change: "+12%",
                    isPositive: true,
                    data: [0.4, 0.45, 0.42, 0.5, 0.55, 0.52, 0.6, 0.58, 0.65, 0.62],
                    color: AppColors.olive
                )

                TrendChartRow(
                    title: "Workout Difficulty",
                    value: "Moderate",
                    change: "Stable",
                    isPositive: true,
                    data: [0.6, 0.55, 0.58, 0.5, 0.52, 0.48, 0.5, 0.45, 0.48, 0.45],
                    color: AppColors.navy
                )

                TrendChartRow(
                    title: "Recovery Score",
                    value: "78",
                    change: "+8%",
                    isPositive: true,
                    data: [0.6, 0.62, 0.58, 0.65, 0.7, 0.68, 0.72, 0.75, 0.78, 0.78],
                    color: AppColors.coral
                )
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct TrendChartRow: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let data: [CGFloat]
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textSecondary)

                Text(value)
                    .font(AppTypography.statValue)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(change)
                        .font(AppTypography.statLabel)
                }
                .foregroundStyle(isPositive ? AppColors.olive : AppColors.coral)
            }
            .frame(width: 100, alignment: .leading)

            TrendSparkline(data: data, color: color)
                .frame(height: 40)
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
