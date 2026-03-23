//
//  AddWorkoutView.swift
//  Insio Health
//
//  Manual workout entry for users without Apple Watch data.
//  Supports common types, custom "Other" type, and flows through analytics pipeline.
//

import SwiftUI

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState

    var onSave: ((Workout) -> Void)?

    @State private var selectedType: WorkoutType = .run
    @State private var customTypeName: String = ""
    @State private var showCustomTypeInput: Bool = false
    @State private var durationMinutes: Int = 30
    @State private var perceivedEffort: ManualEffortLevel = .moderate
    @State private var note: String = ""
    @State private var isSaving = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Common types shown first (most used)
    private let commonTypes: [WorkoutType] = [.run, .strength, .walk, .cycle, .hiit, .yoga]

    // All types including Other
    private var allTypes: [WorkoutType] {
        commonTypes + [.swim, .other]
    }

    // Saved custom types from UserDefaults
    @AppStorage("customWorkoutTypes") private var savedCustomTypesData: Data = Data()

    private var savedCustomTypes: [String] {
        (try? JSONDecoder().decode([String].self, from: savedCustomTypesData)) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Workout Type
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Workout Type")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(AppColors.textSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppSpacing.sm) {
                            ForEach(allTypes, id: \.self) { type in
                                WorkoutTypeButton(
                                    type: type,
                                    customName: type == .other && !customTypeName.isEmpty ? customTypeName : nil,
                                    isSelected: selectedType == type
                                ) {
                                    withAnimation(AppAnimation.springBouncy) {
                                        selectedType = type
                                        if type == .other {
                                            showCustomTypeInput = true
                                        } else {
                                            showCustomTypeInput = false
                                            customTypeName = ""
                                        }
                                    }
                                }
                            }
                        }

                        // Custom type input
                        if showCustomTypeInput || selectedType == .other {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("What type of workout?")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary)

                                TextField("e.g., Pilates, Boxing, Tennis...", text: $customTypeName)
                                    .padding(AppSpacing.md)
                                    .background(AppColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                                            .stroke(AppColors.navy, lineWidth: 1)
                                    )

                                // Show saved custom types
                                if !savedCustomTypes.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: AppSpacing.xs) {
                                            ForEach(savedCustomTypes, id: \.self) { typeName in
                                                Button {
                                                    customTypeName = typeName
                                                } label: {
                                                    Text(typeName)
                                                        .font(AppTypography.chipText)
                                                        .foregroundStyle(customTypeName == typeName ? .white : AppColors.textSecondary)
                                                        .padding(.horizontal, AppSpacing.sm)
                                                        .padding(.vertical, 6)
                                                        .background(customTypeName == typeName ? AppColors.navy : AppColors.cardBackground)
                                                        .clipShape(Capsule())
                                                }
                                                .buttonStyle(BounceButtonStyle())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Duration")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(AppColors.textSecondary)

                        DurationPicker(minutes: $durationMinutes)
                    }

                    // Effort Level (for calorie estimation, not emotional check-in)
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Effort Level")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(AppColors.textSecondary)

                        EffortLevelPicker(effort: $perceivedEffort)
                    }

                    // Optional Note
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Note (optional)")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(AppColors.textSecondary)

                        TextField("How was your workout?", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                                    .stroke(AppColors.divider, lineWidth: 1)
                            )
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    // Save Button
                    Button(action: saveWorkout) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            }
                            Text(isSaving ? "Saving..." : "Save Workout")
                                .font(AppTypography.labelLarge)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(canSave ? AppColors.navy : AppColors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isSaving || !canSave)
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(AppSpacing.Layout.horizontalMargin)
            }
            .background(AppColors.background)
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var canSave: Bool {
        // Require custom type name if "Other" is selected
        if selectedType == .other {
            return !customTypeName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func saveWorkout() {
        isSaving = true

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-Double(durationMinutes * 60))

        // Estimate calories based on type and duration
        let estimatedCalories = estimateCalories(type: selectedType, minutes: durationMinutes, effort: perceivedEffort)

        // Create workout with proper source tracking
        var workout = Workout(
            id: UUID(),
            type: selectedType,
            startDate: startDate,
            endDate: endDate,
            duration: Double(durationMinutes * 60),
            calories: estimatedCalories,
            averageHeartRate: nil,
            maxHeartRate: nil,
            intensity: mapEffortToIntensity(perceivedEffort),
            interpretation: generateInterpretation(),
            isManualEntry: true
        )

        // Mark source as manual (eligible for check-ins)
        workout.source = .manual

        // Set custom type name if "Other"
        if selectedType == .other && !customTypeName.isEmpty {
            workout.customTypeName = customTypeName.trimmingCharacters(in: .whitespaces)
            saveCustomType(customTypeName.trimmingCharacters(in: .whitespaces))
        }

        // Set user feedback from note
        if !note.isEmpty {
            workout.userFeedback = note
        }

        // ══════════════════════════════════════════════════════════════
        // PHASE 1: LOCAL SAVE (synchronous, immediate)
        // ══════════════════════════════════════════════════════════════
        print("📱 AddWorkoutView: ══════════════════════════════════════")
        print("📱 AddWorkoutView: PHASE 1: LOCAL SAVE")
        print("📱 AddWorkoutView: Saving workout locally...")
        persistenceService.saveWorkout(workout)
        print("📱 AddWorkoutView: ✅ Local save complete")

        // Generate full analysis (flows through same pipeline as HealthKit workouts)
        generateAnalysis(for: workout)

        // Auto-record post-workout check-in using the effort level selected
        let feeling = mapEffortToFeeling(perceivedEffort)
        persistenceService.savePostWorkoutCheckIn(
            workoutId: workout.id,
            feeling: feeling,
            note: note.isEmpty ? nil : note
        )
        print("📱 AddWorkoutView: ✅ Auto-recorded post-workout check-in (effort: \(feeling))")

        // Mark the check-in as completed so we don't show the modal
        WorkoutMonitor.shared.postWorkoutCheckInCompleted(for: workout.id)

        print("📱 AddWorkoutView: PHASE 1 COMPLETE - Local data saved")
        print("📱 AddWorkoutView: ══════════════════════════════════════")

        // ══════════════════════════════════════════════════════════════
        // PHASE 2: UI UPDATE (immediate - before any async work)
        // ══════════════════════════════════════════════════════════════
        print("📱 AddWorkoutView: PHASE 2: UI UPDATE")

        // CRITICAL: Reset UI state and dismiss BEFORE any cloud sync
        // This ensures the user is never blocked by network operations
        isSaving = false
        onSave?(workout)

        print("📱 AddWorkoutView: ✅ onSave callback fired")
        print("📱 AddWorkoutView: ✅ Dismissing view NOW")
        dismiss()

        // ══════════════════════════════════════════════════════════════
        // PHASE 3: CLOUD SYNC (detached background, non-blocking)
        // ══════════════════════════════════════════════════════════════
        if authService.isAuthenticated {
            print("📱 AddWorkoutView: PHASE 3: CLOUD SYNC (background)")
            print("📱 AddWorkoutView: userId = \(authService.userId?.uuidString ?? "nil")")

            // CRITICAL: Use Task.detached to ensure cloud sync doesn't block main actor
            // The sync service is @MainActor but we don't need to wait for it
            let syncService = self.syncService
            let workoutToSync = workout
            let feelingToSync = feeling
            let noteToSync = note.isEmpty ? nil : note

            Task.detached(priority: .utility) {
                print("📱 AddWorkoutView: [BACKGROUND] Starting cloud sync...")

                // Sync workout with timeout protection
                await syncService.syncWorkoutWithTimeout(workoutToSync, timeout: 15)

                // Sync check-in with timeout protection
                await syncService.syncPostWorkoutCheckInWithTimeout(
                    workoutId: workoutToSync.id,
                    feeling: feelingToSync,
                    note: noteToSync,
                    timeout: 10
                )

                print("📱 AddWorkoutView: [BACKGROUND] Cloud sync completed")
            }
        } else {
            print("📱 AddWorkoutView: ⏭️ Skipping cloud sync - not authenticated")
        }
    }

    private func saveCustomType(_ typeName: String) {
        var types = savedCustomTypes
        // Add if not already saved, keep most recent at front
        if let index = types.firstIndex(of: typeName) {
            types.remove(at: index)
        }
        types.insert(typeName, at: 0)
        // Keep only last 10 custom types
        types = Array(types.prefix(10))

        if let data = try? JSONEncoder().encode(types) {
            savedCustomTypesData = data
        }
    }

    private func generateAnalysis(for workout: Workout) {
        // Use InterpretationEngine for consistent analysis
        let context = persistenceService.fetchTodayDailyContext()
        let recentWorkouts = persistenceService.fetchRecentWorkouts(limit: 10)
            .filter { $0.id != workout.id }

        let interpretation = InterpretationEngine.interpret(
            workout: workout,
            context: context,
            previousWorkouts: recentWorkouts
        )

        // Save interpretation to persistence
        persistenceService.saveWorkoutInterpretation(
            workoutId: workout.id,
            interpretation: interpretation
        )
    }

    private func estimateCalories(type: WorkoutType, minutes: Int, effort: ManualEffortLevel) -> Int {
        // Base calories per minute by type
        let baseRate: Double
        switch type {
        case .run:
            baseRate = 10.0
        case .cycle:
            baseRate = 8.0
        case .strength:
            baseRate = 6.0
        case .hiit:
            baseRate = 12.0
        case .yoga:
            baseRate = 3.0
        case .walk:
            baseRate = 4.0
        case .swim:
            baseRate = 9.0
        case .other:
            baseRate = 5.0
        }

        // Effort multiplier
        let effortMultiplier: Double
        switch effort {
        case .veryLight:
            effortMultiplier = 0.7
        case .light:
            effortMultiplier = 0.85
        case .moderate:
            effortMultiplier = 1.0
        case .hard:
            effortMultiplier = 1.2
        case .maxEffort:
            effortMultiplier = 1.4
        }

        return Int(baseRate * Double(minutes) * effortMultiplier)
    }

    private func mapEffortToIntensity(_ effort: ManualEffortLevel) -> WorkoutIntensity {
        switch effort {
        case .veryLight:
            return .low
        case .light:
            return .low
        case .moderate:
            return .moderate
        case .hard:
            return .high
        case .maxEffort:
            return .max
        }
    }

    /// Map effort level to WorkoutFeeling string for auto-recording check-in
    /// This eliminates the duplicate "how did it feel?" prompt for manual workouts
    private func mapEffortToFeeling(_ effort: ManualEffortLevel) -> String {
        // Map directly to WorkoutFeeling rawValue strings
        switch effort {
        case .veryLight:
            return "Very Light"
        case .light:
            return "Light"
        case .moderate:
            return "Moderate"
        case .hard:
            return "Hard"
        case .maxEffort:
            return "Max Effort"
        }
    }

    private func generateInterpretation() -> String {
        let effortText: String
        switch perceivedEffort {
        case .veryLight:
            effortText = "a light recovery"
        case .light:
            effortText = "an easy"
        case .moderate:
            effortText = "a solid"
        case .hard:
            effortText = "an intense"
        case .maxEffort:
            effortText = "a max effort"
        }

        let typeName = selectedType == .other && !customTypeName.isEmpty
            ? customTypeName.lowercased()
            : selectedType.rawValue.lowercased()

        return "Completed \(effortText) \(typeName) workout for \(durationMinutes) minutes."
    }
}

// MARK: - Manual Effort Level (UI-specific)

enum ManualEffortLevel: String, CaseIterable {
    case veryLight = "Very Light"
    case light = "Light"
    case moderate = "Moderate"
    case hard = "Hard"
    case maxEffort = "Max Effort"

    var icon: String {
        switch self {
        case .veryLight: return "leaf.fill"
        case .light: return "wind"
        case .moderate: return "flame.fill"
        case .hard: return "bolt.fill"
        case .maxEffort: return "bolt.horizontal.fill"
        }
    }

    var color: Color {
        switch self {
        case .veryLight: return AppColors.intensityLow
        case .light: return AppColors.olive
        case .moderate: return AppColors.navy
        case .hard: return AppColors.orange
        case .maxEffort: return AppColors.coral
        }
    }

    var description: String {
        switch self {
        case .veryLight: return "Recovery pace"
        case .light: return "Easy, conversational"
        case .moderate: return "Challenging but sustainable"
        case .hard: return "Pushed yourself"
        case .maxEffort: return "All-out effort"
        }
    }
}

// MARK: - Workout Type Button

struct WorkoutTypeButton: View {
    let type: WorkoutType
    var customName: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.navy : AppColors.cardBackground)
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                }

                Text(customName ?? type.rawValue)
                    .font(AppTypography.caption)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.navy.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Duration Picker

struct DurationPicker: View {
    @Binding var minutes: Int

    private let presets = [15, 30, 45, 60, 90]

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Presets
            HStack(spacing: AppSpacing.xs) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        withAnimation(AppAnimation.springBouncy) {
                            minutes = preset
                        }
                    } label: {
                        Text("\(preset)m")
                            .font(AppTypography.chipText)
                            .foregroundStyle(minutes == preset ? .white : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 8)
                            .background(minutes == preset ? AppColors.navy : AppColors.cardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }

            // Custom slider
            HStack {
                Text("\(minutes) min")
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 70, alignment: .leading)

                Slider(value: Binding(
                    get: { Double(minutes) },
                    set: { minutes = Int($0) }
                ), in: 5...180, step: 5)
                .tint(AppColors.navy)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Effort Level Picker (Refined, No Emojis)

struct EffortLevelPicker: View {
    @Binding var effort: ManualEffortLevel

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(ManualEffortLevel.allCases, id: \.self) { level in
                Button {
                    withAnimation(AppAnimation.springBouncy) {
                        effort = level
                    }
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(effort == level ? level.color : level.color.opacity(0.12))
                                .frame(width: 36, height: 36)

                            Image(systemName: level.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(effort == level ? .white : level.color)
                        }

                        // Labels
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue)
                                .font(AppTypography.cardSubtitle)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(level.description)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }

                        Spacer()

                        // Selection indicator
                        if effort == level {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(level.color)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(effort == level ? level.color.opacity(0.08) : AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(effort == level ? level.color.opacity(0.4) : AppColors.divider, lineWidth: effort == level ? 2 : 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddWorkoutView()
        .environmentObject(AuthService.shared)
        .environmentObject(AppState())
}
