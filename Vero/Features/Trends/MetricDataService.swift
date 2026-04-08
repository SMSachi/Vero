//
//  MetricDataService.swift
//  Insio Health
//
//  Service for aggregating metric-specific data for the Trends detail views.
//  Fetches real data from PersistenceService and computes stats.
//  Uses UnitPreferences for metric/imperial formatting.
//

import Foundation
import SwiftUI

// MARK: - Metric Data Service

@MainActor
final class MetricDataService {

    static let shared = MetricDataService()

    private let persistence = PersistenceService.shared
    private var units: UnitPreferences { UnitPreferences.shared }

    private init() {}

    // MARK: - Hydration Data

    func fetchHydrationData(days: Int) -> MetricDetailData {
        print("📊 MetricDataService: Fetching hydration data for \(days) days")

        let contexts = fetchContexts(days: days)
        let waterEntries = contexts.compactMap { ctx -> (date: Date, value: Double)? in
            guard let ml = ctx.waterIntakeMl, ml > 0 else { return nil }
            return (ctx.date, Double(ml) / 1000.0) // Always stored in liters
        }.sorted { $0.date < $1.date }

        guard !waterEntries.isEmpty else {
            print("📊 MetricDataService: No hydration data found")
            return MetricDetailData.empty(for: .hydration)
        }

        let values = waterEntries.map { $0.value }  // In liters
        let averageLiters = values.reduce(0, +) / Double(values.count)
        let latestLiters = waterEntries.last?.value ?? 0
        let goalLiters = 2.5
        let percentOfGoal = (averageLiters / goalLiters) * 100

        // Calculate change (compare first half vs second half)
        let change = calculateChange(values: values)

        // Generate chart data points (normalized 0-1)
        let maxVal = values.max() ?? 1
        let chartData = values.map { CGFloat($0 / maxVal) }

        // Format for display using unit preferences
        let displayAverage = units.formatVolume(averageLiters)
        let displayLatest = units.formatVolume(latestLiters)
        let displayGoal = units.dailyHydrationGoalFormatted

        // Generate insight (use liters for logic, show in user units)
        let insight: String
        if averageLiters >= 2.5 {
            insight = "Excellent hydration! Averaging \(displayAverage) daily supports optimal recovery and performance."
        } else if averageLiters >= 2.0 {
            insight = "Good hydration at \(displayAverage) daily. Try adding one more glass to reach optimal levels."
        } else if averageLiters >= 1.5 {
            insight = "Hydration could improve. At \(displayAverage) daily, consider setting reminders to drink more water."
        } else {
            insight = "Low hydration detected. Aim for \(displayGoal) daily for better energy and recovery."
        }

        print("📊 MetricDataService: Hydration - avg=\(displayAverage), entries=\(waterEntries.count)")

        return MetricDetailData(
            metricType: .hydration,
            currentValue: displayLatest,
            averageValue: displayAverage,
            change: change,
            changeLabel: change >= 0 ? "+\(String(format: "%.0f", abs(change)))%" : "\(String(format: "%.0f", change))%",
            isPositiveChange: change >= 0,
            chartData: chartData,
            chartLabels: generateDateLabels(for: waterEntries.map { $0.date }),
            percentOfGoal: percentOfGoal,
            goalLabel: "Goal: \(displayGoal)",
            insight: insight,
            entryCount: waterEntries.count,
            dateRange: dateRangeLabel(days: days)
        )
    }

    // MARK: - Sleep Data

    func fetchSleepData(days: Int) -> MetricDetailData {
        print("📊 MetricDataService: Fetching sleep data for \(days) days")

        let contexts = fetchContexts(days: days)
        let sleepEntries = contexts.compactMap { ctx -> (date: Date, value: Double)? in
            guard ctx.sleepHours > 0 else { return nil }
            return (ctx.date, ctx.sleepHours)
        }.sorted { $0.date < $1.date }

        guard !sleepEntries.isEmpty else {
            print("📊 MetricDataService: No sleep data found")
            return MetricDetailData.empty(for: .sleep)
        }

        let values = sleepEntries.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        let latest = sleepEntries.last?.value ?? 0
        let goalHours = 8.0
        let percentOfGoal = (average / goalHours) * 100

        let change = calculateChange(values: values)

        // Normalize chart data (typically 4-10 hours range)
        let minSleep = 4.0
        let maxSleep = 10.0
        let chartData = values.map { CGFloat(($0 - minSleep) / (maxSleep - minSleep)).clamped(to: 0...1) }

        let insight: String
        if average >= 7.5 {
            insight = "Great sleep averaging \(String(format: "%.1f", average)) hours. This supports optimal recovery and cognitive function."
        } else if average >= 7.0 {
            insight = "Good sleep at \(String(format: "%.1f", average)) hours average. A bit more would further boost recovery."
        } else if average >= 6.0 {
            insight = "Sleep averaging \(String(format: "%.1f", average)) hours is below optimal. Prioritize 7-8 hours for better performance."
        } else {
            insight = "Sleep deficit detected at \(String(format: "%.1f", average)) hours. This may impact recovery and energy levels."
        }

        print("📊 MetricDataService: Sleep - avg=\(String(format: "%.1f", average))h, entries=\(sleepEntries.count)")

        return MetricDetailData(
            metricType: .sleep,
            currentValue: String(format: "%.1f hrs", latest),
            averageValue: String(format: "%.1f hrs", average),
            change: change,
            changeLabel: change >= 0 ? "+\(String(format: "%.1f", abs(change)))%" : "\(String(format: "%.1f", change))%",
            isPositiveChange: change >= 0,
            chartData: chartData,
            chartLabels: generateDateLabels(for: sleepEntries.map { $0.date }),
            percentOfGoal: min(percentOfGoal, 100),
            goalLabel: "Goal: \(Int(goalHours)) hrs",
            insight: insight,
            entryCount: sleepEntries.count,
            dateRange: dateRangeLabel(days: days)
        )
    }

    // MARK: - Weight Data

    func fetchWeightData(days: Int) -> MetricDetailData {
        print("📊 MetricDataService: Fetching weight data for \(days) days")

        let contexts = fetchContexts(days: days)
        let weightEntries = contexts.compactMap { ctx -> (date: Date, value: Double)? in
            guard let kg = ctx.weightKg, kg > 0 else { return nil }
            return (ctx.date, kg)
        }.sorted { $0.date < $1.date }

        guard !weightEntries.isEmpty else {
            print("📊 MetricDataService: No weight data found")
            return MetricDetailData.empty(for: .weight)
        }

        let values = weightEntries.map { $0.value }
        let latest = weightEntries.last?.value ?? 0
        let first = weightEntries.first?.value ?? latest
        let absoluteChange = latest - first
        let percentChange = first > 0 ? (absoluteChange / first) * 100 : 0

        // For weight loss goal, losing weight is positive
        let goalService = UserGoalService.shared
        let isWeightLossGoal = goalService.primaryGoal == .weightLoss
        let isPositive = isWeightLossGoal ? absoluteChange < 0 : absoluteChange > 0

        // Normalize chart data
        let minWeight = (values.min() ?? 50) - 2
        let maxWeight = (values.max() ?? 100) + 2
        let range = maxWeight - minWeight
        let chartData = values.map { CGFloat(($0 - minWeight) / range) }

        // Format change for insight using user's preferred units
        let changeForInsight = String(format: "%.1f %@", units.displayWeight(abs(absoluteChange)), units.weightUnit)
        let latestForInsight = String(format: "%.1f %@", units.displayWeight(latest), units.weightUnit)

        let insight: String
        if weightEntries.count < 3 {
            insight = "Keep logging weight to see trends. Consistent tracking helps identify patterns."
        } else if isWeightLossGoal {
            if absoluteChange < -0.5 {
                insight = "Great progress! You've lost \(changeForInsight). Keep up the consistent effort."
            } else if absoluteChange > 0.5 {
                insight = "Weight has increased by \(changeForInsight). Review nutrition and activity levels."
            } else {
                insight = "Weight is stable. For weight loss, consider adjusting calorie intake or increasing activity."
            }
        } else {
            if absoluteChange > 0.5 {
                insight = "Weight increased by \(changeForInsight). Ensure it's lean mass through strength training."
            } else if absoluteChange < -0.5 {
                insight = "Weight decreased by \(changeForInsight). Monitor if this aligns with your goals."
            } else {
                insight = "Weight is stable at \(latestForInsight)."
            }
        }

        print("📊 MetricDataService: Weight - latest=\(String(format: "%.1f", latest))kg, change=\(String(format: "%.1f", absoluteChange))kg")

        // Format using unit preferences (kg or lb)
        let displayLatest = units.formatWeight(latest)
        let displayAverage = units.formatWeight(values.reduce(0, +) / Double(values.count))
        let displayChange = String(format: "%@%.1f %@",
            absoluteChange >= 0 ? "+" : "",
            units.displayWeight(abs(absoluteChange)),
            units.weightUnit)

        return MetricDetailData(
            metricType: .weight,
            currentValue: displayLatest,
            averageValue: displayAverage,
            change: percentChange,
            changeLabel: displayChange,
            isPositiveChange: isPositive,
            chartData: chartData,
            chartLabels: generateDateLabels(for: weightEntries.map { $0.date }),
            percentOfGoal: nil,
            goalLabel: nil,
            insight: insight,
            entryCount: weightEntries.count,
            dateRange: dateRangeLabel(days: days)
        )
    }

    // MARK: - Heart Rate Data

    func fetchHeartRateData(days: Int) -> MetricDetailData {
        print("📊 MetricDataService: Fetching heart rate data for \(days) days")

        let contexts = fetchContexts(days: days)
        let hrEntries = contexts.compactMap { ctx -> (date: Date, value: Double)? in
            guard let rhr = ctx.restingHeartRate, rhr > 0 else { return nil }
            return (ctx.date, Double(rhr))
        }.sorted { $0.date < $1.date }

        guard !hrEntries.isEmpty else {
            print("📊 MetricDataService: No heart rate data found")
            return MetricDetailData.empty(for: .heartRate)
        }

        let values = hrEntries.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        let latest = hrEntries.last?.value ?? 0

        let change = calculateChange(values: values)
        // Lower resting HR is generally better
        let isPositive = change <= 0

        // Normalize (typical RHR range 50-90)
        let minHR = 45.0
        let maxHR = 95.0
        let chartData = values.map { CGFloat(($0 - minHR) / (maxHR - minHR)).clamped(to: 0...1) }

        let insight: String
        if average < 60 {
            insight = "Excellent cardiovascular fitness! Resting HR of \(Int(average)) bpm indicates strong heart health."
        } else if average < 70 {
            insight = "Good resting heart rate at \(Int(average)) bpm. Regular cardio can lower this further."
        } else if average < 80 {
            insight = "Average resting HR at \(Int(average)) bpm. Consider more aerobic exercise to improve."
        } else {
            insight = "Elevated resting HR at \(Int(average)) bpm. Focus on recovery, stress management, and cardio."
        }

        print("📊 MetricDataService: Heart Rate - avg=\(Int(average))bpm, entries=\(hrEntries.count)")

        return MetricDetailData(
            metricType: .heartRate,
            currentValue: "\(Int(latest)) bpm",
            averageValue: "\(Int(average)) bpm",
            change: change,
            changeLabel: change >= 0 ? "+\(String(format: "%.0f", abs(change)))%" : "\(String(format: "%.0f", change))%",
            isPositiveChange: isPositive,
            chartData: chartData,
            chartLabels: generateDateLabels(for: hrEntries.map { $0.date }),
            percentOfGoal: nil,
            goalLabel: nil,
            insight: insight,
            entryCount: hrEntries.count,
            dateRange: dateRangeLabel(days: days)
        )
    }

    // MARK: - Workouts Data

    func fetchWorkoutsData(days: Int) -> MetricDetailData {
        print("📊 MetricDataService: Fetching workouts data for \(days) days")

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let workouts = persistence.fetchWorkouts(from: startDate, to: endDate)

        guard !workouts.isEmpty else {
            print("📊 MetricDataService: No workout data found")
            return MetricDetailData.empty(for: .workouts)
        }

        let totalWorkouts = workouts.count
        let weeksInPeriod = max(1, Double(days) / 7.0)
        let workoutsPerWeek = Double(totalWorkouts) / weeksInPeriod

        // Group by day for chart
        let calendar = Calendar.current
        var workoutsByDay: [Date: Int] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            workoutsByDay[day, default: 0] += 1
        }

        // Generate daily counts for chart
        var dailyCounts: [(date: Date, count: Int)] = []
        for offset in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: endDate) {
                let day = calendar.startOfDay(for: date)
                dailyCounts.append((day, workoutsByDay[day] ?? 0))
            }
        }

        // Normalize for chart (0 or 1 workout per day typical)
        let maxDailyWorkouts = max(1, dailyCounts.map { $0.count }.max() ?? 1)
        let chartData = dailyCounts.map { CGFloat($0.count) / CGFloat(maxDailyWorkouts) }

        // Calculate workout type distribution
        var typeDistribution: [WorkoutType: Int] = [:]
        for workout in workouts {
            typeDistribution[workout.type, default: 0] += 1
        }
        let topType = typeDistribution.max(by: { $0.value < $1.value })?.key

        // Goal is typically 3-4 workouts per week
        let goalPerWeek = 4.0
        let percentOfGoal = (workoutsPerWeek / goalPerWeek) * 100

        let insight: String
        if workoutsPerWeek >= 4 {
            insight = "Excellent consistency at \(String(format: "%.1f", workoutsPerWeek)) workouts/week. Great for building fitness."
        } else if workoutsPerWeek >= 3 {
            insight = "Good activity level at \(String(format: "%.1f", workoutsPerWeek)) workouts/week. On track for health benefits."
        } else if workoutsPerWeek >= 2 {
            insight = "Moderate activity at \(String(format: "%.1f", workoutsPerWeek)) workouts/week. Adding one more would boost progress."
        } else {
            insight = "Room for more activity. Aim for 3-4 workouts per week for optimal health benefits."
        }

        print("📊 MetricDataService: Workouts - total=\(totalWorkouts), perWeek=\(String(format: "%.1f", workoutsPerWeek))")

        return MetricDetailData(
            metricType: .workouts,
            currentValue: "\(totalWorkouts) total",
            averageValue: String(format: "%.1f/week", workoutsPerWeek),
            change: 0,
            changeLabel: topType != nil ? "Most: \(topType!.rawValue)" : "",
            isPositiveChange: true,
            chartData: chartData,
            chartLabels: generateDateLabels(for: dailyCounts.map { $0.date }),
            percentOfGoal: min(percentOfGoal, 100),
            goalLabel: "Goal: \(Int(goalPerWeek))/week",
            insight: insight,
            entryCount: totalWorkouts,
            dateRange: dateRangeLabel(days: days)
        )
    }

    // MARK: - Helpers

    private func fetchContexts(days: Int) -> [DailyContext] {
        let all = persistence.fetchRecentDailyContexts(limit: days + 7)
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return all.filter { $0.date >= cutoff }
    }

    private func calculateChange(values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }

        let midpoint = values.count / 2
        let firstHalf = Array(values.prefix(midpoint))
        let secondHalf = Array(values.suffix(from: midpoint))

        guard !firstHalf.isEmpty && !secondHalf.isEmpty else { return 0 }

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return 0 }
        return ((secondAvg - firstAvg) / firstAvg) * 100
    }

    private func generateDateLabels(for dates: [Date]) -> [String] {
        guard !dates.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"

        // Return labels for first, middle, and last
        if dates.count <= 3 {
            return dates.map { formatter.string(from: $0) }
        }

        let first = formatter.string(from: dates.first!)
        let last = formatter.string(from: dates.last!)
        let mid = formatter.string(from: dates[dates.count / 2])

        return [first, mid, last]
    }

    private func dateRangeLabel(days: Int) -> String {
        switch days {
        case 7: return "Past week"
        case 14: return "Past 2 weeks"
        case 30: return "Past month"
        default: return "Past \(days) days"
        }
    }
}

// MARK: - Metric Detail Data

struct MetricDetailData {
    let metricType: TrendMetricType
    let currentValue: String
    let averageValue: String
    let change: Double
    let changeLabel: String
    let isPositiveChange: Bool
    let chartData: [CGFloat]
    let chartLabels: [String]
    let percentOfGoal: Double?
    let goalLabel: String?
    let insight: String
    let entryCount: Int
    let dateRange: String

    var hasData: Bool {
        entryCount > 0
    }

    static func empty(for type: TrendMetricType) -> MetricDetailData {
        let emptyInsight: String
        switch type {
        case .hydration:
            emptyInsight = "Start logging your water intake to track hydration trends."
        case .sleep:
            emptyInsight = "Log your sleep to see patterns and get personalized insights."
        case .weight:
            emptyInsight = "Track your weight regularly to monitor progress."
        case .heartRate:
            emptyInsight = "Connect a heart rate monitor to track cardiovascular health."
        case .workouts:
            emptyInsight = "Complete workouts to see your activity trends here."
        }

        return MetricDetailData(
            metricType: type,
            currentValue: "—",
            averageValue: "—",
            change: 0,
            changeLabel: "No data",
            isPositiveChange: true,
            chartData: [],
            chartLabels: [],
            percentOfGoal: nil,
            goalLabel: nil,
            insight: emptyInsight,
            entryCount: 0,
            dateRange: ""
        )
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
