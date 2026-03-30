//
//  UnitPreferences.swift
//  Insio Health
//
//  Global unit preferences for metric/imperial system.
//  Affects: weight (kg/lb), distance (km/mi), hydration (L/oz)
//
//  USAGE:
//  - Views should use @StateObject or @ObservedObject with UnitPreferences.shared
//  - Call formatWeight(), formatVolume() etc. to display values
//  - Internal storage is always metric (kg, liters, km)
//  - Conversion happens only at display time
//

import Foundation
import SwiftUI
import Combine

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "metric"
    case imperial = "imperial"

    var id: String { rawValue }

    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lb"
        }
    }

    var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    var volumeUnit: String {
        switch self {
        case .metric: return "L"
        case .imperial: return "oz"
        }
    }

    var volumeUnitShort: String {
        switch self {
        case .metric: return "L"
        case .imperial: return "fl oz"
        }
    }

    var displayName: String {
        switch self {
        case .metric: return "Metric (kg, km, L)"
        case .imperial: return "Imperial (lb, mi, oz)"
        }
    }
}

// MARK: - Unit Preferences

@MainActor
final class UnitPreferences: ObservableObject {

    // MARK: - Singleton

    static let shared = UnitPreferences()

    // MARK: - Published (triggers UI updates)

    @Published private(set) var unitSystem: UnitSystem = .metric

    // MARK: - Storage Key

    private let storageKey = "unitSystem"

    // MARK: - Conversion Constants

    static let kgToLb: Double = 2.20462
    static let lbToKg: Double = 0.453592
    static let kmToMi: Double = 0.621371
    static let miToKm: Double = 1.60934
    static let litersToOz: Double = 33.814
    static let ozToLiters: Double = 0.0295735

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let system = UnitSystem(rawValue: raw) {
            unitSystem = system
        }
        print("⚙️ UnitPreferences: Initialized with \(unitSystem.rawValue)")
    }

    // MARK: - Set Unit System

    func setUnitSystem(_ system: UnitSystem) {
        guard system != unitSystem else { return }

        // Save to UserDefaults
        UserDefaults.standard.set(system.rawValue, forKey: storageKey)

        // Update published property (triggers all observers)
        unitSystem = system

        print("⚙️ UnitPreferences: Changed to \(system.rawValue)")
    }

    // MARK: - Convenience Accessors

    var isMetric: Bool { unitSystem == .metric }
    var isImperial: Bool { unitSystem == .imperial }

    var weightUnit: String { unitSystem.weightUnit }
    var volumeUnit: String { unitSystem.volumeUnit }
    var distanceUnit: String { unitSystem.distanceUnit }

    // MARK: - Weight Conversion (stored in kg)

    /// Convert kg to display unit value
    func displayWeight(_ kg: Double) -> Double {
        switch unitSystem {
        case .metric: return kg
        case .imperial: return kg * Self.kgToLb
        }
    }

    /// Format weight with unit (input is always kg)
    func formatWeight(_ kg: Double, decimals: Int = 1) -> String {
        guard kg > 0 else { return "—" }
        let value = displayWeight(kg)
        return String(format: "%.\(decimals)f %@", value, unitSystem.weightUnit)
    }

    /// Format weight value only (no unit suffix)
    func formatWeightValue(_ kg: Double, decimals: Int = 1) -> String {
        guard kg > 0 else { return "—" }
        let value = displayWeight(kg)
        return String(format: "%.\(decimals)f", value)
    }

    /// Convert from display unit to kg (for storage)
    func weightToKg(_ displayValue: Double) -> Double {
        switch unitSystem {
        case .metric: return displayValue
        case .imperial: return displayValue * Self.lbToKg
        }
    }

    /// Get weight range for slider based on current unit
    var weightSliderRange: ClosedRange<Double> {
        switch unitSystem {
        case .metric: return 30...200  // kg
        case .imperial: return 66...440  // lb
        }
    }

    /// Get weight step for slider
    var weightSliderStep: Double {
        switch unitSystem {
        case .metric: return 0.5
        case .imperial: return 1.0
        }
    }

    // MARK: - Volume Conversion (stored in liters)

    /// Convert liters to display unit value
    func displayVolume(_ liters: Double) -> Double {
        switch unitSystem {
        case .metric: return liters
        case .imperial: return liters * Self.litersToOz
        }
    }

    /// Format volume with unit (input is always liters)
    func formatVolume(_ liters: Double, decimals: Int = 1) -> String {
        guard liters > 0 else { return "—" }
        let value = displayVolume(liters)
        return String(format: "%.\(decimals)f %@", value, unitSystem.volumeUnit)
    }

    /// Format volume value only (no unit suffix)
    func formatVolumeValue(_ liters: Double, decimals: Int = 1) -> String {
        guard liters > 0 else { return "—" }
        let value = displayVolume(liters)
        return String(format: "%.\(decimals)f", value)
    }

    /// Convert from display unit to liters (for storage)
    func volumeToLiters(_ displayValue: Double) -> Double {
        switch unitSystem {
        case .metric: return displayValue
        case .imperial: return displayValue * Self.ozToLiters
        }
    }

    /// Get volume range for slider based on current unit
    var volumeSliderRange: ClosedRange<Double> {
        switch unitSystem {
        case .metric: return 0...5  // liters
        case .imperial: return 0...170  // fl oz (approx 5L)
        }
    }

    /// Get volume step for slider
    var volumeSliderStep: Double {
        switch unitSystem {
        case .metric: return 0.25
        case .imperial: return 8.0  // 8 oz = ~1 cup
        }
    }

    /// Get volume quick-add amounts (in display units)
    var volumeQuickAddAmounts: [(label: String, displayValue: Double)] {
        switch unitSystem {
        case .metric:
            return [
                ("+0.25L", 0.25),
                ("+0.5L", 0.5),
                ("+1L", 1.0)
            ]
        case .imperial:
            return [
                ("+8oz", 8.0),
                ("+16oz", 16.0),
                ("+32oz", 32.0)
            ]
        }
    }

    /// Daily hydration goal in display units
    var dailyHydrationGoal: Double {
        switch unitSystem {
        case .metric: return 2.5  // liters
        case .imperial: return 85.0  // ~2.5L in oz
        }
    }

    /// Daily hydration goal formatted
    var dailyHydrationGoalFormatted: String {
        switch unitSystem {
        case .metric: return "2.5 L"
        case .imperial: return "85 oz"
        }
    }

    // MARK: - Distance Conversion (stored in km)

    /// Convert km to display unit
    func displayDistance(_ km: Double) -> Double {
        switch unitSystem {
        case .metric: return km
        case .imperial: return km * Self.kmToMi
        }
    }

    /// Format distance with unit
    func formatDistance(_ km: Double, decimals: Int = 1) -> String {
        guard km > 0 else { return "—" }
        let value = displayDistance(km)
        return String(format: "%.\(decimals)f %@", value, unitSystem.distanceUnit)
    }
}
