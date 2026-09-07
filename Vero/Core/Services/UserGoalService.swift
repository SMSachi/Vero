//
//  UserGoalService.swift
//  WellPattern Health
//
//  Manages user goal state and weight UI visibility.
//  CRITICAL: Weight-related UI is ONLY shown when primaryGoal == .weightLoss
//
//  Usage:
//    UserGoalService.shared.shouldShowWeightUI // Check before showing weight UI
//    UserGoalService.shared.setPrimaryGoal(.weightLoss) // Set user's goal
//

import Foundation
import Combine

// MARK: - User Goal Service

@MainActor
final class UserGoalService: ObservableObject {

    // MARK: - Singleton

    static let shared = UserGoalService()

    // MARK: - Published State

    /// User's primary fitness goal
    @Published private(set) var primaryGoal: UserGoal?

    /// All selected goals (user can have multiple)
    @Published private(set) var selectedGoals: Set<UserGoal> = []

    // MARK: - Computed Properties

    /// CRITICAL: Weight UI is ONLY shown when goal == weight_loss
    var shouldShowWeightUI: Bool {
        primaryGoal == .weightLoss
    }

    /// Whether to emphasize nutrition tracking (weight loss or performance goals)
    var shouldEmphasizeNutrition: Bool {
        primaryGoal == .weightLoss || primaryGoal == .performance
    }

    /// Whether user has completed goal selection
    var hasSelectedGoal: Bool {
        primaryGoal != nil
    }

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let primaryGoalKey = "wellpattern_user_primary_goal"
    private let selectedGoalsKey = "wellpattern_user_selected_goals"

    // MARK: - Initialization

    private init() {
        loadSavedGoals()
    }

    // MARK: - Goal Management

    /// Set the user's primary goal
    func setPrimaryGoal(_ goal: UserGoal) {
        primaryGoal = goal
        saveGoals()
        #if DEBUG
        print("🎯 UserGoalService: Primary goal set to \(goal.rawValue)")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: shouldShowWeightUI = \(shouldShowWeightUI)")
        #endif
    }

    /// Set selected goals from onboarding
    func setSelectedGoals(_ goals: Set<UserGoal>, primaryGoal: UserGoal?) {
        self.selectedGoals = goals
        self.primaryGoal = primaryGoal ?? goals.first
        saveGoals()
        #if DEBUG
        print("🎯 UserGoalService: Selected \(goals.count) goals")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: Primary = \(self.primaryGoal?.rawValue ?? "none")")
        #endif
    }

    /// Clear all goals (for logout/account deletion)
    func clearGoals() {
        primaryGoal = nil
        selectedGoals = []
        userDefaults.removeObject(forKey: primaryGoalKey)
        userDefaults.removeObject(forKey: selectedGoalsKey)
        #if DEBUG
        print("🎯 UserGoalService: Goals cleared")
        #endif
    }

    // MARK: - Persistence

    private func saveGoals() {
        #if DEBUG
        print("🎯 UserGoalService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: SAVING GOALS")
        #endif

        if let primary = primaryGoal {
            userDefaults.set(primary.rawValue, forKey: primaryGoalKey)
            #if DEBUG
            print("🎯 UserGoalService: ✅ Saved primary goal: \(primary.rawValue)")
            #endif
        } else {
            userDefaults.removeObject(forKey: primaryGoalKey)
            #if DEBUG
            print("🎯 UserGoalService: ⚠️ No primary goal to save")
            #endif
        }

        let goalsArray = selectedGoals.map { $0.rawValue }
        userDefaults.set(goalsArray, forKey: selectedGoalsKey)
        #if DEBUG
        print("🎯 UserGoalService: ✅ Saved \(goalsArray.count) selected goals: \(goalsArray)")
        #endif

        // Force synchronize to ensure immediate persistence
        userDefaults.synchronize()
        #if DEBUG
        print("🎯 UserGoalService: ✅ UserDefaults synchronized")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: ══════════════════════════════════════════════════")
        #endif
    }

    private func loadSavedGoals() {
        #if DEBUG
        print("🎯 UserGoalService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: LOADING GOALS")
        #endif

        // Load primary goal
        let rawPrimary = userDefaults.string(forKey: primaryGoalKey)
        #if DEBUG
        print("🎯 UserGoalService: Raw primary from UserDefaults: \(rawPrimary ?? "nil")")
        #endif

        if let rawValue = rawPrimary,
           let goal = UserGoal(rawValue: rawValue) {
            primaryGoal = goal
            #if DEBUG
            print("🎯 UserGoalService: ✅ Loaded primary goal: \(goal.rawValue)")
            #endif
        } else {
            #if DEBUG
            print("🎯 UserGoalService: ⚠️ No primary goal found in UserDefaults")
            #endif
        }

        // Load selected goals
        let rawGoals = userDefaults.array(forKey: selectedGoalsKey) as? [String]
        #if DEBUG
        print("🎯 UserGoalService: Raw selected from UserDefaults: \(rawGoals ?? [])")
        #endif

        if let rawValues = rawGoals {
            selectedGoals = Set(rawValues.compactMap { UserGoal(rawValue: $0) })
            #if DEBUG
            print("🎯 UserGoalService: ✅ Loaded \(selectedGoals.count) selected goals")
            #endif
        } else {
            #if DEBUG
            print("🎯 UserGoalService: ⚠️ No selected goals found in UserDefaults")
            #endif
        }

        #if DEBUG
        print("🎯 UserGoalService: RESULT: primary = \(primaryGoal?.rawValue ?? "none"), shouldShowWeightUI = \(shouldShowWeightUI)")
        #endif
        #if DEBUG
        print("🎯 UserGoalService: ══════════════════════════════════════════════════")
        #endif
    }
}

// MARK: - View Extension for Conditional Weight UI

import SwiftUI

extension View {
    /// Only show this view if user's goal is weight_loss
    @ViewBuilder
    func showIfWeightGoal() -> some View {
        if UserGoalService.shared.shouldShowWeightUI {
            self
        }
    }
}
