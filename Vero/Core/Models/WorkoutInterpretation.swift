//
//  WorkoutInterpretation.swift
//  Insio Health
//
//  Result model returned by InterpretationEngine.
//  Contains all the generated text and metadata for displaying
//  workout insights in the UI.
//

import Foundation

// MARK: - Workout Interpretation

/// The result of interpreting a workout through the InterpretationEngine.
/// Contains all text needed to display insights in the UI.
struct WorkoutInterpretation {

    // MARK: - Main Text Content

    /// One-line summary for display on the dashboard card.
    /// Example: "42m run — solid effort with good recovery."
    let summaryText: String

    /// Multi-sentence explanation of what happened during the workout.
    /// Example: "During this 42-minute run, your heart rate averaged 145 bpm..."
    let interpretationText: String

    /// Actionable recommendation for what to do next.
    /// Example: "Allow 24-48 hours before another intense session."
    let recommendationText: String

    /// Bullet points highlighting key observations.
    /// Displayed in the expanded workout insight view.
    let bulletPoints: [InterpretationBullet]

    // MARK: - Metadata

    /// Overall sentiment of the interpretation.
    /// Used to style the UI (colors, icons, etc.)
    let sentiment: InterpretationSentiment

    /// All signals that contributed to this interpretation.
    /// Useful for debugging or showing detailed breakdown.
    let signals: [InterpretationSignal]

    // MARK: - Convenience Properties

    /// The primary message to show prominently.
    /// Uses summary for dashboard, interpretation for detail view.
    var primaryMessage: String {
        interpretationText
    }

    /// Whether this interpretation suggests caution.
    var needsCaution: Bool {
        sentiment == .caution
    }

    /// Whether this interpretation is positive.
    var isPositive: Bool {
        sentiment == .positive
    }

    /// Color name to use for sentiment-based styling.
    var sentimentColorName: String {
        switch sentiment {
        case .positive: return "olive"
        case .neutral: return "navy"
        case .caution: return "coral"
        }
    }
}

// MARK: - Static Helpers

extension WorkoutInterpretation {

    /// Create a default/fallback interpretation when no real data is available.
    static func placeholder(for workout: Workout) -> WorkoutInterpretation {
        WorkoutInterpretation(
            summaryText: "\(workout.durationFormatted) \(workout.type.rawValue.lowercased()) completed.",
            interpretationText: "Complete a check-in after your workout to receive personalized insights.",
            recommendationText: "Log how you felt to help us understand your training better.",
            bulletPoints: [],
            sentiment: .neutral,
            signals: []
        )
    }

    /// Create a simple interpretation from basic workout data only.
    static func basic(for workout: Workout) -> WorkoutInterpretation {
        let summary: String
        let interpretation: String
        let recommendation: String
        let sentiment: InterpretationSentiment

        switch workout.intensity {
        case .low:
            summary = "\(workout.durationFormatted) easy \(workout.type.rawValue.lowercased())."
            interpretation = "A gentle session that supported recovery without adding stress."
            recommendation = "Light activity tomorrow is fine."
            sentiment = .positive

        case .moderate:
            summary = "\(workout.durationFormatted) \(workout.type.rawValue.lowercased()) — solid effort."
            interpretation = "You maintained a sustainable pace that builds fitness over time."
            recommendation = "Similar effort tomorrow is fine if you're feeling good."
            sentiment = .neutral

        case .high:
            summary = "This \(workout.type.rawValue.lowercased()) pushed hard."
            interpretation = "Your cardiovascular system was challenged significantly during this session."
            recommendation = "Allow 24-48 hours before another intense session."
            sentiment = .caution

        case .max:
            summary = "Maximum effort \(workout.type.rawValue.lowercased())."
            interpretation = "This was an all-out session that significantly depleted your energy reserves."
            recommendation = "Prioritize rest and nutrition. Recovery is essential."
            sentiment = .caution
        }

        return WorkoutInterpretation(
            summaryText: summary,
            interpretationText: interpretation,
            recommendationText: recommendation,
            bulletPoints: [],
            sentiment: sentiment,
            signals: []
        )
    }
}
