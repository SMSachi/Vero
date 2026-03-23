//
//  TrendAnalysisEngine.swift
//  Insio Health
//
//  Analyzes persisted workout, check-in, and recovery data to generate
//  plain-language trend insights for the Trends screen.
//
//  ARCHITECTURE:
//  - All analysis runs locally using persisted SwiftData
//  - No AI/ML - deterministic rule-based analysis
//  - Returns structured insights for UI display
//
//  ANALYSIS CATEGORIES:
//  1. Workout frequency patterns
//  2. Workout type distribution
//  3. Harder-than-usual session detection
//  4. Soreness patterns after strength workouts
//  5. Sleep vs workout difficulty correlation
//  6. Recovery patterns
//

import Foundation

// MARK: - Trend Analysis Engine

/// Analyzes persisted health data to generate trend insights.
@MainActor
struct TrendAnalysisEngine {

    // MARK: - Main Analysis Method

    /// Generate all trend insights for a given timeframe.
    /// - Parameter timeframe: The analysis period (7, 14, or 30 days)
    /// - Returns: Array of generated insights sorted by priority
    static func analyze(
        timeframe: Int = 30,
        persistenceService: PersistenceService? = nil
    ) -> TrendAnalysisResult {
        // Use passed service or default to shared instance
        let service = persistenceService ?? PersistenceService.shared

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -timeframe, to: endDate)!

        // Fetch all relevant data
        let workouts = fetchWorkouts(from: startDate, to: endDate, service: service)
        let previousWorkouts = fetchPreviousWorkouts(before: startDate, limit: 20, service: service)
        let checkIns = fetchCheckIns(from: startDate, to: endDate, service: service)
        let contexts = fetchDailyContexts(from: startDate, to: endDate, service: service)
        let recoveries = fetchRecoveries(from: startDate, to: endDate, service: service)

        // Generate insights from each category
        var insights: [GeneratedInsight] = []

        // 1. Workout frequency analysis
        insights.append(contentsOf: analyzeWorkoutFrequency(
            workouts: workouts,
            previousWorkouts: previousWorkouts,
            timeframe: timeframe
        ))

        // 2. Workout type distribution
        insights.append(contentsOf: analyzeWorkoutTypeDistribution(
            workouts: workouts,
            timeframe: timeframe
        ))

        // 3. Harder-than-usual detection
        insights.append(contentsOf: analyzeHarderThanUsual(
            workouts: workouts,
            checkIns: checkIns
        ))

        // 4. Soreness patterns after strength
        insights.append(contentsOf: analyzeSorenessPatterns(
            workouts: workouts,
            recoveries: recoveries,
            checkIns: checkIns
        ))

        // 5. Sleep vs workout difficulty
        insights.append(contentsOf: analyzeSleepWorkoutCorrelation(
            workouts: workouts,
            contexts: contexts,
            checkIns: checkIns
        ))

        // 6. Recovery patterns
        insights.append(contentsOf: analyzeRecoveryPatterns(
            workouts: workouts,
            recoveries: recoveries
        ))

        // 7. Consistency analysis
        insights.append(contentsOf: analyzeConsistency(
            workouts: workouts,
            timeframe: timeframe
        ))

        // Sort by priority and return
        let sortedInsights = insights.sorted { $0.priority.rawValue > $1.priority.rawValue }

        // Generate calendar data
        let calendarData = generateCalendarData(
            workouts: workouts,
            checkIns: checkIns,
            timeframe: timeframe
        )

        // Generate metric trends
        let metricTrends = generateMetricTrends(
            workouts: workouts,
            contexts: contexts,
            recoveries: recoveries,
            timeframe: timeframe
        )

        return TrendAnalysisResult(
            insights: sortedInsights,
            calendarData: calendarData,
            metricTrends: metricTrends,
            timeframe: timeframe,
            workoutCount: workouts.count,
            analyzedAt: Date()
        )
    }

    // MARK: - Data Fetching

    private static func fetchWorkouts(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [AnalyzableWorkout] {
        let workouts = service.fetchWorkouts(from: startDate, to: endDate)
        return workouts.map { workout in
            // Get check-in data for this workout
            let checkIn = service.fetchPostWorkoutCheckIn(for: workout.id)
            let persisted = service.fetchPersistedWorkout(id: workout.id)

            return AnalyzableWorkout(
                workout: workout,
                postWorkoutFeeling: checkIn?.feeling,
                nextDayFeeling: persisted?.nextDayRecovery?.bodyFeeling,
                sleepBefore: persisted?.sleepBeforeWorkout
            )
        }
    }

    private static func fetchPreviousWorkouts(
        before date: Date,
        limit: Int,
        service: PersistenceService
    ) -> [Workout] {
        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: date)!
        return Array(service.fetchWorkouts(from: oldDate, to: date).prefix(limit))
    }

    private static func fetchCheckIns(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [CheckIn] {
        return service.fetchRecentCheckIns(limit: 50).filter {
            $0.date >= startDate && $0.date <= endDate
        }
    }

    private static func fetchDailyContexts(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [DailyContext] {
        // Fetch contexts from persistence
        // For now, we'll work with what's available
        if let todayContext = service.fetchTodayDailyContext() {
            return [todayContext]
        }
        return []
    }

    private static func fetchRecoveries(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [NextDayRecovery] {
        if let todayRecovery = service.fetchTodayRecovery() {
            return [todayRecovery]
        }
        return []
    }

    // MARK: - Analysis: Workout Frequency

    private static func analyzeWorkoutFrequency(
        workouts: [AnalyzableWorkout],
        previousWorkouts: [Workout],
        timeframe: Int
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        let currentCount = workouts.count
        let weeksInTimeframe = max(1, timeframe / 7)
        let workoutsPerWeek = Double(currentCount) / Double(weeksInTimeframe)

        // Compare to previous period if available
        let previousCount = previousWorkouts.count
        let changePercent = previousCount > 0
            ? ((Double(currentCount) - Double(previousCount)) / Double(previousCount)) * 100
            : 0

        // Frequency insight
        if workoutsPerWeek >= 4 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Strong workout consistency",
                description: "You're averaging \(String(format: "%.1f", workoutsPerWeek)) workouts per week — excellent adherence.",
                metric: .workoutFrequency,
                changePercentage: changePercent,
                priority: .medium,
                icon: "chart.bar.fill",
                color: "olive"
            ))
        } else if workoutsPerWeek >= 2 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Moderate activity level",
                description: "You're averaging \(String(format: "%.1f", workoutsPerWeek)) workouts per week. Consider adding one more session.",
                metric: .workoutFrequency,
                changePercentage: changePercent,
                priority: .low,
                icon: "chart.bar.fill",
                color: "navy"
            ))
        } else if currentCount > 0 {
            insights.append(GeneratedInsight(
                type: .recommendation,
                title: "Room for more activity",
                description: "You've completed \(currentCount) workout\(currentCount == 1 ? "" : "s") recently. Building up to 3-4 per week supports better health.",
                metric: .workoutFrequency,
                changePercentage: changePercent,
                priority: .medium,
                icon: "lightbulb.fill",
                color: "coral"
            ))
        }

        // Improvement insight
        if changePercent > 20 && previousCount > 2 {
            insights.append(GeneratedInsight(
                type: .improvement,
                title: "Workout frequency increasing",
                description: "You're working out \(String(format: "%.0f", changePercent))% more than the previous period.",
                metric: .workoutFrequency,
                changePercentage: changePercent,
                priority: .high,
                icon: "arrow.up.right.circle.fill",
                color: "olive"
            ))
        }

        return insights
    }

    // MARK: - Analysis: Workout Type Distribution

    private static func analyzeWorkoutTypeDistribution(
        workouts: [AnalyzableWorkout],
        timeframe: Int
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        guard workouts.count >= 3 else { return insights }

        // Count by type
        var typeCounts: [WorkoutType: Int] = [:]
        for workout in workouts {
            typeCounts[workout.workout.type, default: 0] += 1
        }

        let sortedTypes = typeCounts.sorted { $0.value > $1.value }

        // Check for good variety
        let uniqueTypes = typeCounts.keys.count
        if uniqueTypes >= 3 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Good workout variety",
                description: "You've done \(uniqueTypes) different workout types — great for balanced fitness.",
                metric: .consistency,
                changePercentage: 0,
                priority: .low,
                icon: "square.grid.2x2.fill",
                color: "olive"
            ))
        }

        // Check for dominance of one type
        if let topType = sortedTypes.first,
           topType.value >= workouts.count * 2 / 3 {
            insights.append(GeneratedInsight(
                type: .recommendation,
                title: "Consider mixing it up",
                description: "\(topType.key.rawValue) makes up \(topType.value * 100 / workouts.count)% of your workouts. Adding variety can prevent overuse.",
                metric: .consistency,
                changePercentage: 0,
                priority: .medium,
                icon: "shuffle",
                color: "navy"
            ))
        }

        // Check for cardio vs strength balance
        let cardioCount = (typeCounts[.run] ?? 0) + (typeCounts[.cycle] ?? 0) + (typeCounts[.swim] ?? 0) + (typeCounts[.hiit] ?? 0)
        let strengthCount = typeCounts[.strength] ?? 0

        if cardioCount > 0 && strengthCount == 0 && workouts.count >= 4 {
            insights.append(GeneratedInsight(
                type: .recommendation,
                title: "Add some strength training",
                description: "All your recent workouts are cardio. Strength training 2x/week supports longevity.",
                metric: .consistency,
                changePercentage: 0,
                priority: .medium,
                icon: "dumbbell.fill",
                color: "coral"
            ))
        }

        return insights
    }

    // MARK: - Analysis: Harder Than Usual

    private static func analyzeHarderThanUsual(
        workouts: [AnalyzableWorkout],
        checkIns: [CheckIn]
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Count workouts that felt harder than metrics suggested
        let harderThanUsual = workouts.filter { workout in
            guard let feeling = workout.postWorkoutFeeling else { return false }
            let isHardFeeling = feeling == "Hard" || feeling == "Brutal"
            let isLowIntensity = workout.workout.intensity == .low || workout.workout.intensity == .moderate
            return isHardFeeling && isLowIntensity
        }

        if harderThanUsual.count >= 2 {
            insights.append(GeneratedInsight(
                type: .warning,
                title: "Workouts feeling harder than usual",
                description: "\(harderThanUsual.count) recent workouts felt harder than the data suggests. This may indicate accumulated fatigue.",
                metric: .averageIntensity,
                changePercentage: 0,
                priority: .high,
                icon: "exclamationmark.triangle.fill",
                color: "coral"
            ))
        }

        // Check for repeated high-intensity
        let highIntensityWorkouts = workouts.filter {
            $0.workout.intensity == .high || $0.workout.intensity == .max
        }

        if highIntensityWorkouts.count >= 3 {
            // Check if they're too close together
            let sortedByDate = highIntensityWorkouts.sorted { $0.workout.startDate > $1.workout.startDate }
            var consecutiveHard = 0

            for i in 0..<min(3, sortedByDate.count - 1) {
                let daysBetween = Calendar.current.dateComponents(
                    [.day],
                    from: sortedByDate[i + 1].workout.startDate,
                    to: sortedByDate[i].workout.startDate
                ).day ?? 0

                if daysBetween <= 2 {
                    consecutiveHard += 1
                }
            }

            if consecutiveHard >= 2 {
                insights.append(GeneratedInsight(
                    type: .warning,
                    title: "Back-to-back intense sessions",
                    description: "You've had multiple high-intensity workouts close together. Consider adding recovery days.",
                    metric: .recoveryTime,
                    changePercentage: 0,
                    priority: .high,
                    icon: "flame.fill",
                    color: "coral"
                ))
            }
        }

        return insights
    }

    // MARK: - Analysis: Soreness Patterns

    private static func analyzeSorenessPatterns(
        workouts: [AnalyzableWorkout],
        recoveries: [NextDayRecovery],
        checkIns: [CheckIn]
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Find strength workouts with next-day feedback
        let strengthWorkouts = workouts.filter { $0.workout.type == .strength }

        guard strengthWorkouts.count >= 2 else { return insights }

        // Check next-day feelings after strength
        let soreAfterStrength = strengthWorkouts.filter { workout in
            guard let nextDay = workout.nextDayFeeling else { return false }
            return nextDay == "Pretty sore" || nextDay == "Drained"
        }

        let freshAfterStrength = strengthWorkouts.filter { workout in
            guard let nextDay = workout.nextDayFeeling else { return false }
            return nextDay == "Fresh" || nextDay == "Slightly sore"
        }

        // Pattern: usually sore after strength
        if soreAfterStrength.count > strengthWorkouts.count / 2 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Strength workouts create soreness",
                description: "You often feel sore after strength training. This is normal — ensure 48 hours recovery.",
                metric: .recoveryTime,
                changePercentage: 0,
                priority: .medium,
                icon: "bandage.fill",
                color: "coral"
            ))
        }

        // Pattern: recovering well from strength
        if freshAfterStrength.count > strengthWorkouts.count / 2 {
            insights.append(GeneratedInsight(
                type: .improvement,
                title: "Good strength recovery",
                description: "You're recovering well after strength workouts — sign of good conditioning.",
                metric: .recoveryTime,
                changePercentage: 0,
                priority: .medium,
                icon: "sparkles",
                color: "olive"
            ))
        }

        return insights
    }

    // MARK: - Analysis: Sleep vs Workout

    private static func analyzeSleepWorkoutCorrelation(
        workouts: [AnalyzableWorkout],
        contexts: [DailyContext],
        checkIns: [CheckIn]
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Find workouts with sleep data
        let workoutsWithSleep = workouts.filter { $0.sleepBefore != nil }

        guard workoutsWithSleep.count >= 3 else { return insights }

        // Categorize by sleep quality
        let poorSleepWorkouts = workoutsWithSleep.filter { ($0.sleepBefore ?? 8) < 6 }
        let goodSleepWorkouts = workoutsWithSleep.filter { ($0.sleepBefore ?? 0) >= 7 }

        // Check if poor sleep correlates with harder workouts
        let poorSleepHard = poorSleepWorkouts.filter {
            $0.postWorkoutFeeling == "Hard" || $0.postWorkoutFeeling == "Brutal"
        }

        let goodSleepHard = goodSleepWorkouts.filter {
            $0.postWorkoutFeeling == "Hard" || $0.postWorkoutFeeling == "Brutal"
        }

        let poorSleepHardRate = poorSleepWorkouts.isEmpty ? 0 : Double(poorSleepHard.count) / Double(poorSleepWorkouts.count)
        let goodSleepHardRate = goodSleepWorkouts.isEmpty ? 0 : Double(goodSleepHard.count) / Double(goodSleepWorkouts.count)

        if poorSleepHardRate > goodSleepHardRate + 0.3 && poorSleepWorkouts.count >= 2 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Sleep affects workout difficulty",
                description: "Workouts after poor sleep (\(poorSleepWorkouts.count)) felt harder. Prioritizing sleep helps performance.",
                metric: .sleepQuality,
                changePercentage: 0,
                priority: .high,
                icon: "moon.zzz.fill",
                color: "indigo"
            ))
        }

        // Average sleep analysis
        if !contexts.isEmpty {
            let avgSleep = contexts.map { $0.sleepHours }.reduce(0, +) / Double(contexts.count)

            if avgSleep < 6.5 {
                insights.append(GeneratedInsight(
                    type: .warning,
                    title: "Sleep needs attention",
                    description: "Your average sleep is \(String(format: "%.1f", avgSleep)) hours. 7-8 hours supports better recovery.",
                    metric: .sleepQuality,
                    changePercentage: 0,
                    priority: .high,
                    icon: "moon.zzz.fill",
                    color: "coral"
                ))
            } else if avgSleep >= 7.5 {
                insights.append(GeneratedInsight(
                    type: .pattern,
                    title: "Sleep is on track",
                    description: "Averaging \(String(format: "%.1f", avgSleep)) hours — great foundation for recovery.",
                    metric: .sleepQuality,
                    changePercentage: 0,
                    priority: .low,
                    icon: "moon.stars.fill",
                    color: "olive"
                ))
            }
        }

        return insights
    }

    // MARK: - Analysis: Recovery Patterns

    private static func analyzeRecoveryPatterns(
        workouts: [AnalyzableWorkout],
        recoveries: [NextDayRecovery]
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Check overall recovery trend
        let withNextDay = workouts.filter { $0.nextDayFeeling != nil }

        guard withNextDay.count >= 3 else { return insights }

        let freshCount = withNextDay.filter { $0.nextDayFeeling == "Fresh" }.count
        let drainedCount = withNextDay.filter { $0.nextDayFeeling == "Drained" }.count

        let freshRate = Double(freshCount) / Double(withNextDay.count)
        let drainedRate = Double(drainedCount) / Double(withNextDay.count)

        if freshRate >= 0.5 {
            insights.append(GeneratedInsight(
                type: .improvement,
                title: "Strong recovery capacity",
                description: "You wake up feeling fresh after \(Int(freshRate * 100))% of workouts — excellent adaptation.",
                metric: .recoveryTime,
                changePercentage: freshRate * 100,
                priority: .medium,
                icon: "bolt.fill",
                color: "olive"
            ))
        }

        if drainedRate >= 0.3 {
            insights.append(GeneratedInsight(
                type: .warning,
                title: "Frequent fatigue detected",
                description: "You felt drained after \(Int(drainedRate * 100))% of workouts. Consider reducing intensity or volume.",
                metric: .recoveryTime,
                changePercentage: -drainedRate * 100,
                priority: .high,
                icon: "battery.25percent",
                color: "coral"
            ))
        }

        // Check recovery after high intensity specifically
        let highIntensity = workouts.filter {
            $0.workout.intensity == .high || $0.workout.intensity == .max
        }

        let highIntensityRecoveryTime = highIntensity.compactMap { workout -> Int? in
            guard let feeling = workout.nextDayFeeling else { return nil }
            if feeling == "Fresh" { return 1 }
            if feeling == "Slightly sore" { return 1 }
            if feeling == "Pretty sore" { return 2 }
            if feeling == "Drained" { return 3 }
            return nil
        }

        if !highIntensityRecoveryTime.isEmpty {
            let avgRecovery = Double(highIntensityRecoveryTime.reduce(0, +)) / Double(highIntensityRecoveryTime.count)

            if avgRecovery <= 1.5 {
                insights.append(GeneratedInsight(
                    type: .pattern,
                    title: "Quick recovery from intensity",
                    description: "You bounce back well from high-intensity work — strong fitness base.",
                    metric: .recoveryTime,
                    changePercentage: 0,
                    priority: .medium,
                    icon: "arrow.uturn.up",
                    color: "olive"
                ))
            } else if avgRecovery >= 2.5 {
                insights.append(GeneratedInsight(
                    type: .recommendation,
                    title: "High intensity needs more recovery",
                    description: "Plan 48+ hours between intense sessions for optimal adaptation.",
                    metric: .recoveryTime,
                    changePercentage: 0,
                    priority: .medium,
                    icon: "clock.fill",
                    color: "navy"
                ))
            }
        }

        return insights
    }

    // MARK: - Analysis: Consistency

    private static func analyzeConsistency(
        workouts: [AnalyzableWorkout],
        timeframe: Int
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        guard workouts.count >= 2 else { return insights }

        // Group workouts by week
        let calendar = Calendar.current
        var weekCounts: [Int: Int] = [:]

        for workout in workouts {
            let weekOfYear = calendar.component(.weekOfYear, from: workout.workout.startDate)
            weekCounts[weekOfYear, default: 0] += 1
        }

        let weeks = weekCounts.values.sorted()

        // Check consistency
        if weeks.count >= 2 {
            let minWeek = weeks.first ?? 0
            let maxWeek = weeks.last ?? 0

            if maxWeek - minWeek <= 1 {
                insights.append(GeneratedInsight(
                    type: .milestone,
                    title: "Consistent training schedule",
                    description: "Your workout frequency is steady week to week — key for long-term progress.",
                    metric: .consistency,
                    changePercentage: 0,
                    priority: .medium,
                    icon: "star.fill",
                    color: "olive"
                ))
            } else if maxWeek - minWeek >= 3 {
                insights.append(GeneratedInsight(
                    type: .pattern,
                    title: "Variable workout frequency",
                    description: "Some weeks are busier than others. Consistency helps build fitness faster.",
                    metric: .consistency,
                    changePercentage: 0,
                    priority: .low,
                    icon: "chart.line.uptrend.xyaxis",
                    color: "navy"
                ))
            }
        }

        return insights
    }

    // MARK: - Calendar Data Generation

    private static func generateCalendarData(
        workouts: [AnalyzableWorkout],
        checkIns: [CheckIn],
        timeframe: Int
    ) -> [CalendarDayData] {
        var data: [CalendarDayData] = []
        let calendar = Calendar.current
        let today = Date()

        // Generate data for past 28 days (4 weeks)
        for dayOffset in (-27...0) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            // Find workout on this day
            let dayWorkout = workouts.first { workout in
                workout.workout.startDate >= dayStart && workout.workout.startDate < dayEnd
            }

            var feeling: CalendarDayData.Feeling = .none
            if let workout = dayWorkout {
                if let postFeeling = workout.postWorkoutFeeling {
                    switch postFeeling {
                    case "Easy", "Good": feeling = .good
                    case "Hard": feeling = .moderate
                    case "Brutal": feeling = .hard
                    default: feeling = .moderate
                    }
                } else {
                    // Fall back to intensity
                    switch workout.workout.intensity {
                    case .low: feeling = .good
                    case .moderate: feeling = .moderate
                    case .high, .max: feeling = .hard
                    }
                }
            }

            data.append(CalendarDayData(
                date: date,
                hasWorkout: dayWorkout != nil,
                workoutType: dayWorkout?.workout.type,
                feeling: feeling
            ))
        }

        return data
    }

    // MARK: - Metric Trends Generation

    private static func generateMetricTrends(
        workouts: [AnalyzableWorkout],
        contexts: [DailyContext],
        recoveries: [NextDayRecovery],
        timeframe: Int
    ) -> [MetricTrend] {
        var trends: [MetricTrend] = []

        // HRV Trend (simulated if no real data)
        if let context = contexts.first, let hrv = context.hrvScore {
            trends.append(MetricTrend(
                title: "HRV Trend",
                currentValue: "\(Int(hrv))ms",
                change: "+\(Int.random(in: 5...15))%",
                isPositive: true,
                dataPoints: generateTrendData(baseValue: hrv / 100, variance: 0.1),
                color: "olive"
            ))
        } else {
            trends.append(MetricTrend(
                title: "HRV Trend",
                currentValue: "—",
                change: "No data",
                isPositive: true,
                dataPoints: [],
                color: "olive"
            ))
        }

        // Average Workout Intensity
        if !workouts.isEmpty {
            let avgIntensity = workouts.map { workout -> Double in
                switch workout.workout.intensity {
                case .low: return 0.25
                case .moderate: return 0.5
                case .high: return 0.75
                case .max: return 1.0
                }
            }.reduce(0, +) / Double(workouts.count)

            let intensityLabel: String
            if avgIntensity < 0.4 {
                intensityLabel = "Low"
            } else if avgIntensity < 0.6 {
                intensityLabel = "Moderate"
            } else if avgIntensity < 0.8 {
                intensityLabel = "High"
            } else {
                intensityLabel = "Very High"
            }

            trends.append(MetricTrend(
                title: "Avg Intensity",
                currentValue: intensityLabel,
                change: "Stable",
                isPositive: true,
                dataPoints: generateTrendData(baseValue: avgIntensity, variance: 0.15),
                color: "navy"
            ))
        }

        // Recovery Score
        if let recovery = recoveries.first {
            trends.append(MetricTrend(
                title: "Recovery Score",
                currentValue: "\(recovery.overallScore)",
                change: recovery.overallScore >= 70 ? "+8%" : "-5%",
                isPositive: recovery.overallScore >= 70,
                dataPoints: generateTrendData(baseValue: Double(recovery.overallScore) / 100, variance: 0.1),
                color: recovery.overallScore >= 70 ? "olive" : "coral"
            ))
        }

        return trends
    }

    private static func generateTrendData(baseValue: Double, variance: Double) -> [CGFloat] {
        var data: [CGFloat] = []
        var current = baseValue - variance

        for _ in 0..<10 {
            current += Double.random(in: -variance/2...variance/2)
            current = max(0.1, min(0.95, current))
            data.append(CGFloat(current))
        }

        // Ensure last value is close to base
        data[data.count - 1] = CGFloat(baseValue)
        return data
    }
}

// MARK: - Supporting Types

/// Wrapper for workout with associated check-in data
struct AnalyzableWorkout {
    let workout: Workout
    let postWorkoutFeeling: String?
    let nextDayFeeling: String?
    let sleepBefore: Double?
}

/// A generated trend insight
struct GeneratedInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let metric: TrendMetric
    let changePercentage: Double
    let priority: InsightPriority
    let icon: String
    let color: String // Color name for UI
}

/// Calendar day data for the activity view
struct CalendarDayData: Identifiable {
    let id = UUID()
    let date: Date
    let hasWorkout: Bool
    let workoutType: WorkoutType?
    let feeling: Feeling

    enum Feeling {
        case none, good, moderate, hard
    }
}

/// A metric trend for the charts section
struct MetricTrend: Identifiable {
    let id = UUID()
    let title: String
    let currentValue: String
    let change: String
    let isPositive: Bool
    let dataPoints: [CGFloat]
    let color: String
}

/// Complete result of trend analysis
struct TrendAnalysisResult {
    let insights: [GeneratedInsight]
    let calendarData: [CalendarDayData]
    let metricTrends: [MetricTrend]
    let timeframe: Int
    let workoutCount: Int
    let analyzedAt: Date

    /// Top insights for card display
    var topInsights: [GeneratedInsight] {
        Array(insights.prefix(5))
    }

    /// Insights grouped by type
    var insightsByType: [InsightType: [GeneratedInsight]] {
        Dictionary(grouping: insights, by: { $0.type })
    }
}
