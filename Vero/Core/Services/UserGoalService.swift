//
//  UserGoalService.swift
//  Insio Health
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

    /// Whether user has completed goal selection
    var hasSelectedGoal: Bool {
        primaryGoal != nil
    }

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let primaryGoalKey = "insio_user_primary_goal"
    private let selectedGoalsKey = "insio_user_selected_goals"

    // MARK: - Initialization

    private init() {
        loadSavedGoals()
    }

    // MARK: - Goal Management

    /// Set the user's primary goal
    func setPrimaryGoal(_ goal: UserGoal) {
        primaryGoal = goal
        saveGoals()
        print("🎯 UserGoalService: Primary goal set to \(goal.rawValue)")
        print("🎯 UserGoalService: shouldShowWeightUI = \(shouldShowWeightUI)")
    }

    /// Set selected goals from onboarding
    func setSelectedGoals(_ goals: Set<UserGoal>, primaryGoal: UserGoal?) {
        self.selectedGoals = goals
        self.primaryGoal = primaryGoal ?? goals.first
        saveGoals()
        print("🎯 UserGoalService: Selected \(goals.count) goals")
        print("🎯 UserGoalService: Primary = \(self.primaryGoal?.rawValue ?? "none")")
    }

    /// Clear all goals (for logout/account deletion)
    func clearGoals() {
        primaryGoal = nil
        selectedGoals = []
        userDefaults.removeObject(forKey: primaryGoalKey)
        userDefaults.removeObject(forKey: selectedGoalsKey)
        print("🎯 UserGoalService: Goals cleared")
    }

    // MARK: - Persistence

    private func saveGoals() {
        if let primary = primaryGoal {
            userDefaults.set(primary.rawValue, forKey: primaryGoalKey)
        } else {
            userDefaults.removeObject(forKey: primaryGoalKey)
        }

        let goalsArray = selectedGoals.map { $0.rawValue }
        userDefaults.set(goalsArray, forKey: selectedGoalsKey)
    }

    private func loadSavedGoals() {
        // Load primary goal
        if let rawValue = userDefaults.string(forKey: primaryGoalKey),
           let goal = UserGoal(rawValue: rawValue) {
            primaryGoal = goal
        }

        // Load selected goals
        if let rawValues = userDefaults.array(forKey: selectedGoalsKey) as? [String] {
            selectedGoals = Set(rawValues.compactMap { UserGoal(rawValue: $0) })
        }

        print("🎯 UserGoalService: Loaded goals - primary = \(primaryGoal?.rawValue ?? "none")")
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
