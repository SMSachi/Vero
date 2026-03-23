//
//  TrendsViewModel.swift
//  Insio Health
//
//  ViewModel for the Trends screen that manages trend analysis
//  and provides data to the view.
//

import Foundation
import SwiftUI

@MainActor
final class TrendsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Selected timeframe for analysis
    @Published var selectedTimeframe: TrendTimeframe = .month {
        didSet {
            if oldValue != selectedTimeframe {
                Task { await loadTrends() }
            }
        }
    }

    /// Analysis result with all trend data
    @Published private(set) var analysisResult: TrendAnalysisResult?

    /// Whether data is being loaded
    @Published private(set) var isLoading = false

    /// Whether we have any real data
    @Published private(set) var hasRealData = false

    // MARK: - Computed Properties

    /// Top insights for card display
    var topInsights: [GeneratedInsight] {
        analysisResult?.topInsights ?? []
    }

    /// Calendar data for activity display
    var calendarData: [CalendarDayData] {
        analysisResult?.calendarData ?? []
    }

    /// Metric trends for charts
    var metricTrends: [MetricTrend] {
        analysisResult?.metricTrends ?? []
    }

    /// Total workout count in timeframe
    var workoutCount: Int {
        analysisResult?.workoutCount ?? 0
    }

    /// Timeframe days value
    var timeframeDays: Int {
        selectedTimeframe.days
    }

    // MARK: - Methods

    /// Load trends for the selected timeframe
    func loadTrends() async {
        isLoading = true

        // Run analysis
        let result = TrendAnalysisEngine.analyze(timeframe: selectedTimeframe.days)

        // Update state
        analysisResult = result
        hasRealData = result.workoutCount > 0

        isLoading = false
    }

    /// Refresh trends
    func refresh() async {
        await loadTrends()
    }
}

// MARK: - Timeframe Extension

extension TrendTimeframe {
    var days: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        }
    }

    var subtitleText: String {
        switch self {
        case .week: return "Your patterns this week"
        case .twoWeeks: return "Your patterns over 2 weeks"
        case .month: return "Your patterns this month"
        }
    }
}
