//
//  TrendInsight.swift
//  Insio Health
//

import Foundation

struct TrendInsight: Identifiable, Codable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let metric: TrendMetric
    let changePercentage: Double
    let timeframe: Timeframe
    let createdAt: Date
    let priority: InsightPriority

    var isPositive: Bool {
        switch metric {
        case .restingHeartRate, .recoveryTime:
            return changePercentage < 0
        default:
            return changePercentage > 0
        }
    }

    var changeFormatted: String {
        let sign = changePercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", changePercentage))%"
    }
}

enum InsightType: String, Codable, CaseIterable {
    case improvement = "Improvement"
    case warning = "Warning"
    case milestone = "Milestone"
    case recommendation = "Recommendation"
    case pattern = "Pattern"

    var icon: String {
        switch self {
        case .improvement: return "arrow.up.right.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .milestone: return "star.fill"
        case .recommendation: return "lightbulb.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum TrendMetric: String, Codable, CaseIterable {
    case workoutFrequency = "Workout Frequency"
    case averageIntensity = "Average Intensity"
    case totalDuration = "Total Duration"
    case caloriesBurned = "Calories Burned"
    case restingHeartRate = "Resting Heart Rate"
    case hrvScore = "HRV Score"
    case sleepQuality = "Sleep Quality"
    case recoveryTime = "Recovery Time"
    case consistency = "Consistency"
}

enum Timeframe: String, Codable, CaseIterable {
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"
    case year = "This Year"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

enum InsightPriority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}
