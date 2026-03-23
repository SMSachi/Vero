//
//  NextDayRecovery.swift
//  Insio Health
//

import Foundation

struct NextDayRecovery: Identifiable, Codable {
    let id: UUID
    let date: Date
    let overallScore: Int // 0-100
    let muscleRecovery: RecoveryStatus
    let cardioRecovery: RecoveryStatus
    let mentalRecovery: RecoveryStatus
    let recommendation: RecoveryRecommendation
    let suggestedWorkoutTypes: [WorkoutType]
    let interpretation: String

    var scoreCategory: RecoveryCategory {
        switch overallScore {
        case 0..<40: return .poor
        case 40..<60: return .moderate
        case 60..<80: return .good
        default: return .excellent
        }
    }
}

enum RecoveryStatus: String, Codable, CaseIterable {
    case recovering = "Recovering"
    case partial = "Partial"
    case ready = "Ready"
    case optimal = "Optimal"

    var icon: String {
        switch self {
        case .recovering: return "arrow.triangle.2.circlepath"
        case .partial: return "circle.lefthalf.filled"
        case .ready: return "checkmark.circle"
        case .optimal: return "checkmark.circle.fill"
        }
    }
}

enum RecoveryCategory: String, Codable {
    case poor = "Poor"
    case moderate = "Moderate"
    case good = "Good"
    case excellent = "Excellent"

    var color: String {
        switch self {
        case .poor: return "red"
        case .moderate: return "yellow"
        case .good: return "mint"
        case .excellent: return "green"
        }
    }
}

enum RecoveryRecommendation: String, Codable, CaseIterable {
    case rest = "Rest Day"
    case lightActivity = "Light Activity"
    case moderateTraining = "Moderate Training"
    case fullTraining = "Full Training"
    case pushHard = "Push Hard"

    var description: String {
        switch self {
        case .rest:
            return "Your body needs recovery. Focus on sleep and nutrition."
        case .lightActivity:
            return "Try gentle movement like walking or stretching."
        case .moderateTraining:
            return "You're ready for a standard workout session."
        case .fullTraining:
            return "Good to go for your planned training."
        case .pushHard:
            return "Optimal recovery! Great day for a challenging session."
        }
    }
}
