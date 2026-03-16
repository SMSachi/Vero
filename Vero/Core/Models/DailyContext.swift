//
//  DailyContext.swift
//  Vero
//

import Foundation

struct DailyContext: Identifiable, Codable {
    let id: UUID
    let date: Date
    let sleepHours: Double
    let sleepQuality: SleepQuality
    let stressLevel: StressLevel
    let energyLevel: EnergyLevel
    let restingHeartRate: Int?
    let hrvScore: Double?
    let readinessScore: Int

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

enum SleepQuality: String, Codable, CaseIterable {
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"

    var icon: String {
        switch self {
        case .poor: return "moon.zzz"
        case .fair: return "moon"
        case .good: return "moon.stars"
        case .excellent: return "moon.stars.fill"
        }
    }
}

enum StressLevel: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
}

enum EnergyLevel: String, Codable, CaseIterable {
    case depleted = "Depleted"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case peak = "Peak"

    var icon: String {
        switch self {
        case .depleted: return "battery.0percent"
        case .low: return "battery.25percent"
        case .moderate: return "battery.50percent"
        case .high: return "battery.75percent"
        case .peak: return "battery.100percent"
        }
    }
}
