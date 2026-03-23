//
//  NutritionEntry.swift
//  Insio Health
//
//  Simple nutrition logging model for water, calories, and macros.
//  Designed to be quick to log without requiring a full meal database.
//
//  USAGE:
//  - Water: Track daily water intake in ml
//  - Calories: Track total daily calories
//  - Macros: Track protein, carbs, fat in grams
//
//  This data feeds into Plus/Pro tier insights.
//

import Foundation
import SwiftData

// MARK: - Nutrition Entry (SwiftData)

@Model
final class NutritionEntry {
    // MARK: - Core Properties

    /// Unique identifier
    var id: UUID

    /// Date of the entry (normalized to start of day)
    var date: Date

    /// Water intake in milliliters
    var waterIntakeMl: Int?

    /// Total calories for the day
    var calories: Int?

    /// Protein in grams
    var proteinGrams: Int?

    /// Carbohydrates in grams
    var carbsGrams: Int?

    /// Fat in grams
    var fatGrams: Int?

    /// Notes or meal description
    var notes: String?

    /// When this entry was created
    var createdAt: Date

    /// When this entry was last updated
    var updatedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        waterIntakeMl: Int? = nil,
        calories: Int? = nil,
        proteinGrams: Int? = nil,
        carbsGrams: Int? = nil,
        fatGrams: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.waterIntakeMl = waterIntakeMl
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Whether this entry has any water data
    var hasWaterData: Bool {
        waterIntakeMl != nil && waterIntakeMl! > 0
    }

    /// Whether this entry has any macro data
    var hasMacroData: Bool {
        (calories != nil && calories! > 0) ||
        (proteinGrams != nil && proteinGrams! > 0)
    }

    /// Whether this entry has any data at all
    var hasData: Bool {
        hasWaterData || hasMacroData
    }

    /// Water intake in liters
    var waterIntakeLiters: Double? {
        guard let ml = waterIntakeMl else { return nil }
        return Double(ml) / 1000.0
    }

    /// Hydration status based on water intake
    var hydrationStatus: HydrationStatus {
        guard let ml = waterIntakeMl else { return .unknown }
        switch ml {
        case 0..<1000: return .low
        case 1000..<2000: return .moderate
        case 2000..<3000: return .good
        default: return .excellent
        }
    }

    // MARK: - Update Methods

    /// Add water intake
    func addWater(_ ml: Int) {
        waterIntakeMl = (waterIntakeMl ?? 0) + ml
        updatedAt = Date()
    }

    /// Set macros
    func setMacros(calories: Int?, protein: Int?, carbs: Int?, fat: Int?) {
        if let c = calories { self.calories = c }
        if let p = protein { self.proteinGrams = p }
        if let c = carbs { self.carbsGrams = c }
        if let f = fat { self.fatGrams = f }
        updatedAt = Date()
    }

    // MARK: - Conversion

    /// Convert to NutritionContext for analysis
    func toNutritionContext() -> NutritionContext {
        NutritionContext(
            waterIntakeMl: waterIntakeMl,
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            date: date
        )
    }
}

// MARK: - Quick Add Amounts

enum WaterQuickAdd: Int, CaseIterable {
    case glass = 250      // 250ml glass
    case bottle = 500     // 500ml bottle
    case largeBottle = 750 // 750ml large bottle
    case liter = 1000     // 1L

    var displayName: String {
        switch self {
        case .glass: return "Glass"
        case .bottle: return "Bottle"
        case .largeBottle: return "Large"
        case .liter: return "1 Liter"
        }
    }

    var displayAmount: String {
        switch self {
        case .glass: return "250ml"
        case .bottle: return "500ml"
        case .largeBottle: return "750ml"
        case .liter: return "1L"
        }
    }

    var icon: String {
        switch self {
        case .glass: return "cup.and.saucer"
        case .bottle: return "waterbottle"
        case .largeBottle: return "waterbottle.fill"
        case .liter: return "drop.fill"
        }
    }
}

// MARK: - Meal Type (Optional Categorization)

enum MealType: String, Codable, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    case preworkout = "pre_workout"
    case postworkout = "post_workout"

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .preworkout: return "Pre-Workout"
        case .postworkout: return "Post-Workout"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .snack: return "carrot"
        case .preworkout: return "figure.run"
        case .postworkout: return "figure.cooldown"
        }
    }
}
