//
//  MockData.swift
//  Insio Health
//

import Foundation

struct MockData {
    // MARK: - Detailed Workout (for summary view)
    static let detailedWorkout = Workout(
        id: UUID(),
        type: .run,
        startDate: Date().addingTimeInterval(-3600),
        endDate: Date(),
        duration: 2520,
        calories: 380,
        averageHeartRate: 145,
        maxHeartRate: 172,
        intensity: .moderate,
        interpretation: "Solid aerobic session. Your pace was consistent and heart rate stayed in zone 3. Great for building endurance.",
        recoveryHeartRate: 98,
        distance: 5.2,
        elevationGain: 45,
        whatHappened: "You completed a 42-minute run covering 5.2 km at a steady pace. Your heart rate averaged 145 bpm, staying primarily in zone 3 (aerobic). You maintained consistent effort throughout with minimal pace variation.",
        whatItMeans: "This was an effective aerobic base-building session. Your body spent most of the time in the fat-burning zone, which improves endurance without excessive stress. Your quick heart rate recovery (down to 98 bpm within 2 minutes) suggests good cardiovascular fitness.",
        whatToDoNext: "Tomorrow would be a good day for either active recovery (light walk or yoga) or strength training. If you run again, consider keeping the intensity similar or slightly lower. Your next high-intensity session should wait 48-72 hours.",
        sleepBeforeWorkout: 7.5,
        hydrationLevel: .good,
        nutritionStatus: .lightMeal,
        preWorkoutNote: "Had coffee and banana about an hour before",
        perceivedEffort: .moderate,
        userFeedback: nil
    )

    // MARK: - Workouts
    static let workouts: [Workout] = [
        detailedWorkout,
        Workout(
            id: UUID(),
            type: .hiit,
            startDate: Date().addingTimeInterval(-86400 - 1800),
            endDate: Date().addingTimeInterval(-86400),
            duration: 1800,
            calories: 290,
            averageHeartRate: 158,
            maxHeartRate: 185,
            intensity: .high,
            interpretation: "Intense interval session. You pushed into zone 4 multiple times. Allow 48 hours before another high-intensity workout.",
            recoveryHeartRate: 112,
            distance: nil,
            elevationGain: nil,
            whatHappened: "A 30-minute high-intensity interval session with 8 work periods. Peak heart rate reached 185 bpm during the final intervals.",
            whatItMeans: "You pushed your anaerobic threshold effectively. The elevated recovery heart rate suggests significant cardiovascular stress—this is expected and beneficial for improving VO2 max.",
            whatToDoNext: "Take it easy tomorrow. Your body needs 48 hours to fully recover from this type of session. Light movement is fine, but avoid another intense workout.",
            sleepBeforeWorkout: 6.5,
            hydrationLevel: .adequate,
            nutritionStatus: .wellFueled,
            preWorkoutNote: nil,
            perceivedEffort: .hard,
            userFeedback: nil
        ),
        Workout(
            id: UUID(),
            type: .strength,
            startDate: Date().addingTimeInterval(-172800 - 3600),
            endDate: Date().addingTimeInterval(-172800),
            duration: 3600,
            calories: 220,
            averageHeartRate: 118,
            maxHeartRate: 142,
            intensity: .moderate,
            interpretation: "Effective strength session. Your heart rate suggests good rest between sets. Focus on progressive overload next session.",
            recoveryHeartRate: 85,
            distance: nil,
            elevationGain: nil,
            whatHappened: "A 60-minute strength training session. Heart rate stayed moderate with good recovery between sets.",
            whatItMeans: "Your rest periods were appropriate for strength gains. The moderate cardiovascular demand suggests you're lifting with good form and control.",
            whatToDoNext: "Allow 48 hours before training the same muscle groups. Tomorrow would be ideal for cardio or training different muscle groups.",
            sleepBeforeWorkout: 8.0,
            hydrationLevel: .excellent,
            nutritionStatus: .fullMeal,
            preWorkoutNote: "Feeling strong today",
            perceivedEffort: .moderate,
            userFeedback: nil
        ),
        Workout(
            id: UUID(),
            type: .yoga,
            startDate: Date().addingTimeInterval(-259200 - 2700),
            endDate: Date().addingTimeInterval(-259200),
            duration: 2700,
            calories: 95,
            averageHeartRate: 82,
            maxHeartRate: 105,
            intensity: .low,
            interpretation: "Restorative session. Your heart rate variability improved post-session. Great for recovery and flexibility.",
            recoveryHeartRate: 72,
            distance: nil,
            elevationGain: nil,
            whatHappened: "A 45-minute restorative yoga session. Heart rate remained low throughout, indicating a truly relaxing practice.",
            whatItMeans: "This session supported your parasympathetic nervous system, aiding recovery. Your HRV improved after the session, a sign of reduced stress.",
            whatToDoNext: "You're well-recovered and ready for any type of workout tomorrow. This is a great time for a challenging session if you're feeling motivated.",
            sleepBeforeWorkout: 7.0,
            hydrationLevel: .good,
            nutritionStatus: .lightMeal,
            preWorkoutNote: nil,
            perceivedEffort: .veryLight,
            userFeedback: nil
        )
    ]

    // MARK: - Daily Context
    static let todayContext = DailyContext(
        id: UUID(),
        date: Date(),
        sleepHours: 7.5,
        sleepQuality: .good,
        stressLevel: .moderate,
        energyLevel: .high,
        restingHeartRate: 58,
        hrvScore: 45.2,
        readinessScore: 78
    )

    static let weeklyContexts: [DailyContext] = (0..<7).map { dayOffset in
        DailyContext(
            id: UUID(),
            date: Date().addingTimeInterval(TimeInterval(-dayOffset * 86400)),
            sleepHours: Double.random(in: 5.5...8.5),
            sleepQuality: SleepQuality.allCases.randomElement()!,
            stressLevel: StressLevel.allCases.randomElement()!,
            energyLevel: EnergyLevel.allCases.randomElement()!,
            restingHeartRate: Int.random(in: 55...68),
            hrvScore: Double.random(in: 35...55),
            readinessScore: Int.random(in: 50...95)
        )
    }

    // MARK: - Check-Ins
    static let checkIns: [CheckIn] = [
        CheckIn(
            id: UUID(),
            date: Date(),
            mood: Mood.great,
            energyLevel: EnergyLevel.high,
            soreness: SorenessLevel.mild,
            motivation: MotivationLevel.high,
            notes: "Feeling ready to train today"
        ),
        CheckIn(
            id: UUID(),
            date: Date().addingTimeInterval(-86400),
            mood: Mood.good,
            energyLevel: EnergyLevel.moderate,
            soreness: SorenessLevel.moderate,
            motivation: MotivationLevel.moderate,
            notes: "Legs still recovering from yesterday"
        ),
        CheckIn(
            id: UUID(),
            date: Date().addingTimeInterval(-172800),
            mood: Mood.okay,
            energyLevel: EnergyLevel.low,
            soreness: SorenessLevel.significant,
            motivation: MotivationLevel.low,
            notes: "Need more rest"
        )
    ]

    // MARK: - Recovery
    static let todayRecovery = NextDayRecovery(
        id: UUID(),
        date: Date(),
        overallScore: 78,
        muscleRecovery: .ready,
        cardioRecovery: .optimal,
        mentalRecovery: .ready,
        recommendation: .moderateTraining,
        suggestedWorkoutTypes: [.run, .cycle, .strength],
        interpretation: "Your body has recovered well from recent training. Cardio systems are fully restored. Consider a moderate-intensity session today focusing on aerobic work or strength training."
    )

    // MARK: - Trend Insights
    static let insights: [TrendInsight] = [
        TrendInsight(
            id: UUID(),
            type: .improvement,
            title: "Consistency Streak",
            description: "You've worked out 4 days this week, matching your best streak this month.",
            metric: .consistency,
            changePercentage: 15.0,
            timeframe: .week,
            createdAt: Date(),
            priority: .high
        ),
        TrendInsight(
            id: UUID(),
            type: .pattern,
            title: "Morning Performance",
            description: "Your morning workouts show 12% higher intensity than evening sessions.",
            metric: .averageIntensity,
            changePercentage: 12.0,
            timeframe: .month,
            createdAt: Date().addingTimeInterval(-3600),
            priority: .medium
        ),
        TrendInsight(
            id: UUID(),
            type: .milestone,
            title: "Recovery Improved",
            description: "Your average recovery time has decreased by 18% over the past month.",
            metric: .recoveryTime,
            changePercentage: -18.0,
            timeframe: .month,
            createdAt: Date().addingTimeInterval(-7200),
            priority: .high
        ),
        TrendInsight(
            id: UUID(),
            type: .recommendation,
            title: "Sleep Opportunity",
            description: "Adding 30 minutes of sleep could improve your HRV by an estimated 8%.",
            metric: .sleepQuality,
            changePercentage: 8.0,
            timeframe: .week,
            createdAt: Date().addingTimeInterval(-10800),
            priority: .medium
        )
    ]

    // MARK: - User Profile
    static let userName = "Sachi"
    static let memberSince = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    static let totalWorkouts = 47
    static let currentStreak = 4
    static let longestStreak = 12

    // MARK: - Home Screen Context
    static let hasNutritionData = true
    static let todayWaterIntake = 1.2 // liters
    static let todayCaloriesConsumed = 1850
    static let workoutsThisWeek = 3

    // MARK: - Status Messages
    static let statusMessages = [
        "You may feel a bit more taxed today than usual.",
        "Your body is well-rested and ready for a challenge.",
        "Consider taking it easy—your recovery metrics suggest fatigue.",
        "Great sleep last night should help you perform well today.",
        "Your consistency this week is paying off."
    ]

    static var todayStatusMessage: String {
        statusMessages[0]
    }
}
