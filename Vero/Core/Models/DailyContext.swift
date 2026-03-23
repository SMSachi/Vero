//
//  DailyContext.swift
//  Insio Health
//
//  Extended daily_contexts data model for Supabase sync.
//  Includes sleep, water, nutrition, and weight (if goal == weight_loss).
//

import Foundation

struct DailyContext: Identifiable, Codable {
    let id: UUID
    let date: Date

    // MARK: - Sleep Data
    var sleepHours: Double
    var sleepQuality: SleepQuality

    // MARK: - Energy & Stress
    var stressLevel: StressLevel
    var energyLevel: EnergyLevel

    // MARK: - Biometrics
    var restingHeartRate: Int?
    var hrvScore: Double?
    var readinessScore: Int

    // MARK: - Nutrition Data (extended)
    var waterIntakeMl: Int?
    var calories: Int?
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?

    // MARK: - Weight Data (only tracked if goal == weight_loss)
    var weightKg: Double?
    var bodyFatPercentage: Double?

    // MARK: - Computed Properties

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Water intake in liters
    var waterIntakeLiters: Double? {
        guard let ml = waterIntakeMl else { return nil }
        return Double(ml) / 1000.0
    }

    /// Whether nutrition data has been logged
    var hasNutritionData: Bool {
        waterIntakeMl != nil || calories != nil || proteinGrams != nil
    }

    /// Whether weight data has been logged
    var hasWeightData: Bool {
        weightKg != nil || bodyFatPercentage != nil
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
