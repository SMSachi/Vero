//
//  CheckIn.swift
//  Insio Health
//

import Foundation

struct CheckIn: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mood: Mood
    let energyLevel: EnergyLevel
    let soreness: SorenessLevel
    let motivation: MotivationLevel
    let notes: String?

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum Mood: String, Codable, CaseIterable {
    case struggling = "Struggling"
    case okay = "Okay"
    case good = "Good"
    case great = "Great"
    case amazing = "Amazing"

    var icon: String {
        switch self {
        case .struggling: return "cloud.rain"
        case .okay: return "cloud"
        case .good: return "cloud.sun"
        case .great: return "sun.max"
        case .amazing: return "sparkles"
        }
    }

    var emoji: String {
        switch self {
        case .struggling: return "😔"
        case .okay: return "😐"
        case .good: return "🙂"
        case .great: return "😊"
        case .amazing: return "🤩"
        }
    }
}

enum SorenessLevel: String, Codable, CaseIterable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case significant = "Significant"
    case severe = "Severe"
}

enum MotivationLevel: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
}
