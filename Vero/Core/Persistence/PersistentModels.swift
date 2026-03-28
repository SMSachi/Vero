//
//  PersistentModels.swift
//  Insio Health
//
//  SwiftData models for local persistence.
//  These mirror the struct-based models but are @Model classes for SwiftData.
//
//  ARCHITECTURE:
//  - Persistent models are prefixed with "Persisted" to distinguish from value types
//  - Each has a convenience initializer to create from the struct version
//  - Each has a computed property to convert back to the struct version
//  - Relationships are maintained via SwiftData's relationship system
//

import Foundation
import SwiftData

// MARK: - Persisted Workout

/// Persistent version of Workout for SwiftData storage.
@Model
final class PersistedWorkout {

    // MARK: - Core Properties

    /// Unique identifier - matches the UUID from HealthKit mapping
    @Attribute(.unique) var workoutId: UUID

    var type: String // WorkoutType raw value
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var calories: Int
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var intensity: String // WorkoutIntensity raw value
    var interpretation: String

    // MARK: - Extended Metrics

    var recoveryHeartRate: Int?
    var distance: Double?
    var elevationGain: Double?

    // MARK: - Insights (from InterpretationEngine)

    var whatHappened: String?
    var whatItMeans: String?
    var whatToDoNext: String?

    // MARK: - Stored Interpretation

    var interpretationSummary: String?
    var interpretationText: String?
    var interpretationRecommendation: String?
    var interpretationSentiment: String? // "positive", "neutral", "caution"

    // MARK: - Context at Workout Time

    var sleepBeforeWorkout: Double?
    var hydrationLevel: String?
    var nutritionStatus: String?
    var preWorkoutNote: String?

    // MARK: - User Response (from PostWorkoutCheckIn)

    var perceivedEffort: Int?
    var userFeedback: String?
    var postWorkoutFeeling: String? // WorkoutFeeling raw value
    var postWorkoutNote: String?
    var checkInDate: Date?

    // MARK: - Source Tracking

    /// How this workout was created (healthkit, manual, cloud_sync, historical)
    /// Default to "healthkit" for existing records that don't have this field
    var source: String = "healthkit"

    // MARK: - Metadata

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \PersistedNextDayRecovery.relatedWorkout)
    var nextDayRecovery: PersistedNextDayRecovery?

    // MARK: - Initialization

    init(
        workoutId: UUID = UUID(),
        type: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        calories: Int,
        averageHeartRate: Int?,
        maxHeartRate: Int?,
        intensity: String,
        interpretation: String,
        source: String = WorkoutSource.healthKit.rawValue
    ) {
        self.workoutId = workoutId
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.intensity = intensity
        self.interpretation = interpretation
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Create from a Workout struct
    convenience init(from workout: Workout) {
        self.init(
            workoutId: workout.id,
            type: workout.type.rawValue,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            calories: workout.calories,
            averageHeartRate: workout.averageHeartRate,
            maxHeartRate: workout.maxHeartRate,
            intensity: workout.intensity.rawValue,
            interpretation: workout.interpretation,
            source: workout.source.rawValue
        )

        // Extended metrics
        self.recoveryHeartRate = workout.recoveryHeartRate
        self.distance = workout.distance
        self.elevationGain = workout.elevationGain

        // Insights
        self.whatHappened = workout.whatHappened
        self.whatItMeans = workout.whatItMeans
        self.whatToDoNext = workout.whatToDoNext

        // Context
        self.sleepBeforeWorkout = workout.sleepBeforeWorkout
        self.hydrationLevel = workout.hydrationLevel?.rawValue
        self.nutritionStatus = workout.nutritionStatus?.rawValue
        self.preWorkoutNote = workout.preWorkoutNote

        // User response
        self.perceivedEffort = workout.perceivedEffort?.rawValue
        self.userFeedback = workout.userFeedback
    }

    /// Convert back to Workout struct
    func toWorkout() -> Workout {
        var workout = Workout(
            id: workoutId,
            type: WorkoutType(rawValue: type) ?? .other,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            calories: calories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            intensity: WorkoutIntensity(rawValue: intensity) ?? .moderate,
            interpretation: interpretation,
            recoveryHeartRate: recoveryHeartRate,
            distance: distance,
            elevationGain: elevationGain,
            whatHappened: whatHappened,
            whatItMeans: whatItMeans,
            whatToDoNext: whatToDoNext,
            sleepBeforeWorkout: sleepBeforeWorkout,
            hydrationLevel: hydrationLevel.flatMap { HydrationLevel(rawValue: $0) },
            nutritionStatus: nutritionStatus.flatMap { NutritionStatus(rawValue: $0) },
            preWorkoutNote: preWorkoutNote,
            perceivedEffort: perceivedEffort.flatMap { PerceivedEffort(rawValue: $0) },
            userFeedback: userFeedback
        )
        // Restore source from persisted value
        workout.source = WorkoutSource(rawValue: source) ?? .healthKit
        return workout
    }

    /// Update interpretation from InterpretationEngine result
    func updateInterpretation(_ interp: WorkoutInterpretation) {
        self.interpretationSummary = interp.summaryText
        self.interpretationText = interp.interpretationText
        self.interpretationRecommendation = interp.recommendationText
        self.interpretationSentiment = {
            switch interp.sentiment {
            case .positive: return "positive"
            case .neutral: return "neutral"
            case .caution: return "caution"
            }
        }()
        self.updatedAt = Date()
    }

    /// Update with post-workout check-in data
    func updateWithCheckIn(feeling: String, note: String?, date: Date = Date()) {
        self.postWorkoutFeeling = feeling
        self.postWorkoutNote = note
        self.checkInDate = date
        self.updatedAt = Date()
    }
}

// MARK: - Persisted Daily Context

/// Persistent version of DailyContext for SwiftData storage.
@Model
final class PersistedDailyContext {

    @Attribute(.unique) var contextId: UUID

    var date: Date
    var sleepHours: Double
    var sleepQuality: String // SleepQuality raw value
    var stressLevel: String // StressLevel raw value
    var energyLevel: String // EnergyLevel raw value
    var restingHeartRate: Int?
    var hrvScore: Double?
    var readinessScore: Int

    // Nutrition fields (added for daily context sync)
    var waterIntakeMl: Int?
    var calories: Int?
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?

    // Weight fields (only tracked if goal == weight_loss)
    var weightKg: Double?
    var bodyFatPercentage: Double?

    // Metadata
    var createdAt: Date
    var updatedAt: Date

    init(
        contextId: UUID = UUID(),
        date: Date,
        sleepHours: Double,
        sleepQuality: String,
        stressLevel: String,
        energyLevel: String,
        restingHeartRate: Int? = nil,
        hrvScore: Double? = nil,
        readinessScore: Int,
        waterIntakeMl: Int? = nil,
        calories: Int? = nil,
        proteinGrams: Int? = nil,
        carbsGrams: Int? = nil,
        fatGrams: Int? = nil,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil
    ) {
        self.contextId = contextId
        self.date = date
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.stressLevel = stressLevel
        self.energyLevel = energyLevel
        self.restingHeartRate = restingHeartRate
        self.hrvScore = hrvScore
        self.readinessScore = readinessScore
        self.waterIntakeMl = waterIntakeMl
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Create from DailyContext struct
    convenience init(from context: DailyContext) {
        self.init(
            contextId: context.id,
            date: context.date,
            sleepHours: context.sleepHours,
            sleepQuality: context.sleepQuality.rawValue,
            stressLevel: context.stressLevel.rawValue,
            energyLevel: context.energyLevel.rawValue,
            restingHeartRate: context.restingHeartRate,
            hrvScore: context.hrvScore,
            readinessScore: context.readinessScore,
            waterIntakeMl: context.waterIntakeMl,
            calories: context.calories,
            proteinGrams: context.proteinGrams,
            carbsGrams: context.carbsGrams,
            fatGrams: context.fatGrams,
            weightKg: context.weightKg,
            bodyFatPercentage: context.bodyFatPercentage
        )
    }

    /// Convert to DailyContext struct
    func toDailyContext() -> DailyContext {
        var context = DailyContext(
            id: contextId,
            date: date,
            sleepHours: sleepHours,
            sleepQuality: SleepQuality(rawValue: sleepQuality) ?? .fair,
            stressLevel: StressLevel(rawValue: stressLevel) ?? .moderate,
            energyLevel: EnergyLevel(rawValue: energyLevel) ?? .moderate,
            restingHeartRate: restingHeartRate,
            hrvScore: hrvScore,
            readinessScore: readinessScore
        )
        context.waterIntakeMl = waterIntakeMl
        context.calories = calories
        context.proteinGrams = proteinGrams
        context.carbsGrams = carbsGrams
        context.fatGrams = fatGrams
        context.weightKg = weightKg
        context.bodyFatPercentage = bodyFatPercentage
        return context
    }
}

// MARK: - Persisted Check-In

/// Persistent version of CheckIn for SwiftData storage.
/// This is a general check-in that can be used for various purposes.
@Model
final class PersistedCheckIn {

    @Attribute(.unique) var checkInId: UUID

    var date: Date
    var mood: String // Mood raw value
    var energyLevel: String // EnergyLevel raw value
    var soreness: String // SorenessLevel raw value
    var motivation: String // MotivationLevel raw value
    var notes: String?

    // Metadata
    var createdAt: Date

    init(
        checkInId: UUID = UUID(),
        date: Date,
        mood: String,
        energyLevel: String,
        soreness: String,
        motivation: String,
        notes: String? = nil
    ) {
        self.checkInId = checkInId
        self.date = date
        self.mood = mood
        self.energyLevel = energyLevel
        self.soreness = soreness
        self.motivation = motivation
        self.notes = notes
        self.createdAt = Date()
    }

    /// Create from CheckIn struct
    convenience init(from checkIn: CheckIn) {
        self.init(
            checkInId: checkIn.id,
            date: checkIn.date,
            mood: checkIn.mood.rawValue,
            energyLevel: checkIn.energyLevel.rawValue,
            soreness: checkIn.soreness.rawValue,
            motivation: checkIn.motivation.rawValue,
            notes: checkIn.notes
        )
    }

    /// Convert to CheckIn struct
    func toCheckIn() -> CheckIn {
        CheckIn(
            id: checkInId,
            date: date,
            mood: Mood(rawValue: mood) ?? .okay,
            energyLevel: EnergyLevel(rawValue: energyLevel) ?? .moderate,
            soreness: SorenessLevel(rawValue: soreness) ?? .none,
            motivation: MotivationLevel(rawValue: motivation) ?? .moderate,
            notes: notes
        )
    }
}

// MARK: - Persisted Next Day Recovery

/// Persistent version of NextDayRecovery for SwiftData storage.
/// Records how the user felt the day after a workout.
@Model
final class PersistedNextDayRecovery {

    @Attribute(.unique) var recoveryId: UUID

    var date: Date
    var overallScore: Int
    var muscleRecovery: String // RecoveryStatus raw value
    var cardioRecovery: String
    var mentalRecovery: String
    var recommendation: String // RecoveryRecommendation raw value

    /// JSON-encoded array of WorkoutType raw values.
    /// SwiftData cannot persist [String] directly, so we store as JSON string.
    var suggestedWorkoutTypesData: String = "[]"

    var interpretation: String

    // User input from NextDayCheckIn
    var bodyFeeling: String? // BodyFeeling raw value
    var checkInDate: Date?

    // Relationship to the workout this recovery is for
    var relatedWorkout: PersistedWorkout?

    // Metadata
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Property for Array Access

    /// Decoded array of suggested workout type strings.
    /// Returns empty array if data is missing or malformed.
    /// @Transient ensures SwiftData does not try to persist this computed property.
    @Transient
    var suggestedWorkoutTypes: [String] {
        get {
            guard let data = suggestedWorkoutTypesData.data(using: .utf8),
                  let types = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return types
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                suggestedWorkoutTypesData = string
            } else {
                suggestedWorkoutTypesData = "[]"
            }
        }
    }

    init(
        recoveryId: UUID = UUID(),
        date: Date,
        overallScore: Int,
        muscleRecovery: String,
        cardioRecovery: String,
        mentalRecovery: String,
        recommendation: String,
        suggestedWorkoutTypes: [String],
        interpretation: String
    ) {
        self.recoveryId = recoveryId
        self.date = date
        self.overallScore = overallScore
        self.muscleRecovery = muscleRecovery
        self.cardioRecovery = cardioRecovery
        self.mentalRecovery = mentalRecovery
        self.recommendation = recommendation
        self.interpretation = interpretation
        self.createdAt = Date()
        self.updatedAt = Date()

        // Encode the array to JSON string
        if let data = try? JSONEncoder().encode(suggestedWorkoutTypes),
           let string = String(data: data, encoding: .utf8) {
            self.suggestedWorkoutTypesData = string
        } else {
            self.suggestedWorkoutTypesData = "[]"
        }
    }

    /// Create from NextDayRecovery struct
    convenience init(from recovery: NextDayRecovery) {
        self.init(
            recoveryId: recovery.id,
            date: recovery.date,
            overallScore: recovery.overallScore,
            muscleRecovery: recovery.muscleRecovery.rawValue,
            cardioRecovery: recovery.cardioRecovery.rawValue,
            mentalRecovery: recovery.mentalRecovery.rawValue,
            recommendation: recovery.recommendation.rawValue,
            suggestedWorkoutTypes: recovery.suggestedWorkoutTypes.map { $0.rawValue },
            interpretation: recovery.interpretation
        )
    }

    /// Convert to NextDayRecovery struct
    func toNextDayRecovery() -> NextDayRecovery {
        NextDayRecovery(
            id: recoveryId,
            date: date,
            overallScore: overallScore,
            muscleRecovery: RecoveryStatus(rawValue: muscleRecovery) ?? .recovering,
            cardioRecovery: RecoveryStatus(rawValue: cardioRecovery) ?? .recovering,
            mentalRecovery: RecoveryStatus(rawValue: mentalRecovery) ?? .recovering,
            recommendation: RecoveryRecommendation(rawValue: recommendation) ?? .rest,
            suggestedWorkoutTypes: suggestedWorkoutTypes.compactMap { WorkoutType(rawValue: $0) },
            interpretation: interpretation
        )
    }

    /// Update with next-day check-in data
    func updateWithCheckIn(bodyFeeling: String, date: Date = Date()) {
        self.bodyFeeling = bodyFeeling
        self.checkInDate = date
        self.updatedAt = Date()

        // Adjust recovery score based on feeling
        switch bodyFeeling {
        case "Fresh":
            self.overallScore = min(100, overallScore + 10)
            self.muscleRecovery = RecoveryStatus.optimal.rawValue
        case "Slightly sore":
            // Keep existing score
            self.muscleRecovery = RecoveryStatus.ready.rawValue
        case "Pretty sore":
            self.overallScore = max(0, overallScore - 10)
            self.muscleRecovery = RecoveryStatus.partial.rawValue
        case "Drained":
            self.overallScore = max(0, overallScore - 20)
            self.muscleRecovery = RecoveryStatus.recovering.rawValue
        default:
            break
        }
    }
}

// MARK: - Post Workout Check-In Model

/// Dedicated model for post-workout check-ins.
/// This captures the user's immediate reaction after completing a workout.
@Model
final class PersistedPostWorkoutCheckIn {

    @Attribute(.unique) var checkInId: UUID

    var workoutId: UUID // Reference to the workout
    var date: Date
    var feeling: String // WorkoutFeeling raw value: easy, good, hard, brutal
    var note: String?

    // Metadata
    var createdAt: Date

    init(
        checkInId: UUID = UUID(),
        workoutId: UUID,
        date: Date = Date(),
        feeling: String,
        note: String? = nil
    ) {
        self.checkInId = checkInId
        self.workoutId = workoutId
        self.date = date
        self.feeling = feeling
        self.note = note
        self.createdAt = Date()
    }
}
