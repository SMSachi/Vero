//
//  NutritionService.swift
//  Insio Health
//
//  Service for managing nutrition/water logging.
//  Provides simple CRUD operations and aggregation for trends.
//

import Foundation
import SwiftData

// MARK: - Nutrition Service

@MainActor
final class NutritionService: ObservableObject {

    // MARK: - Singleton

    static let shared = NutritionService()

    // MARK: - Published State

    @Published private(set) var todayEntry: NutritionEntry?
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private var modelContext: ModelContext?

    // MARK: - Initialization

    private init() {
        // Context will be set when app initializes SwiftData
    }

    /// Configure with SwiftData context
    func configure(with context: ModelContext) {
        self.modelContext = context
        loadTodayEntry()
    }

    // MARK: - Today's Entry

    /// Load or create today's nutrition entry
    func loadTodayEntry() {
        guard let context = modelContext else {
            print("⚠️ NutritionService: No model context available")
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let descriptor = FetchDescriptor<NutritionEntry>(
            predicate: #Predicate<NutritionEntry> { entry in
                entry.date >= today && entry.date < tomorrow
            }
        )

        do {
            let entries = try context.fetch(descriptor)
            if let existing = entries.first {
                todayEntry = existing
            } else {
                // Create new entry for today
                let newEntry = NutritionEntry(date: Date())
                context.insert(newEntry)
                try context.save()
                todayEntry = newEntry
            }
            print("💧 NutritionService: Loaded today's entry")
        } catch {
            print("❌ NutritionService: Failed to load today's entry - \(error)")
        }
    }

    /// Get or create entry for today
    func getOrCreateTodayEntry() -> NutritionEntry? {
        if todayEntry == nil {
            loadTodayEntry()
        }
        return todayEntry
    }

    // MARK: - Water Logging

    /// Add water to today's entry
    func addWater(_ ml: Int) {
        guard let context = modelContext else { return }

        let entry = getOrCreateTodayEntry()
        entry?.addWater(ml)

        do {
            try context.save()
            print("💧 NutritionService: Added \(ml)ml water")
        } catch {
            print("❌ NutritionService: Failed to save water - \(error)")
        }
    }

    /// Set water intake directly
    func setWaterIntake(_ ml: Int) {
        guard let context = modelContext else { return }

        let entry = getOrCreateTodayEntry()
        entry?.waterIntakeMl = ml
        entry?.updatedAt = Date()

        do {
            try context.save()
            print("💧 NutritionService: Set water to \(ml)ml")
        } catch {
            print("❌ NutritionService: Failed to save water - \(error)")
        }
    }

    // MARK: - Macro Logging

    /// Log macros for today
    func logMacros(calories: Int?, protein: Int?, carbs: Int?, fat: Int?) {
        guard let context = modelContext else { return }

        let entry = getOrCreateTodayEntry()
        entry?.setMacros(calories: calories, protein: protein, carbs: carbs, fat: fat)

        do {
            try context.save()
            print("🍎 NutritionService: Logged macros")
        } catch {
            print("❌ NutritionService: Failed to save macros - \(error)")
        }
    }

    // MARK: - Historical Data

    /// Get entry for a specific date
    func getEntry(for date: Date) -> NutritionEntry? {
        guard let context = modelContext else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<NutritionEntry>(
            predicate: #Predicate<NutritionEntry> { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            print("❌ NutritionService: Failed to fetch entry - \(error)")
            return nil
        }
    }

    /// Get entries for a date range
    func getEntries(from startDate: Date, to endDate: Date) -> [NutritionEntry] {
        guard let context = modelContext else { return [] }

        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!

        let descriptor = FetchDescriptor<NutritionEntry>(
            predicate: #Predicate<NutritionEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ NutritionService: Failed to fetch entries - \(error)")
            return []
        }
    }

    // MARK: - Aggregation for Trends

    /// Get nutrition summary for the past N days
    func getNutritionSummary(days: Int) -> NutritionTrendSummary {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!

        let entries = getEntries(from: startDate, to: endDate)
        let entriesWithData = entries.filter { $0.hasData }

        guard !entriesWithData.isEmpty else {
            return NutritionTrendSummary(
                averageWaterIntakeMl: nil,
                averageCalories: nil,
                averageProtein: nil,
                averageCarbs: nil,
                daysTracked: 0
            )
        }

        // Calculate averages
        let waterEntries = entriesWithData.compactMap { $0.waterIntakeMl }
        let calorieEntries = entriesWithData.compactMap { $0.calories }
        let proteinEntries = entriesWithData.compactMap { $0.proteinGrams }
        let carbEntries = entriesWithData.compactMap { $0.carbsGrams }

        let avgWater = waterEntries.isEmpty ? nil : waterEntries.reduce(0, +) / waterEntries.count
        let avgCalories = calorieEntries.isEmpty ? nil : calorieEntries.reduce(0, +) / calorieEntries.count
        let avgProtein = proteinEntries.isEmpty ? nil : proteinEntries.reduce(0, +) / proteinEntries.count
        let avgCarbs = carbEntries.isEmpty ? nil : carbEntries.reduce(0, +) / carbEntries.count

        return NutritionTrendSummary(
            averageWaterIntakeMl: avgWater,
            averageCalories: avgCalories,
            averageProtein: avgProtein,
            averageCarbs: avgCarbs,
            daysTracked: entriesWithData.count
        )
    }

    /// Get NutritionContext for a specific date (for workout analysis)
    func getNutritionContext(for date: Date) -> NutritionContext? {
        let entry = getEntry(for: date)
        return entry?.toNutritionContext()
    }

    // MARK: - Cleanup

    /// Delete all nutrition entries (for account deletion)
    func deleteAllEntries() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<NutritionEntry>()

        do {
            let entries = try context.fetch(descriptor)
            for entry in entries {
                context.delete(entry)
            }
            try context.save()
            todayEntry = nil
            print("🗑️ NutritionService: Deleted all entries")
        } catch {
            print("❌ NutritionService: Failed to delete entries - \(error)")
        }
    }
}
