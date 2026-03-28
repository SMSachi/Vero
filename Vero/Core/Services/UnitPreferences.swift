//
//  UnitPreferences.swift
//  Insio Health
//
//  Global unit preferences for metric/imperial system.
//  Affects: weight (kg/lb), distance (km/mi), hydration (L/oz)
//

import Foundation
import SwiftUI

// MARK: - Unit System

enum UnitSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

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

    // MARK: - Storage

    @AppStorage("unitSystem") private var unitSystemRaw: String = UnitSystem.metric.rawValue

    // MARK: - Published

    @Published private(set) var unitSystem: UnitSystem = .metric

    // MARK: - Conversion Constants

    static let kgToLb: Double = 2.20462
    static let lbToKg: Double = 0.453592
    static let kmToMi: Double = 0.621371
    static let miToKm: Double = 1.60934
    static let litersToOz: Double = 33.814
    static let ozToLiters: Double = 0.0295735

    // MARK: - Initialization

    private init() {
        unitSystem = UnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    // MARK: - Set Unit System

    func setUnitSystem(_ system: UnitSystem) {
        unitSystemRaw = system.rawValue
        unitSystem = system
        print("⚙️ UnitPreferences: Changed to \(system.rawValue)")
    }

    // MARK: - Weight Conversion

    /// Convert kg to display unit
    func displayWeight(_ kg: Double) -> Double {
        switch unitSystem {
        case .metric: return kg
        case .imperial: return kg * Self.kgToLb
        }
    }

    /// Format weight with unit
    func formatWeight(_ kg: Double, decimals: Int = 1) -> String {
        let value = displayWeight(kg)
        return String(format: "%.\(decimals)f %@", value, unitSystem.weightUnit)
    }

    /// Convert from display unit to kg
    func weightToKg(_ value: Double) -> Double {
        switch unitSystem {
        case .metric: return value
        case .imperial: return value * Self.lbToKg
        }
    }

    // MARK: - Distance Conversion

    /// Convert km to display unit
    func displayDistance(_ km: Double) -> Double {
        switch unitSystem {
        case .metric: return km
        case .imperial: return km * Self.kmToMi
        }
    }

    /// Format distance with unit
    func formatDistance(_ km: Double, decimals: Int = 1) -> String {
        let value = displayDistance(km)
        return String(format: "%.\(decimals)f %@", value, unitSystem.distanceUnit)
    }

    // MARK: - Volume Conversion

    /// Convert liters to display unit
    func displayVolume(_ liters: Double) -> Double {
        switch unitSystem {
        case .metric: return liters
        case .imperial: return liters * Self.litersToOz
        }
    }

    /// Format volume with unit
    func formatVolume(_ liters: Double, decimals: Int = 1) -> String {
        let value = displayVolume(liters)
        return String(format: "%.\(decimals)f %@", value, unitSystem.volumeUnit)
    }

    /// Convert from display unit to liters
    func volumeToLiters(_ value: Double) -> Double {
        switch unitSystem {
        case .metric: return value
        case .imperial: return value * Self.ozToLiters
        }
    }
}

// MARK: - View Modifier for Easy Access

extension View {
    /// Access unit preferences in a view
    func withUnitPreferences(_ action: (UnitPreferences) -> Void) -> some View {
        action(UnitPreferences.shared)
        return self
    }
}
