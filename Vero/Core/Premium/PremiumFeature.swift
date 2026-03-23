//
//  PremiumFeature.swift
//  Insio Health
//
//  Defines feature gating across Free, Plus, and Pro tiers.
//
//  FREE TIER (after 3-day trial):
//  - Basic manual workout logging
//  - Apple Health connection
//  - Basic workout list/history (7 days)
//  - No trends or AI
//
//  PLUS TIER ($4.99/month):
//  - Weekly AI trend summary
//  - Nutrition/water-aware weekly insights
//  - 30-day trends and history
//
//  PRO TIER ($12.99/month):
//  - AI summary after every workout
//  - Weekly/monthly AI trend summaries
//  - Deeper pattern analysis
//  - Unlimited history
//  - Advanced insights
//

import Foundation

// MARK: - Premium Feature

/// Defines all features that can be gated by subscription tier
enum PremiumFeature: String, CaseIterable, Identifiable {
    // MARK: AI Features
    case aiWorkoutSummaries = "ai_workout_summaries"        // Pro only
    case aiWeeklyTrends = "ai_weekly_trends"                // Plus+
    case aiMonthlyTrends = "ai_monthly_trends"              // Pro only
    case aiPatternAnalysis = "ai_pattern_analysis"          // Pro only

    // MARK: History & Data
    case extendedHistory = "extended_history"               // Plus+ (30 days)
    case unlimitedHistory = "unlimited_history"             // Pro only
    case exportData = "export_data"                         // Pro only

    // MARK: Trends & Insights
    case basicTrends = "basic_trends"                       // Free (7 days)
    case deeperTrends = "deeper_trends"                     // Plus+
    case advancedInsights = "advanced_insights"             // Pro only
    case nutritionAwareTrends = "nutrition_aware_trends"    // Plus+

    // MARK: Analysis
    case deeperPatternAnalysis = "deeper_pattern_analysis"  // Pro only
    case recoveryPredictions = "recovery_predictions"       // Pro only
    case workoutRecommendations = "workout_recommendations" // Pro only

    var id: String { rawValue }

    /// Minimum tier required for this feature
    var requiredTier: SubscriptionTier {
        switch self {
        // Free features
        case .basicTrends:
            return .free

        // Plus features
        case .aiWeeklyTrends,
             .extendedHistory,
             .deeperTrends,
             .nutritionAwareTrends:
            return .plus

        // Pro features
        case .aiWorkoutSummaries,
             .aiMonthlyTrends,
             .aiPatternAnalysis,
             .unlimitedHistory,
             .exportData,
             .advancedInsights,
             .deeperPatternAnalysis,
             .recoveryPredictions,
             .workoutRecommendations:
            return .pro
        }
    }

    /// Human-readable name for the feature
    var displayName: String {
        switch self {
        case .aiWorkoutSummaries:
            return "AI Workout Summaries"
        case .aiWeeklyTrends:
            return "Weekly AI Insights"
        case .aiMonthlyTrends:
            return "Monthly AI Reports"
        case .aiPatternAnalysis:
            return "AI Pattern Analysis"
        case .extendedHistory:
            return "30-Day History"
        case .unlimitedHistory:
            return "Unlimited History"
        case .exportData:
            return "Export Data"
        case .basicTrends:
            return "Basic Trends"
        case .deeperTrends:
            return "Deeper Trends"
        case .advancedInsights:
            return "Advanced Insights"
        case .nutritionAwareTrends:
            return "Nutrition-Aware Insights"
        case .deeperPatternAnalysis:
            return "Deep Pattern Analysis"
        case .recoveryPredictions:
            return "Recovery Predictions"
        case .workoutRecommendations:
            return "Smart Recommendations"
        }
    }

    /// Description of what this feature provides
    var description: String {
        switch self {
        case .aiWorkoutSummaries:
            return "Get personalized AI summaries after every workout"
        case .aiWeeklyTrends:
            return "Weekly AI-generated insights on your fitness progress"
        case .aiMonthlyTrends:
            return "Comprehensive monthly AI reports and analysis"
        case .aiPatternAnalysis:
            return "AI identifies training patterns you might miss"
        case .extendedHistory:
            return "Access up to 30 days of workout history"
        case .unlimitedHistory:
            return "Access your complete workout history"
        case .exportData:
            return "Export your workout data for use in other apps"
        case .basicTrends:
            return "View your last 7 days of workout trends"
        case .deeperTrends:
            return "Analyze trends over the past month"
        case .advancedInsights:
            return "Deeper analysis with recovery and performance context"
        case .nutritionAwareTrends:
            return "Insights that factor in your nutrition and hydration"
        case .deeperPatternAnalysis:
            return "Advanced pattern detection across workout types"
        case .recoveryPredictions:
            return "Predictive recovery scores based on training load"
        case .workoutRecommendations:
            return "AI-powered suggestions for your next workout"
        }
    }

    /// Icon for this feature
    var icon: String {
        switch self {
        case .aiWorkoutSummaries:
            return "sparkles"
        case .aiWeeklyTrends:
            return "chart.line.uptrend.xyaxis"
        case .aiMonthlyTrends:
            return "calendar.badge.checkmark"
        case .aiPatternAnalysis:
            return "brain.head.profile"
        case .extendedHistory:
            return "clock"
        case .unlimitedHistory:
            return "clock.arrow.circlepath"
        case .exportData:
            return "square.and.arrow.up"
        case .basicTrends:
            return "chart.bar"
        case .deeperTrends:
            return "chart.bar.xaxis"
        case .advancedInsights:
            return "lightbulb.fill"
        case .nutritionAwareTrends:
            return "fork.knife"
        case .deeperPatternAnalysis:
            return "waveform.path.ecg"
        case .recoveryPredictions:
            return "heart.text.square"
        case .workoutRecommendations:
            return "figure.run"
        }
    }
}

// MARK: - Tier Limits (Legacy Compatibility)

enum FreeTierLimits {
    /// Maximum days of history visible in free tier
    static let historyDays = InsioConfig.TierLimits.freeHistoryDays

    /// Maximum number of workouts visible in free tier
    static let maxWorkoutsVisible = InsioConfig.TierLimits.freeMaxWorkoutsVisible

    /// Whether basic insights are available
    static let basicInsightsEnabled = true

    /// Whether manual logging is available
    static let manualLoggingEnabled = true

    /// Whether Apple Health connection is available
    static let healthKitEnabled = true
}

// MARK: - Tier Benefits (for Paywall Display)

struct TierBenefits {

    /// Benefits for Plus tier (shown on paywall)
    static let plusHighlights: [PremiumFeature] = [
        .aiWeeklyTrends,
        .nutritionAwareTrends,
        .extendedHistory,
        .deeperTrends
    ]

    /// Benefits for Pro tier (shown on paywall)
    static let proHighlights: [PremiumFeature] = [
        .aiWorkoutSummaries,
        .aiWeeklyTrends,
        .aiMonthlyTrends,
        .unlimitedHistory,
        .advancedInsights,
        .workoutRecommendations
    ]

    /// All features available in Plus tier
    static let plusFeatures: [PremiumFeature] = PremiumFeature.allCases.filter {
        $0.requiredTier <= .plus
    }

    /// All features available in Pro tier (all features)
    static let proFeatures: [PremiumFeature] = PremiumFeature.allCases

    /// Features exclusive to Pro (not in Plus)
    static let proExclusiveFeatures: [PremiumFeature] = PremiumFeature.allCases.filter {
        $0.requiredTier == .pro
    }
}

// MARK: - Legacy Compatibility

struct PremiumBenefits {
    /// Legacy: highlights for paywall (maps to Pro)
    static let highlights = TierBenefits.proHighlights

    /// Legacy: all premium features
    static let allFeatures = TierBenefits.proFeatures
}
