//
//  InterpretationEngine.swift
//  Insio Health
//
//  Rule-based interpretation engine that generates human-readable insights
//  about workouts based on workout data, daily context, check-ins, and patterns.
//
//  ARCHITECTURE:
//  - This engine is deterministic and runs entirely on-device
//  - No AI, no ML, no remote calls - just rule-based logic
//  - Easy to extend by adding new rules to the evaluate methods
//  - Returns a WorkoutInterpretation struct with summary, interpretation, and recommendation
//
//  HOW IT WORKS:
//  1. The engine receives a Workout, optional DailyContext, and optional CheckInInput
//  2. It evaluates multiple rule categories (intensity, recovery, context, patterns, check-in)
//  3. Each rule can contribute signals (positive, neutral, caution)
//  4. Final interpretation is composed from the most relevant signals
//

import Foundation

// MARK: - Check-In Input

/// Input from user check-ins that can influence interpretation.
/// This captures both post-workout feelings and next-day recovery feedback.
struct CheckInInput {
    /// How the workout felt immediately after (from PostWorkoutCheckIn)
    /// Values: "Easy", "Good", "Hard", "Brutal"
    let postWorkoutFeeling: String?

    /// Optional note from post-workout check-in
    let postWorkoutNote: String?

    /// How the body feels the next day (from NextDayCheckIn)
    /// Values: "Fresh", "Slightly sore", "Pretty sore", "Drained"
    let nextDayFeeling: String?

    init(
        postWorkoutFeeling: String? = nil,
        postWorkoutNote: String? = nil,
        nextDayFeeling: String? = nil
    ) {
        self.postWorkoutFeeling = postWorkoutFeeling
        self.postWorkoutNote = postWorkoutNote
        self.nextDayFeeling = nextDayFeeling
    }
}

// MARK: - Interpretation Engine

/// Rule-based engine that generates workout interpretations.
/// All logic is deterministic and runs locally on-device.
struct InterpretationEngine {

    // MARK: - Main Interpretation Method

    /// Generate a complete interpretation for a workout.
    ///
    /// - Parameters:
    ///   - workout: The workout to interpret
    ///   - context: Optional daily context (sleep, HRV, stress, etc.)
    ///   - previousWorkouts: Optional array of recent workouts for pattern detection
    ///   - checkIn: Optional check-in input from user (post-workout feeling, next-day recovery)
    /// - Returns: A WorkoutInterpretation with summary, explanation, and recommendation
    static func interpret(
        workout: Workout,
        context: DailyContext? = nil,
        previousWorkouts: [Workout] = [],
        checkIn: CheckInInput? = nil
    ) -> WorkoutInterpretation {

        // HONEST FIRST-WORKOUT HANDLING
        // If this is a first/early workout without physiological data, be honest about it
        let isFirstWorkout = previousWorkouts.isEmpty
        let hasPhysiologicalData = workout.averageHeartRate != nil || workout.maxHeartRate != nil
        let hasContextData = context != nil && (context?.hrvScore != nil || context?.sleepHours ?? 0 > 0)

        if isFirstWorkout && !hasPhysiologicalData {
            return generateHonestFirstWorkoutInterpretation(
                workout: workout,
                hasContextData: hasContextData,
                checkIn: checkIn
            )
        }

        // EARLY-STAGE USER (few workouts, no HR data)
        // Don't pretend we have insights we don't have
        if !hasPhysiologicalData && previousWorkouts.count < 3 {
            return generateEarlyStageInterpretation(
                workout: workout,
                previousWorkouts: previousWorkouts,
                checkIn: checkIn
            )
        }

        // Collect signals from all rule evaluators
        var signals: [InterpretationSignal] = []

        // 1. Evaluate workout intensity rules
        signals.append(contentsOf: evaluateIntensity(workout: workout))

        // 2. Evaluate context rules (sleep, HRV, stress)
        if let context = context {
            signals.append(contentsOf: evaluateContext(workout: workout, context: context))
        }

        // 3. Evaluate heart rate rules (only if we have HR data)
        if hasPhysiologicalData {
            signals.append(contentsOf: evaluateHeartRate(workout: workout))
        }

        // 4. Evaluate duration rules
        signals.append(contentsOf: evaluateDuration(workout: workout))

        // 5. Evaluate pattern rules (comparing to previous workouts)
        if !previousWorkouts.isEmpty {
            signals.append(contentsOf: evaluatePatterns(workout: workout, previous: previousWorkouts))
        }

        // 6. Evaluate workout type-specific rules
        signals.append(contentsOf: evaluateWorkoutType(workout: workout, context: context))

        // 7. Evaluate check-in rules (user's subjective feedback)
        if let checkIn = checkIn {
            signals.append(contentsOf: evaluateCheckIn(workout: workout, checkIn: checkIn))
        }

        // Generate the interpretation from collected signals
        return composeInterpretation(
            workout: workout,
            context: context,
            signals: signals
        )
    }

    // MARK: - Honest First Workout Interpretation

    /// Generate an honest interpretation for a user's first workout without physiological data.
    private static func generateHonestFirstWorkoutInterpretation(
        workout: Workout,
        hasContextData: Bool,
        checkIn: CheckInInput?
    ) -> WorkoutInterpretation {

        let typeName = workout.type.rawValue.lowercased()
        let durationStr = workout.durationFormatted

        // Build honest summary
        let summaryText = "Great start — your first \(typeName) logged in Insio."

        // Build honest interpretation
        var interpretationParts: [String] = [
            "You completed a \(durationStr) \(typeName) workout."
        ]

        // Add perceived effort if available
        switch workout.intensity {
        case .low:
            interpretationParts.append("You reported this as a light effort session.")
        case .moderate:
            interpretationParts.append("You reported this as a moderate effort.")
        case .high:
            interpretationParts.append("You pushed hard during this session.")
        case .max:
            interpretationParts.append("This was a max effort workout.")
        }

        // Add check-in feedback if available
        if let feeling = checkIn?.postWorkoutFeeling {
            interpretationParts.append("You felt \"\(feeling.lowercased())\" afterward.")
        }

        interpretationParts.append("As you log more workouts, Insio will begin identifying patterns in effort, recovery, and consistency.")

        let interpretationText = interpretationParts.joined(separator: " ")

        // Honest recommendation
        let recommendationText = "Keep logging your workouts. With more data, Insio can provide personalized insights about your training patterns."

        // Simple bullet points
        var bullets: [InterpretationBullet] = [
            InterpretationBullet(
                icon: "checkmark.circle.fill",
                text: "First workout logged — you're building your training history.",
                sentiment: .positive
            )
        ]

        if !hasContextData {
            bullets.append(InterpretationBullet(
                icon: "applewatch",
                text: "Connect Apple Health for heart rate, sleep, and recovery insights.",
                sentiment: .neutral
            ))
        }

        return WorkoutInterpretation(
            summaryText: summaryText,
            interpretationText: interpretationText,
            recommendationText: recommendationText,
            bulletPoints: bullets,
            sentiment: .positive,
            signals: []
        )
    }

    // MARK: - Early Stage Interpretation

    /// Generate interpretation for early-stage users without full physiological data.
    private static func generateEarlyStageInterpretation(
        workout: Workout,
        previousWorkouts: [Workout],
        checkIn: CheckInInput?
    ) -> WorkoutInterpretation {

        let typeName = workout.type.rawValue.lowercased()
        let durationStr = workout.durationFormatted
        let workoutCount = previousWorkouts.count + 1

        // Summary
        let summaryText = "\(durationStr) \(typeName) — workout #\(workoutCount) logged."

        // Interpretation
        var interpretationParts: [String] = [
            "You completed a \(durationStr) \(typeName) session."
        ]

        switch workout.intensity {
        case .low:
            interpretationParts.append("This was a light effort that supports recovery.")
        case .moderate:
            interpretationParts.append("A solid moderate effort.")
        case .high, .max:
            interpretationParts.append("You pushed yourself in this session.")
        }

        if let feeling = checkIn?.postWorkoutFeeling {
            interpretationParts.append("You reported feeling \"\(feeling.lowercased())\" after the workout.")
        }

        if workoutCount < 3 {
            interpretationParts.append("Log a few more workouts to unlock pattern insights.")
        }

        let interpretationText = interpretationParts.joined(separator: " ")

        // Recommendation
        let recommendationText: String
        switch workout.intensity {
        case .low:
            recommendationText = "Light activity tomorrow is fine."
        case .moderate:
            recommendationText = "Another moderate effort tomorrow would be appropriate."
        case .high:
            recommendationText = "Consider taking it easier tomorrow."
        case .max:
            recommendationText = "Allow time for recovery before your next intense session."
        }

        // Bullets
        var bullets: [InterpretationBullet] = [
            InterpretationBullet(
                icon: "chart.bar.fill",
                text: "Building your workout history (\(workoutCount) workout\(workoutCount == 1 ? "" : "s") so far).",
                sentiment: .neutral
            )
        ]

        if workout.averageHeartRate == nil {
            bullets.append(InterpretationBullet(
                icon: "heart.fill",
                text: "Heart rate data unlocks deeper insights. Use Apple Watch or connect Health.",
                sentiment: .neutral
            ))
        }

        return WorkoutInterpretation(
            summaryText: summaryText,
            interpretationText: interpretationText,
            recommendationText: recommendationText,
            bulletPoints: bullets,
            sentiment: .neutral,
            signals: []
        )
    }

    // MARK: - Rule Evaluators

    // ═══════════════════════════════════════════════════════════════════
    // INTENSITY RULES
    // Evaluate the workout's intensity level and its implications
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateIntensity(workout: Workout) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        switch workout.intensity {
        case .low:
            signals.append(InterpretationSignal(
                category: .intensity,
                sentiment: .positive,
                weight: 0.7,
                summaryFragment: "easy effort",
                explanationFragment: "This was a gentle session that supported recovery without adding stress.",
                recommendationFragment: "Light activity tomorrow is fine."
            ))

        case .moderate:
            signals.append(InterpretationSignal(
                category: .intensity,
                sentiment: .neutral,
                weight: 0.8,
                summaryFragment: "solid effort",
                explanationFragment: "You maintained a sustainable pace that builds aerobic fitness.",
                recommendationFragment: "Your body can handle similar effort tomorrow if needed."
            ))

        case .high:
            signals.append(InterpretationSignal(
                category: .intensity,
                sentiment: .caution,
                weight: 0.9,
                summaryFragment: "pushed hard",
                explanationFragment: "Your cardiovascular system was challenged significantly.",
                recommendationFragment: "Allow 24-48 hours before another intense session."
            ))

        case .max:
            signals.append(InterpretationSignal(
                category: .intensity,
                sentiment: .caution,
                weight: 1.0,
                summaryFragment: "maximum effort",
                explanationFragment: "This was an all-out session that depleted energy reserves.",
                recommendationFragment: "Prioritize rest and nutrition. Recovery is essential."
            ))
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONTEXT RULES
    // Evaluate how daily context affects workout interpretation
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateContext(
        workout: Workout,
        context: DailyContext
    ) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        // RULE: High intensity + poor sleep = more taxing than usual
        if workout.intensity == .high || workout.intensity == .max {
            if context.sleepQuality == .poor || context.sleepHours < 6 {
                signals.append(InterpretationSignal(
                    category: .context,
                    sentiment: .caution,
                    weight: 0.95,
                    summaryFragment: "harder on limited sleep",
                    explanationFragment: "With only \(String(format: "%.1f", context.sleepHours)) hours of sleep, this workout likely cost more than usual.",
                    recommendationFragment: "Extra recovery time is needed. Prioritize sleep tonight."
                ))
            }
        }

        // RULE: Low HRV + hard effort = recovery may be slower
        if let hrv = context.hrvScore, hrv < 40 {
            if workout.intensity == .high || workout.intensity == .max {
                signals.append(InterpretationSignal(
                    category: .context,
                    sentiment: .caution,
                    weight: 0.85,
                    summaryFragment: "recovery may be slower",
                    explanationFragment: "Your HRV was lower than optimal (\(Int(hrv))ms), suggesting your body was already under some stress.",
                    recommendationFragment: "Monitor how you feel tomorrow. Take it easy if fatigue persists."
                ))
            }
        }

        // RULE: High stress + workout = may have helped or added load
        if context.stressLevel == .high || context.stressLevel == .veryHigh {
            if workout.intensity == .low || workout.intensity == .moderate {
                signals.append(InterpretationSignal(
                    category: .context,
                    sentiment: .positive,
                    weight: 0.7,
                    summaryFragment: "good stress relief",
                    explanationFragment: "Light-to-moderate activity during high stress can help regulate your nervous system.",
                    recommendationFragment: nil
                ))
            } else {
                signals.append(InterpretationSignal(
                    category: .context,
                    sentiment: .caution,
                    weight: 0.75,
                    summaryFragment: "added to existing stress",
                    explanationFragment: "Intense exercise during periods of high stress compounds the load on your system.",
                    recommendationFragment: "Consider lighter activity until stress levels decrease."
                ))
            }
        }

        // RULE: Good sleep + moderate effort = optimal training stimulus
        if context.sleepQuality == .good || context.sleepQuality == .excellent {
            if context.sleepHours >= 7 && workout.intensity == .moderate {
                signals.append(InterpretationSignal(
                    category: .context,
                    sentiment: .positive,
                    weight: 0.8,
                    summaryFragment: "well-rested training",
                    explanationFragment: "Good sleep before this workout means better adaptation potential.",
                    recommendationFragment: nil
                ))
            }
        }

        // RULE: Low energy + completed workout = pushed through
        if context.energyLevel == .low || context.energyLevel == .depleted {
            signals.append(InterpretationSignal(
                category: .context,
                sentiment: .neutral,
                weight: 0.6,
                summaryFragment: "powered through low energy",
                explanationFragment: "You completed this workout despite feeling depleted. Sometimes showing up matters most.",
                recommendationFragment: "Listen to your body tomorrow. Rest if needed."
            ))
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // HEART RATE RULES
    // Evaluate heart rate patterns during the workout
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateHeartRate(workout: Workout) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        guard let avgHR = workout.averageHeartRate, let maxHR = workout.maxHeartRate else {
            // No heart rate data available (manual entry)
            return signals
        }

        // RULE: Very high average HR suggests maximal effort
        if avgHR > 170 {
            signals.append(InterpretationSignal(
                category: .heartRate,
                sentiment: .caution,
                weight: 0.85,
                summaryFragment: "elevated heart rate throughout",
                explanationFragment: "Your heart rate averaged \(avgHR) bpm—near your upper limits for sustained effort.",
                recommendationFragment: nil
            ))
        }

        // RULE: HR near or above 90% of estimated max
        let estimatedMaxHR = 220 - 30 // Assuming ~30 years old, this is approximate
        if maxHR > Int(Double(estimatedMaxHR) * 0.95) {
            signals.append(InterpretationSignal(
                category: .heartRate,
                sentiment: .caution,
                weight: 0.7,
                summaryFragment: "peak heart rate",
                explanationFragment: "You hit \(maxHR) bpm at peak—close to maximum capacity.",
                recommendationFragment: nil
            ))
        }

        // RULE: Low HR for workout type suggests easy pace
        if workout.type == .run || workout.type == .cycle {
            if avgHR < 120 {
                signals.append(InterpretationSignal(
                    category: .heartRate,
                    sentiment: .positive,
                    weight: 0.6,
                    summaryFragment: "kept heart rate low",
                    explanationFragment: "Maintaining a low heart rate during cardio builds aerobic base efficiently.",
                    recommendationFragment: nil
                ))
            }
        }

        // RULE: Good recovery heart rate (if available)
        if let recoveryHR = workout.recoveryHeartRate {
            if recoveryHR < 100 {
                signals.append(InterpretationSignal(
                    category: .heartRate,
                    sentiment: .positive,
                    weight: 0.75,
                    summaryFragment: "quick recovery",
                    explanationFragment: "Your heart rate dropped to \(recoveryHR) bpm quickly after finishing—a sign of good cardiovascular fitness.",
                    recommendationFragment: nil
                ))
            } else if recoveryHR > 120 {
                signals.append(InterpretationSignal(
                    category: .heartRate,
                    sentiment: .caution,
                    weight: 0.7,
                    summaryFragment: "slow recovery",
                    explanationFragment: "Heart rate stayed elevated at \(recoveryHR) bpm after finishing. This may indicate accumulated fatigue.",
                    recommendationFragment: "Allow extra recovery time before the next hard session."
                ))
            }
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // DURATION RULES
    // Evaluate workout duration and its implications
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateDuration(workout: Workout) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        let durationMinutes = workout.durationMinutes

        // RULE: Long duration workouts
        if durationMinutes > 60 {
            if workout.intensity == .high || workout.intensity == .max {
                signals.append(InterpretationSignal(
                    category: .duration,
                    sentiment: .caution,
                    weight: 0.85,
                    summaryFragment: "extended high-intensity",
                    explanationFragment: "A \(durationMinutes)-minute session at this intensity significantly depletes glycogen stores.",
                    recommendationFragment: "Refuel with carbohydrates and protein within the next hour."
                ))
            } else {
                signals.append(InterpretationSignal(
                    category: .duration,
                    sentiment: .positive,
                    weight: 0.7,
                    summaryFragment: "good endurance session",
                    explanationFragment: "Extended duration at moderate intensity builds aerobic endurance effectively.",
                    recommendationFragment: nil
                ))
            }
        }

        // RULE: Short high-intensity (efficient)
        if durationMinutes < 30 && workout.intensity == .high {
            signals.append(InterpretationSignal(
                category: .duration,
                sentiment: .neutral,
                weight: 0.65,
                summaryFragment: "efficient high-intensity",
                explanationFragment: "Short, intense sessions can be effective for fitness when time is limited.",
                recommendationFragment: nil
            ))
        }

        // RULE: Very short workout
        if durationMinutes < 15 {
            signals.append(InterpretationSignal(
                category: .duration,
                sentiment: .neutral,
                weight: 0.4,
                summaryFragment: "quick session",
                explanationFragment: "Even brief movement counts. Consistency matters more than duration.",
                recommendationFragment: nil
            ))
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // PATTERN RULES
    // Compare current workout to recent history for pattern detection
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluatePatterns(
        workout: Workout,
        previous: [Workout]
    ) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        // Filter to same workout type for comparison
        let sameTypeWorkouts = previous.filter { $0.type == workout.type }

        if sameTypeWorkouts.count >= 2, let currentHR = workout.averageHeartRate {
            // Calculate average intensity/HR from previous similar workouts (only those with HR data)
            let workoutsWithHR = sameTypeWorkouts.compactMap { $0.averageHeartRate }
            if !workoutsWithHR.isEmpty {
                let avgPreviousHR = workoutsWithHR.reduce(0, +) / workoutsWithHR.count

                // RULE: Lower effort for similar workout type = getting easier
                if currentHR < avgPreviousHR - 10 {
                    signals.append(InterpretationSignal(
                        category: .pattern,
                        sentiment: .positive,
                        weight: 0.8,
                        summaryFragment: "improving efficiency",
                        explanationFragment: "Your heart rate was lower than usual for this type of workout. This suggests improving fitness.",
                        recommendationFragment: "You might be ready to increase intensity or duration."
                    ))
                }

                // RULE: Higher effort for similar workout = might be fatigued
                if currentHR > avgPreviousHR + 15 {
                    signals.append(InterpretationSignal(
                        category: .pattern,
                        sentiment: .caution,
                        weight: 0.75,
                        summaryFragment: "higher effort than usual",
                        explanationFragment: "Your heart rate was elevated compared to similar recent workouts. This could indicate fatigue.",
                        recommendationFragment: "Consider whether you're fully recovered from recent training."
                    ))
                }
            }
        }

        // RULE: Check for consecutive high-intensity days
        let recentHighIntensity = previous.prefix(3).filter {
            $0.intensity == .high || $0.intensity == .max
        }

        if recentHighIntensity.count >= 2 && (workout.intensity == .high || workout.intensity == .max) {
            signals.append(InterpretationSignal(
                category: .pattern,
                sentiment: .caution,
                weight: 0.9,
                summaryFragment: "multiple hard days",
                explanationFragment: "This is your third or more high-intensity session recently. Back-to-back hard days increase injury risk.",
                recommendationFragment: "Take at least one full recovery day soon."
            ))
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // WORKOUT TYPE RULES
    // Type-specific interpretations (strength, cardio, recovery, etc.)
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateWorkoutType(
        workout: Workout,
        context: DailyContext?
    ) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        switch workout.type {
        case .strength:
            // RULE: Strength + high intensity = muscle building
            if workout.intensity == .moderate || workout.intensity == .high {
                signals.append(InterpretationSignal(
                    category: .workoutType,
                    sentiment: .neutral,
                    weight: 0.7,
                    summaryFragment: "strength training stimulus",
                    explanationFragment: "This session provided stimulus for muscle adaptation. Protein intake and sleep support recovery.",
                    recommendationFragment: "Allow 48 hours before training the same muscle groups."
                ))
            }

        case .yoga:
            signals.append(InterpretationSignal(
                category: .workoutType,
                sentiment: .positive,
                weight: 0.65,
                summaryFragment: "recovery-focused",
                explanationFragment: "Yoga supports nervous system recovery and mobility.",
                recommendationFragment: "You're ready for any type of workout tomorrow."
            ))

        case .hiit:
            signals.append(InterpretationSignal(
                category: .workoutType,
                sentiment: .caution,
                weight: 0.85,
                summaryFragment: "high metabolic demand",
                explanationFragment: "HIIT creates significant metabolic stress and depletes fast-twitch muscle fibers.",
                recommendationFragment: "Avoid another HIIT session for at least 48 hours."
            ))

        case .run, .cycle:
            if workout.intensity == .low {
                signals.append(InterpretationSignal(
                    category: .workoutType,
                    sentiment: .positive,
                    weight: 0.6,
                    summaryFragment: "aerobic base building",
                    explanationFragment: "Low-intensity cardio builds endurance without excessive stress.",
                    recommendationFragment: nil
                ))
            }

        case .swim:
            signals.append(InterpretationSignal(
                category: .workoutType,
                sentiment: .positive,
                weight: 0.65,
                summaryFragment: "low-impact cardio",
                explanationFragment: "Swimming provides cardiovascular benefits with minimal joint stress.",
                recommendationFragment: nil
            ))

        default:
            break
        }

        return signals
    }

    // ═══════════════════════════════════════════════════════════════════
    // CHECK-IN RULES
    // Incorporate user's subjective feedback from check-ins
    // ═══════════════════════════════════════════════════════════════════

    private static func evaluateCheckIn(
        workout: Workout,
        checkIn: CheckInInput
    ) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []

        // RULE: Post-workout feeling evaluation
        if let feeling = checkIn.postWorkoutFeeling {
            switch feeling {
            case "Easy":
                // Workout felt easier than data suggests
                if workout.intensity == .high || workout.intensity == .max {
                    signals.append(InterpretationSignal(
                        category: .checkIn,
                        sentiment: .positive,
                        weight: 0.85,
                        summaryFragment: "felt easier than expected",
                        explanationFragment: "Despite the metrics showing high intensity, you felt strong. This suggests good fitness adaptation.",
                        recommendationFragment: "You might be ready for more challenging workouts."
                    ))
                } else {
                    signals.append(InterpretationSignal(
                        category: .checkIn,
                        sentiment: .positive,
                        weight: 0.7,
                        summaryFragment: "comfortable effort",
                        explanationFragment: "The workout felt manageable, matching the moderate load.",
                        recommendationFragment: nil
                    ))
                }

            case "Good":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .positive,
                    weight: 0.75,
                    summaryFragment: "felt good overall",
                    explanationFragment: "You reported feeling good after this session — a sign of appropriate training load.",
                    recommendationFragment: nil
                ))

            case "Hard":
                // Workout felt hard — check if data agrees
                if workout.intensity == .low || workout.intensity == .moderate {
                    signals.append(InterpretationSignal(
                        category: .checkIn,
                        sentiment: .caution,
                        weight: 0.9,
                        summaryFragment: "harder than usual",
                        explanationFragment: "You felt this workout was hard despite moderate metrics. This may indicate accumulated fatigue or external stress.",
                        recommendationFragment: "Consider extra recovery before your next intense session."
                    ))
                } else {
                    signals.append(InterpretationSignal(
                        category: .checkIn,
                        sentiment: .neutral,
                        weight: 0.7,
                        summaryFragment: "appropriately challenging",
                        explanationFragment: "The workout felt hard, which matches the high intensity. This is expected.",
                        recommendationFragment: nil
                    ))
                }

            case "Brutal":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .caution,
                    weight: 0.95,
                    summaryFragment: "maximum perceived effort",
                    explanationFragment: "You described this as brutal — your body was pushed to its limits. Recovery is critical.",
                    recommendationFragment: "Take it easy tomorrow. Active recovery or rest is recommended."
                ))

            default:
                break
            }
        }

        // RULE: Next-day feeling evaluation
        if let nextDayFeeling = checkIn.nextDayFeeling {
            switch nextDayFeeling {
            case "Fresh":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .positive,
                    weight: 0.8,
                    summaryFragment: "recovered well",
                    explanationFragment: "You woke up feeling fresh — excellent recovery from the previous workout.",
                    recommendationFragment: "Your body is ready for another training session."
                ))

            case "Slightly sore":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .neutral,
                    weight: 0.65,
                    summaryFragment: "mild soreness",
                    explanationFragment: "Light soreness the next day is normal and indicates your muscles are adapting.",
                    recommendationFragment: nil
                ))

            case "Pretty sore":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .caution,
                    weight: 0.8,
                    summaryFragment: "significant soreness",
                    explanationFragment: "You reported feeling pretty sore. The workout created substantial muscle damage.",
                    recommendationFragment: "Light movement like walking or yoga can help. Avoid intense training."
                ))

            case "Drained":
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .caution,
                    weight: 0.9,
                    summaryFragment: "depleted recovery",
                    explanationFragment: "Feeling drained suggests the workout was very taxing on your system.",
                    recommendationFragment: "Prioritize rest, sleep, and nutrition today. Skip hard training."
                ))

            default:
                break
            }
        }

        // RULE: Check for mismatch between post-workout feeling and next-day recovery
        if let postFeeling = checkIn.postWorkoutFeeling,
           let nextDayFeeling = checkIn.nextDayFeeling {
            // Felt easy but drained next day = possibly underestimated effort
            if (postFeeling == "Easy" || postFeeling == "Good") && nextDayFeeling == "Drained" {
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .caution,
                    weight: 0.85,
                    summaryFragment: "delayed fatigue",
                    explanationFragment: "The workout felt manageable but left you drained. This delayed fatigue suggests hidden stress.",
                    recommendationFragment: "Pay attention to cumulative fatigue in future sessions."
                ))
            }

            // Felt brutal but fresh next day = good recovery capacity
            if postFeeling == "Brutal" && nextDayFeeling == "Fresh" {
                signals.append(InterpretationSignal(
                    category: .checkIn,
                    sentiment: .positive,
                    weight: 0.85,
                    summaryFragment: "excellent recovery",
                    explanationFragment: "Despite the intense effort, you recovered quickly. This indicates strong fitness.",
                    recommendationFragment: nil
                ))
            }
        }

        return signals
    }

    // MARK: - Interpretation Composer

    /// Compose the final interpretation from collected signals.
    private static func composeInterpretation(
        workout: Workout,
        context: DailyContext?,
        signals: [InterpretationSignal]
    ) -> WorkoutInterpretation {

        // Sort signals by weight (importance)
        let sortedSignals = signals.sorted { $0.weight > $1.weight }

        // Take top signals for composition
        let topSignals = Array(sortedSignals.prefix(4))

        // Determine overall sentiment
        let cautionCount = topSignals.filter { $0.sentiment == .caution }.count
        let positiveCount = topSignals.filter { $0.sentiment == .positive }.count

        let overallSentiment: InterpretationSentiment
        if cautionCount >= 2 {
            overallSentiment = .caution
        } else if positiveCount >= 2 {
            overallSentiment = .positive
        } else {
            overallSentiment = .neutral
        }

        // Build summary (one line for dashboard)
        let summaryText = buildSummary(workout: workout, signals: topSignals, sentiment: overallSentiment)

        // Build interpretation (paragraph explanation)
        let interpretationText = buildInterpretation(workout: workout, context: context, signals: topSignals)

        // Build recommendation (what to do next)
        let recommendationText = buildRecommendation(workout: workout, signals: topSignals)

        // Build bullet points
        let bulletPoints = buildBulletPoints(signals: topSignals)

        return WorkoutInterpretation(
            summaryText: summaryText,
            interpretationText: interpretationText,
            recommendationText: recommendationText,
            bulletPoints: bulletPoints,
            sentiment: overallSentiment,
            signals: sortedSignals
        )
    }

    // MARK: - Text Builders

    private static func buildSummary(
        workout: Workout,
        signals: [InterpretationSignal],
        sentiment: InterpretationSentiment
    ) -> String {

        // Get the most important signal's summary fragment
        guard let primarySignal = signals.first else {
            return "Completed \(workout.type.rawValue.lowercased()) session."
        }

        // Find a context-based signal if available
        let contextSignal = signals.first { $0.category == .context }

        let durationStr = workout.durationFormatted

        // Compose based on sentiment and signals
        switch sentiment {
        case .positive:
            if let ctx = contextSignal {
                return "\(durationStr) \(workout.type.rawValue.lowercased()) — \(ctx.summaryFragment)."
            }
            return "\(durationStr) \(workout.type.rawValue.lowercased()) — \(primarySignal.summaryFragment)."

        case .caution:
            if let ctx = contextSignal {
                return "This session may have been \(ctx.summaryFragment)."
            }
            return "This \(workout.type.rawValue.lowercased()) session \(primarySignal.summaryFragment)."

        case .neutral:
            return "\(durationStr) \(workout.type.rawValue.lowercased()) with \(primarySignal.summaryFragment)."
        }
    }

    private static func buildInterpretation(
        workout: Workout,
        context: DailyContext?,
        signals: [InterpretationSignal]
    ) -> String {

        var paragraphs: [String] = []

        // Opening sentence with workout basics
        if let avgHR = workout.averageHeartRate {
            let opening = "During this \(workout.durationFormatted) \(workout.type.rawValue.lowercased()), your heart rate averaged \(avgHR) bpm"

            if let maxHR = workout.maxHeartRate, maxHR > 0 {
                paragraphs.append("\(opening) and peaked at \(maxHR) bpm.")
            } else {
                paragraphs.append("\(opening).")
            }
        } else {
            paragraphs.append("This \(workout.durationFormatted) \(workout.type.rawValue.lowercased()) was a \(workout.intensity.rawValue.lowercased()) intensity effort.")
        }

        // Add top explanation fragments
        for signal in signals.prefix(3) {
            if let explanation = signal.explanationFragment {
                paragraphs.append(explanation)
            }
        }

        return paragraphs.joined(separator: " ")
    }

    private static func buildRecommendation(
        workout: Workout,
        signals: [InterpretationSignal]
    ) -> String {

        // Collect all recommendation fragments
        let recommendations = signals.compactMap { $0.recommendationFragment }

        if recommendations.isEmpty {
            // Fallback based on intensity
            switch workout.intensity {
            case .low:
                return "Light activity tomorrow is fine. Your body can handle more if you're feeling ready."
            case .moderate:
                return "A good balance of effort and recovery. Tomorrow could be another moderate day, or take it easy."
            case .high:
                return "Consider prioritizing sleep tonight and taking it easier tomorrow."
            case .max:
                return "Take tomorrow easy. Light movement only. Let your body recover."
            }
        }

        // Return the most weighted recommendation
        return recommendations.first ?? "Listen to your body and recover as needed."
    }

    private static func buildBulletPoints(
        signals: [InterpretationSignal]
    ) -> [InterpretationBullet] {

        return signals.prefix(4).compactMap { signal -> InterpretationBullet? in
            guard let explanation = signal.explanationFragment else { return nil }

            let icon: String
            switch signal.category {
            case .intensity: icon = "flame.fill"
            case .context: icon = "moon.zzz.fill"
            case .heartRate: icon = "heart.fill"
            case .duration: icon = "clock.fill"
            case .pattern: icon = "chart.line.uptrend.xyaxis"
            case .workoutType: icon = "figure.run"
            case .checkIn: icon = "person.fill.checkmark"
            }

            return InterpretationBullet(
                icon: icon,
                text: explanation,
                sentiment: signal.sentiment
            )
        }
    }
}

// MARK: - Supporting Types

/// A signal collected during rule evaluation.
struct InterpretationSignal {
    let category: SignalCategory
    let sentiment: InterpretationSentiment
    let weight: Double // 0.0 - 1.0, higher = more important
    let summaryFragment: String
    let explanationFragment: String?
    let recommendationFragment: String?

    init(
        category: SignalCategory,
        sentiment: InterpretationSentiment,
        weight: Double,
        summaryFragment: String,
        explanationFragment: String? = nil,
        recommendationFragment: String? = nil
    ) {
        self.category = category
        self.sentiment = sentiment
        self.weight = weight
        self.summaryFragment = summaryFragment
        self.explanationFragment = explanationFragment
        self.recommendationFragment = recommendationFragment
    }
}

/// Categories of interpretation signals.
enum SignalCategory {
    case intensity
    case context
    case heartRate
    case duration
    case pattern
    case workoutType
    case checkIn // User's subjective feedback from check-ins
}

/// Overall sentiment of the interpretation.
enum InterpretationSentiment {
    case positive
    case neutral
    case caution
}

/// A bullet point for display in the interpretation view.
struct InterpretationBullet {
    let icon: String
    let text: String
    let sentiment: InterpretationSentiment
}
