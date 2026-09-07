//
//  TrendAnalysisEngine.swift
//  WellPattern Health
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
// Analysis runs in two phases:
//   Phase 1 (main actor)  — SwiftData fetches + singleton captures
//   Phase 2 (background)  — pure computation on whatever thread the caller uses
struct TrendAnalysisEngine {

    // MARK: - Main Analysis Method

    /// Generate all trend insights for a given timeframe.
    /// - Parameter timeframe: The analysis period (7, 14, or 30 days)
    /// - Returns: Complete analysis result
    static func analyze(timeframe: Int = 30) async -> TrendAnalysisResult {

        // ── Phase 1: Fetch data on the main actor ────────────────────────────
        // All SwiftData queries and @MainActor singleton reads happen here.
        let fetched = await MainActor.run { () -> FetchedData in
            let service = PersistenceService.shared
            let endDate = Date()
            let startDate = MetricsEngine.shared.rollingWindowStart(days: timeframe)
            let goalService = UserGoalService.shared

            return FetchedData(
                workouts: fetchWorkouts(from: startDate, to: endDate, service: service),
                previousWorkouts: fetchPreviousWorkouts(before: startDate, limit: 20, service: service),
                checkIns: fetchCheckIns(from: startDate, to: endDate, service: service),
                contexts: fetchDailyContexts(from: startDate, to: endDate, service: service),
                recoveries: fetchRecoveries(from: startDate, to: endDate, service: service),
                weightEntries: MetricsEngine.shared.weightEntries(rollingDays: timeframe),
                weeksInTimeframe: MetricsEngine.shared.weeksInPeriod(timeframe),
                showWeightUI: goalService.shouldShowWeightUI,
                showNutrition: goalService.shouldEmphasizeNutrition,
                primaryGoal: goalService.primaryGoal,
                unitSystem: UnitPreferences.shared.unitSystem
            )
        }

        // ── Phase 2: Pure computation (runs on caller's executor) ─────────────
        var insights: [GeneratedInsight] = []

        // 1. Workout frequency analysis
        insights.append(contentsOf: analyzeWorkoutFrequency(
            workouts: fetched.workouts,
            previousWorkouts: fetched.previousWorkouts,
            timeframe: timeframe,
            weeksInTimeframe: fetched.weeksInTimeframe
        ))

        // 2. Workout type distribution
        insights.append(contentsOf: analyzeWorkoutTypeDistribution(
            workouts: fetched.workouts,
            timeframe: timeframe
        ))

        // 3. Harder-than-usual detection
        insights.append(contentsOf: analyzeHarderThanUsual(
            workouts: fetched.workouts,
            checkIns: fetched.checkIns
        ))

        // 4. Soreness patterns after strength
        insights.append(contentsOf: analyzeSorenessPatterns(
            workouts: fetched.workouts,
            recoveries: fetched.recoveries,
            checkIns: fetched.checkIns
        ))

        // 5. Sleep vs workout difficulty
        insights.append(contentsOf: analyzeSleepWorkoutCorrelation(
            workouts: fetched.workouts,
            contexts: fetched.contexts,
            checkIns: fetched.checkIns
        ))

        // 6. Recovery patterns
        insights.append(contentsOf: analyzeRecoveryPatterns(
            workouts: fetched.workouts,
            recoveries: fetched.recoveries
        ))

        // 7. Consistency analysis
        insights.append(contentsOf: analyzeConsistency(
            workouts: fetched.workouts,
            timeframe: timeframe
        ))

        // 8. Weight trend analysis (only for weight_loss goal)
        if fetched.showWeightUI {
            insights.append(contentsOf: analyzeWeightTrend(
                contexts: fetched.contexts,
                timeframe: timeframe,
                unitSystem: fetched.unitSystem
            ))
        }

        // 9. Nutrition/hydration trend analysis (for weight_loss and performance)
        if fetched.showNutrition {
            insights.append(contentsOf: analyzeNutritionTrend(
                contexts: fetched.contexts,
                timeframe: timeframe,
                primaryGoal: fetched.primaryGoal
            ))
        }

        // 10. Hydration trend (all goals)
        insights.append(contentsOf: analyzeHydrationTrend(
            contexts: fetched.contexts,
            timeframe: timeframe
        ))

        let sortedInsights = insights.sorted { $0.priority.rawValue > $1.priority.rawValue }

        let calendarData = generateCalendarData(
            workouts: fetched.workouts,
            checkIns: fetched.checkIns,
            timeframe: timeframe
        )

        let metricTrends = generateMetricTrends(
            workouts: fetched.workouts,
            contexts: fetched.contexts,
            recoveries: fetched.recoveries,
            timeframe: timeframe,
            weightEntries: fetched.weightEntries,
            showWeightUI: fetched.showWeightUI,
            unitSystem: fetched.unitSystem
        )

        return TrendAnalysisResult(
            insights: sortedInsights,
            calendarData: calendarData,
            metricTrends: metricTrends,
            timeframe: timeframe,
            workoutCount: fetched.workouts.count,
            analyzedAt: Date()
        )
    }

    // MARK: - Prefetched data container

    private struct FetchedData: Sendable {
        let workouts: [AnalyzableWorkout]
        let previousWorkouts: [Workout]
        let checkIns: [CheckIn]
        let contexts: [DailyContext]
        let recoveries: [NextDayRecovery]
        let weightEntries: [(date: Date, kg: Double)]
        let weeksInTimeframe: Double
        let showWeightUI: Bool
        let showNutrition: Bool
        let primaryGoal: UserGoal?
        let unitSystem: UnitSystem
    }

    // MARK: - Data Fetching

    @MainActor private static func fetchWorkouts(
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

    @MainActor private static func fetchPreviousWorkouts(
        before date: Date,
        limit: Int,
        service: PersistenceService
    ) -> [Workout] {
        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: date)!
        return Array(service.fetchWorkouts(from: oldDate, to: date).prefix(limit))
    }

    @MainActor private static func fetchCheckIns(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [CheckIn] {
        return service.fetchRecentCheckIns(limit: 50).filter {
            $0.date >= startDate && $0.date <= endDate
        }
    }

    @MainActor private static func fetchDailyContexts(
        from startDate: Date,
        to endDate: Date,
        service: PersistenceService
    ) -> [DailyContext] {
        // Fetch recent daily contexts and filter by date range
        let allContexts = service.fetchRecentDailyContexts(limit: 60)
        return allContexts.filter { context in
            context.date >= startDate && context.date <= endDate
        }
    }

    @MainActor private static func fetchRecoveries(
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
        timeframe: Int,
        weeksInTimeframe: Double
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        let currentCount = workouts.count
        let workoutsPerWeek = Double(currentCount) / weeksInTimeframe

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

        // Average sleep analysis — only include days where sleep was actually logged
        let sleepLogged = contexts.map { $0.sleepHours }.filter { $0 > 0 }
        if !sleepLogged.isEmpty {
            let avgSleep = sleepLogged.reduce(0, +) / Double(sleepLogged.count)

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

    // MARK: - Analysis: Weight Trend (Weight Loss Goal Only)

    private static func analyzeWeightTrend(
        contexts: [DailyContext],
        timeframe: Int,
        unitSystem: UnitSystem
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Get weight entries
        let weightsWithDates = contexts.compactMap { context -> (date: Date, weight: Double)? in
            guard let weight = context.weightKg else { return nil }
            return (context.date, weight)
        }.sorted { $0.date < $1.date }

        guard weightsWithDates.count >= 2 else {
            // Not enough data
            if weightsWithDates.isEmpty {
                insights.append(GeneratedInsight(
                    type: .recommendation,
                    title: "Start tracking weight",
                    description: "Log your weight regularly to see trends toward your goal.",
                    metric: .weight,
                    changePercentage: 0,
                    priority: .medium,
                    icon: "scalemass.fill",
                    color: "navy"
                ))
            }
            return insights
        }

        // Calculate trend
        let firstWeight = weightsWithDates.first!.weight
        let lastWeight = weightsWithDates.last!.weight
        let weightChange = lastWeight - firstWeight
        let percentChange = firstWeight > 0 ? (weightChange / firstWeight) * 100 : 0

        let weightUnit = unitSystem.weightUnit
        let convert: (Double) -> Double = unitSystem == .imperial
            ? { $0 * UnitPreferences.kgToLb }
            : { $0 }
        if weightChange < -0.5 {
            // Losing weight
            let progressText = "Keep it up!"
            let lostDisplay = convert(abs(weightChange))
            insights.append(GeneratedInsight(
                type: .improvement,
                title: "Weight trending down",
                description: String(format: "You've lost %.1f %@ (%.1f%%). %@", lostDisplay, weightUnit, abs(percentChange), progressText),
                metric: .weight,
                changePercentage: percentChange,
                priority: .high,
                icon: "arrow.down.circle.fill",
                color: "olive"
            ))
        } else if weightChange > 0.5 {
            // Gaining weight (not ideal for weight loss goal)
            let gainedDisplay = convert(abs(weightChange))
            insights.append(GeneratedInsight(
                type: .warning,
                title: "Weight trending up",
                description: String(format: "You've gained %.1f %@. Review nutrition and activity.", gainedDisplay, weightUnit),
                metric: .weight,
                changePercentage: percentChange,
                priority: .high,
                icon: "arrow.up.circle.fill",
                color: "coral"
            ))
        } else {
            // Stable
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Weight is stable",
                description: String(format: "Holding steady at %.1f %@. Adjust intake for change.", convert(lastWeight), weightUnit),
                metric: .weight,
                changePercentage: percentChange,
                priority: .medium,
                icon: "equal.circle.fill",
                color: "navy"
            ))
        }

        return insights
    }

    // MARK: - Analysis: Nutrition Trend

    private static func analyzeNutritionTrend(
        contexts: [DailyContext],
        timeframe: Int,
        primaryGoal: UserGoal?
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Analyze calories
        let calorieEntries = contexts.compactMap { $0.calories }
        if calorieEntries.count >= 3 {
            let avgCalories = Double(calorieEntries.reduce(0, +)) / Double(calorieEntries.count)

            if avgCalories < 1500 {
                insights.append(GeneratedInsight(
                    type: .warning,
                    title: "Low calorie intake",
                    description: String(format: "Averaging %.0f kcal/day. Ensure adequate nutrition.", avgCalories),
                    metric: .nutrition,
                    changePercentage: 0,
                    priority: .high,
                    icon: "fork.knife",
                    color: "coral"
                ))
            } else if avgCalories > 2800 {
                insights.append(GeneratedInsight(
                    type: .pattern,
                    title: "High calorie intake",
                    description: String(format: "Averaging %.0f kcal/day. Good for muscle gain or high activity.", avgCalories),
                    metric: .nutrition,
                    changePercentage: 0,
                    priority: .low,
                    icon: "fork.knife",
                    color: "navy"
                ))
            }
        }

        // Analyze protein
        let proteinEntries = contexts.compactMap { $0.proteinGrams }
        if proteinEntries.count >= 3 {
            let avgProtein = Double(proteinEntries.reduce(0, +)) / Double(proteinEntries.count)

            if primaryGoal == .performance && avgProtein < 120 {
                insights.append(GeneratedInsight(
                    type: .recommendation,
                    title: "Protein could be higher",
                    description: String(format: "Averaging %.0fg protein. Aim for 1.6-2.2g per kg bodyweight for performance.", avgProtein),
                    metric: .nutrition,
                    changePercentage: 0,
                    priority: .medium,
                    icon: "bolt.fill",
                    color: "navy"
                ))
            } else if avgProtein >= 120 {
                insights.append(GeneratedInsight(
                    type: .pattern,
                    title: "Good protein intake",
                    description: String(format: "Averaging %.0fg protein daily — supports recovery and muscle.", avgProtein),
                    metric: .nutrition,
                    changePercentage: 0,
                    priority: .low,
                    icon: "checkmark.circle.fill",
                    color: "olive"
                ))
            }
        }

        return insights
    }

    // MARK: - Analysis: Hydration Trend

    private static func analyzeHydrationTrend(
        contexts: [DailyContext],
        timeframe: Int
    ) -> [GeneratedInsight] {
        var insights: [GeneratedInsight] = []

        // Get water intake entries
        let waterEntries = contexts.compactMap { $0.waterIntakeMl }

        guard waterEntries.count >= 3 else {
            if waterEntries.isEmpty {
                insights.append(GeneratedInsight(
                    type: .recommendation,
                    title: "Track your water intake",
                    description: "Hydration affects performance and recovery. Start logging water.",
                    metric: .hydration,
                    changePercentage: 0,
                    priority: .low,
                    icon: "drop.fill",
                    color: "blue"
                ))
            }
            return insights
        }

        let avgWaterMl = Double(waterEntries.reduce(0, +)) / Double(waterEntries.count)
        let avgWaterL = avgWaterMl / 1000.0

        if avgWaterL < 1.5 {
            insights.append(GeneratedInsight(
                type: .warning,
                title: "Hydration needs attention",
                description: String(format: "Averaging %.1fL water/day. Aim for 2-3L for optimal performance.", avgWaterL),
                metric: .hydration,
                changePercentage: 0,
                priority: .medium,
                icon: "drop.fill",
                color: "coral"
            ))
        } else if avgWaterL >= 2.5 {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Excellent hydration",
                description: String(format: "Averaging %.1fL water/day — great for recovery.", avgWaterL),
                metric: .hydration,
                changePercentage: 0,
                priority: .low,
                icon: "drop.fill",
                color: "olive"
            ))
        } else {
            insights.append(GeneratedInsight(
                type: .pattern,
                title: "Good hydration",
                description: String(format: "Averaging %.1fL water/day. On track.", avgWaterL),
                metric: .hydration,
                changePercentage: 0,
                priority: .low,
                icon: "drop.fill",
                color: "blue"
            ))
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
        timeframe: Int,
        weightEntries: [(date: Date, kg: Double)],
        showWeightUI: Bool,
        unitSystem: UnitSystem
    ) -> [MetricTrend] {
        var trends: [MetricTrend] = []

        // HRV Trend — uses real historical values sorted by date
        let hrvEntries = contexts.compactMap { ctx -> (date: Date, hrv: Double)? in
            guard let hrv = ctx.hrvScore, hrv > 0 else { return nil }
            return (ctx.date, hrv)
        }.sorted { $0.date < $1.date }

        if let latestHrv = hrvEntries.last?.hrv {
            let hrvValues = hrvEntries.map { $0.hrv }
            let changeText: String
            if hrvValues.count >= 2 {
                let diff = latestHrv - hrvValues.first!
                changeText = String(format: "%@%.0f ms", diff >= 0 ? "+" : "", diff)
            } else {
                changeText = "1 entry"
            }
            let maxHrv = hrvValues.max() ?? 100
            let hrvDataPoints = hrvValues.map { CGFloat($0 / maxHrv) }
            trends.append(MetricTrend(
                title: "HRV Trend",
                currentValue: "\(Int(latestHrv))ms",
                change: changeText,
                isPositive: true,
                dataPoints: hrvDataPoints,
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

            // Chart points are real per-workout intensity values in chronological order
            let sortedWorkouts = workouts.sorted { $0.workout.startDate < $1.workout.startDate }
            let intensityPoints = sortedWorkouts.map { w -> CGFloat in
                switch w.workout.intensity {
                case .low: return 0.25
                case .moderate: return 0.5
                case .high: return 0.75
                case .max: return 1.0
                }
            }
            trends.append(MetricTrend(
                title: "Avg Intensity",
                currentValue: intensityLabel,
                change: "\(workouts.count) sessions",
                isPositive: true,
                dataPoints: intensityPoints,
                color: "navy"
            ))
        }

        // Recovery Score — single real data point (today's recovery)
        if let recovery = recoveries.first {
            let scoreLabel: String
            switch recovery.overallScore {
            case 85...: scoreLabel = "Excellent"
            case 70..<85: scoreLabel = "Good"
            case 55..<70: scoreLabel = "Fair"
            default: scoreLabel = "Low"
            }
            trends.append(MetricTrend(
                title: "Recovery Score",
                currentValue: "\(recovery.overallScore)",
                change: scoreLabel,
                isPositive: recovery.overallScore >= 70,
                dataPoints: [CGFloat(Double(recovery.overallScore) / 100)],
                color: recovery.overallScore >= 70 ? "olive" : "coral"
            ))
        }

        // Weight Trend (only for weight_loss goal)
        // Uses pre-fetched weightEntries sorted by DATE ascending — never by value
        if showWeightUI {
            if let latestEntry = weightEntries.last {
                let latestKg = latestEntry.kg
                let changeText: String
                let isPositive: Bool
                let wUnit = unitSystem.weightUnit
                let convert: (Double) -> Double = unitSystem == .imperial
                    ? { $0 * UnitPreferences.kgToLb }
                    : { $0 }
                if weightEntries.count >= 2 {
                    let firstKg = weightEntries.first!.kg
                    let diff = latestKg - firstKg
                    let diffDisplay = convert(abs(diff))
                    changeText = String(format: "%@%.1f %@", diff >= 0 ? "+" : "-", diffDisplay, wUnit)
                    isPositive = diff < 0 // For weight loss, losing is positive
                } else {
                    changeText = "1 entry"
                    isPositive = true
                }

                let weightValues = weightEntries.map { $0.kg }
                let latestDisplay = convert(latestKg)
                trends.append(MetricTrend(
                    title: "Weight",
                    currentValue: String(format: "%.1f %@", latestDisplay, wUnit),
                    change: changeText,
                    isPositive: isPositive,
                    dataPoints: generateWeightTrendData(weights: weightValues),
                    color: isPositive ? "olive" : "coral"
                ))
            }
        }

        // Sleep Trend — avg of days with logged sleep only, sorted by date
        let sleepEntries = contexts.compactMap { ctx -> (date: Date, hours: Double)? in
            guard ctx.sleepHours > 0 else { return nil }
            return (ctx.date, ctx.sleepHours)
        }.sorted { $0.date < $1.date }

        if !sleepEntries.isEmpty {
            let sleepHours = sleepEntries.map { $0.hours }
            let avgSleep = sleepHours.reduce(0, +) / Double(sleepHours.count)
            let changeText: String
            if sleepHours.count >= 2 {
                let diff = sleepHours.last! - sleepHours.first!
                changeText = String(format: "%@%.1f h", diff >= 0 ? "+" : "", diff)
            } else {
                changeText = "\(sleepHours.count) entr\(sleepHours.count == 1 ? "y" : "ies")"
            }
            let maxH = sleepHours.max() ?? 8
            let dataPoints = sleepHours.map { CGFloat($0 / max(maxH, 1)) }
            trends.append(MetricTrend(
                title: "Sleep",
                currentValue: String(format: "%.1f hrs", avgSleep),
                change: changeText,
                isPositive: avgSleep >= 7.0,
                dataPoints: dataPoints,
                color: "olive"
            ))
        }

        // Hydration Trend
        let waterEntries = contexts.compactMap { $0.waterIntakeMl }
        if !waterEntries.isEmpty {
            let avgWater = Double(waterEntries.reduce(0, +)) / Double(waterEntries.count)
            let avgLiters = avgWater / 1000.0
            let isGood = avgLiters >= 2.0
            let hydrationDisplay: String = {
                if unitSystem == .imperial {
                    return String(format: "%.0f oz", avgLiters * UnitPreferences.litersToOz)
                } else {
                    return String(format: "%.1f L", avgLiters)
                }
            }()

            trends.append(MetricTrend(
                title: "Hydration",
                currentValue: hydrationDisplay,
                change: isGood ? "On target" : "Below target",
                isPositive: isGood,
                dataPoints: generateTrendData(baseValue: min(avgLiters / 3.0, 1.0), variance: 0.1),
                color: isGood ? "blue" : "coral"
            ))
        }

        return trends
    }

    private static func generateWeightTrendData(weights: [Double]) -> [CGFloat] {
        guard weights.count >= 2 else { return [] }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100
        let range = maxWeight - minWeight
        guard range > 0 else {
            return weights.map { _ in CGFloat(0.5) }
        }
        return weights.map { CGFloat(($0 - minWeight) / range) }
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
