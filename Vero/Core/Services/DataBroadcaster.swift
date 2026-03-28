//
//  DataBroadcaster.swift
//  Insio Health
//
//  UNIFIED DATA PIPELINE
//  =====================
//  This is the SINGLE source of truth for data change notifications.
//
//  ALL logged metrics MUST go through this path:
//  1. Log action → save locally → broadcast → UI refresh
//
//  ARCHITECTURE:
//  - Singleton broadcaster that all saves notify
//  - All ViewModels subscribe to relevant changes
//  - Home and Trends stay in sync automatically
//
//  SUPPORTED METRICS:
//  - workouts
//  - sleep
//  - hydration (water)
//  - weight
//  - calories / daily context
//  - check-ins
//

import Foundation
import Combine

// MARK: - Data Change Types

/// Types of data changes that can be broadcast
enum DataChangeType: String, CaseIterable {
    case workout = "workout"
    case sleep = "sleep"
    case hydration = "hydration"
    case weight = "weight"
    case calories = "calories"
    case dailyContext = "dailyContext"
    case checkIn = "checkIn"
    case recovery = "recovery"

    /// All types that should trigger Home refresh
    static var homeRefreshTypes: [DataChangeType] {
        [.workout, .sleep, .hydration, .weight, .dailyContext, .checkIn]
    }

    /// All types that should trigger Trends refresh
    static var trendsRefreshTypes: [DataChangeType] {
        [.workout, .sleep, .hydration, .weight, .calories, .dailyContext, .checkIn, .recovery]
    }
}

/// A data change event
struct DataChangeEvent {
    let type: DataChangeType
    let timestamp: Date
    let metadata: [String: Any]?

    init(type: DataChangeType, metadata: [String: Any]? = nil) {
        self.type = type
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Data Broadcaster

/// Singleton that broadcasts all data changes.
/// Subscribe to receive notifications when any metric is logged.
@MainActor
final class DataBroadcaster: ObservableObject {

    // MARK: - Singleton

    static let shared = DataBroadcaster()

    // MARK: - Publishers

    /// Publisher for all data changes
    let dataChanged = PassthroughSubject<DataChangeEvent, Never>()

    /// Publisher for Home-relevant changes
    var homeDataChanged: AnyPublisher<DataChangeEvent, Never> {
        dataChanged
            .filter { DataChangeType.homeRefreshTypes.contains($0.type) }
            .eraseToAnyPublisher()
    }

    /// Publisher for Trends-relevant changes
    var trendsDataChanged: AnyPublisher<DataChangeEvent, Never> {
        dataChanged
            .filter { DataChangeType.trendsRefreshTypes.contains($0.type) }
            .eraseToAnyPublisher()
    }

    // MARK: - Published State

    /// Last change timestamp (for debugging)
    @Published private(set) var lastChangeTimestamp: Date?
    @Published private(set) var lastChangeType: DataChangeType?

    // MARK: - Initialization

    private init() {
        print("📡 DataBroadcaster: initialized")
    }

    // MARK: - Broadcast Methods

    /// Broadcast that a workout was saved
    func workoutSaved(id: UUID? = nil) {
        broadcast(.workout, metadata: id.map { ["id": $0.uuidString] })
    }

    /// Broadcast that sleep data was saved
    func sleepSaved(hours: Double? = nil) {
        broadcast(.sleep, metadata: hours.map { ["hours": $0] })
    }

    /// Broadcast that hydration data was saved
    func hydrationSaved(liters: Double? = nil) {
        broadcast(.hydration, metadata: liters.map { ["liters": $0] })
    }

    /// Broadcast that weight was saved
    func weightSaved(kg: Double? = nil) {
        broadcast(.weight, metadata: kg.map { ["kg": $0] })
    }

    /// Broadcast that calories/nutrition was saved
    func caloriesSaved(calories: Int? = nil) {
        broadcast(.calories, metadata: calories.map { ["calories": $0] })
    }

    /// Broadcast that daily context was saved (may include multiple metrics)
    func dailyContextSaved() {
        broadcast(.dailyContext)
    }

    /// Broadcast that a check-in was saved
    func checkInSaved(workoutId: UUID? = nil) {
        broadcast(.checkIn, metadata: workoutId.map { ["workoutId": $0.uuidString] })
    }

    /// Broadcast that recovery data was saved
    func recoverySaved() {
        broadcast(.recovery)
    }

    // MARK: - Private

    private func broadcast(_ type: DataChangeType, metadata: [String: Any]? = nil) {
        let event = DataChangeEvent(type: type, metadata: metadata)

        // Update state
        lastChangeTimestamp = event.timestamp
        lastChangeType = type

        // Log for debugging
        print("📡 ════════════════════════════════════════════════════════")
        print("📡 DATA BROADCAST: \(type.rawValue.uppercased())")
        print("📡 Timestamp: \(event.timestamp)")
        if let meta = metadata {
            print("📡 Metadata: \(meta)")
        }
        print("📡 ════════════════════════════════════════════════════════")

        // Publish event
        dataChanged.send(event)
    }
}

// MARK: - Convenience Extensions

extension DataBroadcaster {

    /// Subscribe to all home-relevant data changes
    func subscribeToHomeChanges(
        handler: @escaping (DataChangeEvent) -> Void
    ) -> AnyCancellable {
        homeDataChanged.sink(receiveValue: handler)
    }

    /// Subscribe to all trends-relevant data changes
    func subscribeToTrendsChanges(
        handler: @escaping (DataChangeEvent) -> Void
    ) -> AnyCancellable {
        trendsDataChanged.sink(receiveValue: handler)
    }

    /// Subscribe to specific data type
    func subscribe(
        to type: DataChangeType,
        handler: @escaping (DataChangeEvent) -> Void
    ) -> AnyCancellable {
        dataChanged
            .filter { $0.type == type }
            .sink(receiveValue: handler)
    }
}
