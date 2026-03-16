//
//  Workout.swift
//  Vero
//

import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    let type: WorkoutType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calories: Int
    let averageHeartRate: Int
    let maxHeartRate: Int
    let intensity: WorkoutIntensity
    let interpretation: String

    // Extended metrics
    var recoveryHeartRate: Int?
    var distance: Double? // in kilometers
    var elevationGain: Double? // in meters

    // Insights
    var whatHappened: String?
    var whatItMeans: String?
    var whatToDoNext: String?

    // Context at time of workout
    var sleepBeforeWorkout: Double?
    var hydrationLevel: HydrationLevel?
    var nutritionStatus: NutritionStatus?
    var preWorkoutNote: String?

    // User response
    var perceivedEffort: PerceivedEffort?
    var userFeedback: String?

    var durationFormatted: String {
        let totalMinutes = Int(duration) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", totalMinutes, seconds)
    }

    var durationMinutes: Int {
        Int(duration) / 60
    }

    var distanceFormatted: String? {
        guard let distance = distance else { return nil }
        if distance < 1 {
            return String(format: "%.0fm", distance * 1000)
        }
        return String(format: "%.2fkm", distance)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: startDate)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var category: WorkoutCategory {
        switch type {
        case .run, .walk, .cycle, .swim:
            return .cardio
        case .hiit:
            return .highIntensity
        case .strength:
            return .strength
        case .yoga:
            return .recovery
        case .other:
            return .mixed
        }
    }
}

// MARK: - Workout Type

enum WorkoutType: String, Codable, CaseIterable {
    case run = "Run"
    case walk = "Walk"
    case cycle = "Cycle"
    case swim = "Swim"
    case hiit = "HIIT"
    case strength = "Strength"
    case yoga = "Yoga"
    case other = "Other"

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "bicycle"
        case .swim: return "figure.pool.swim"
        case .hiit: return "flame.fill"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.mind.and.body"
        case .other: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Workout Intensity

enum WorkoutIntensity: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case max = "Max"

    var description: String {
        switch self {
        case .low: return "Easy effort, recovery pace"
        case .moderate: return "Steady effort, conversational"
        case .high: return "Challenging, focused effort"
        case .max: return "All-out, peak performance"
        }
    }
}

// MARK: - Workout Category

enum WorkoutCategory: String, Codable {
    case cardio = "Cardio"
    case strength = "Strength"
    case highIntensity = "High Intensity"
    case recovery = "Recovery"
    case mixed = "Mixed"

    var color: String {
        switch self {
        case .cardio: return "blue"
        case .strength: return "purple"
        case .highIntensity: return "orange"
        case .recovery: return "green"
        case .mixed: return "gray"
        }
    }
}

// MARK: - Hydration Level

enum HydrationLevel: String, Codable, CaseIterable {
    case poor = "Poor"
    case adequate = "Adequate"
    case good = "Good"
    case excellent = "Excellent"
}

// MARK: - Nutrition Status

enum NutritionStatus: String, Codable, CaseIterable {
    case fasted = "Fasted"
    case lightMeal = "Light meal"
    case fullMeal = "Full meal"
    case wellFueled = "Well fueled"
}

// MARK: - Perceived Effort

enum PerceivedEffort: Int, Codable, CaseIterable {
    case veryLight = 1
    case light = 2
    case moderate = 3
    case hard = 4
    case veryHard = 5

    var label: String {
        switch self {
        case .veryLight: return "Very light"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        case .veryHard: return "Very hard"
        }
    }

    var description: String {
        switch self {
        case .veryLight: return "Could do this all day"
        case .light: return "Comfortable, easy conversation"
        case .moderate: return "Steady, focused effort"
        case .hard: return "Challenging, short phrases only"
        case .veryHard: return "Maximum effort, can't talk"
        }
    }
}
