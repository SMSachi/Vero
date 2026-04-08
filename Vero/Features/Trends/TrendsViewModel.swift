//
//  TrendsViewModel.swift
//  Insio Health
//
//  ViewModel for the Trends screen that manages trend analysis
//  and provides data to the view.
//
//  DATA FLOW:
//  - Subscribes to DataBroadcaster for automatic updates
//  - When any metric is logged, Trends refreshes automatically
//  - Uses same PersistenceService as Home for consistency
//

import Foundation
import SwiftUI
import Combine

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

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        print("📈 TrendsViewModel: init() - subscribing to DataBroadcaster")

        // Subscribe to trends-relevant data changes
        DataBroadcaster.shared.trendsDataChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                print("📊 ════════════════════════════════════════════════════")
                print("📊 TRENDS: REFRESH TRIGGERED (broadcast: \(event.type.rawValue))")
                print("📊 ════════════════════════════════════════════════════")
                Task { [weak self] in
                    await self?.loadTrends()
                }
            }
            .store(in: &cancellables)
    }

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
        print("📊 TRENDS REFRESH START")
        isLoading = true

        // Run analysis - reads from same PersistenceService as Home
        let result = TrendAnalysisEngine.analyze(timeframe: selectedTimeframe.days)

        // Update state
        analysisResult = result
        hasRealData = result.workoutCount > 0

        isLoading = false

        print("📊 ════════════════════════════════════════════════════")
        print("📊 TRENDS REFRESH COMPLETE")
        print("📊 Timeframe: \(selectedTimeframe.days) days")
        print("📊 Workouts: \(result.workoutCount)")
        print("📊 Metrics: \(result.metricTrends.count)")
        print("📊 ════════════════════════════════════════════════════")
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
