//
//  WeightLoggingView.swift
//  Insio Health
//
//  Dedicated weight logging screen with slider input.
//  Uses UnitPreferences for metric/imperial display.
//  Internal storage is always in kg.
//

import SwiftUI

struct WeightLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var units = UnitPreferences.shared

    /// Callback when weight is saved
    var onSave: (() -> Void)?

    // State - display value in current unit system
    @State private var displayWeight: Double = 70.0
    @State private var isSaving = false
    @State private var showSuccess = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Computed kg value for storage
    private var weightKg: Double {
        units.weightToKg(displayWeight)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        AppColors.navy.opacity(0.08),
                        AppColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Weight display
                    weightDisplayView
                        .padding(.top, 40)

                    Spacer()

                    // Unit toggle
                    unitToggle
                        .padding(.horizontal, 24)

                    Spacer()

                    // Slider
                    sliderSection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Quick adjust buttons
                    quickAdjustSection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Save button
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.navy)
                }
            }
        }
        .onAppear {
            loadExistingWeight()
        }
    }

    // MARK: - Weight Display

    private var weightDisplayView: some View {
        VStack(spacing: 12) {
            // Large weight number
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", displayWeight))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: displayWeight)

                Text(units.weightUnit)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Conversion hint (show opposite unit)
            Text(units.isMetric
                ? String(format: "%.1f lb", weightKg * UnitPreferences.kgToLb)
                : String(format: "%.1f kg", weightKg))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    // MARK: - Unit Toggle

    private var unitToggle: some View {
        VStack(spacing: 12) {
            Text("UNIT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 0) {
                unitButton("kg", isSelected: units.isMetric) {
                    switchToMetric()
                }

                unitButton("lb", isSelected: units.isImperial) {
                    switchToImperial()
                }
            }
            .background(AppColors.divider)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func unitButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .frame(width: 70, height: 40)
                .background(isSelected ? AppColors.navy : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func switchToMetric() {
        guard units.isImperial else { return }
        // Convert current display value to kg before switching
        let kg = units.weightToKg(displayWeight)
        withAnimation(.spring(response: 0.3)) {
            units.setUnitSystem(.metric)
            displayWeight = kg  // Now in kg
        }
    }

    private func switchToImperial() {
        guard units.isMetric else { return }
        // Convert current display value to lb before switching
        let kg = displayWeight  // Currently in kg
        withAnimation(.spring(response: 0.3)) {
            units.setUnitSystem(.imperial)
            displayWeight = kg * UnitPreferences.kgToLb  // Now in lb
        }
    }

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(spacing: 12) {
            Slider(
                value: $displayWeight,
                in: units.weightSliderRange,
                step: units.weightSliderStep
            )
            .tint(AppColors.navy)

            HStack {
                Text(String(format: "%.0f %@", units.weightSliderRange.lowerBound, units.weightUnit))
                Spacer()
                Text(String(format: "%.0f %@", units.weightSliderRange.upperBound, units.weightUnit))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.textTertiary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }

    // MARK: - Quick Adjust

    private var quickAdjustSection: some View {
        VStack(spacing: 12) {
            Text("QUICK ADJUST")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 12) {
                // Amounts in display units
                let smallStep = units.isMetric ? 0.5 : 1.0
                let largeStep = units.isMetric ? 1.0 : 2.0

                adjustButton(String(format: "-%.1f", largeStep), delta: -largeStep)
                adjustButton(String(format: "-%.1f", smallStep), delta: -smallStep)
                adjustButton(String(format: "+%.1f", smallStep), delta: smallStep)
                adjustButton(String(format: "+%.1f", largeStep), delta: largeStep)
            }
        }
    }

    private func adjustButton(_ label: String, delta: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                let newValue = displayWeight + delta
                displayWeight = max(units.weightSliderRange.lowerBound,
                                   min(units.weightSliderRange.upperBound, newValue))
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.navy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.navy.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                Text(isSaving ? "Saving..." : (showSuccess ? "Saved!" : "Save"))
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(showSuccess ? AppColors.olive : AppColors.navy)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppColors.navy.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isSaving)
    }

    // MARK: - Actions

    private func loadExistingWeight() {
        var loadedKg: Double?

        if let context = persistenceService.fetchTodayDailyContext(),
           let weight = context.weightKg, weight > 0 {
            loadedKg = weight
        } else if let lastWeight = persistenceService.fetchLastRecordedWeight() {
            loadedKg = lastWeight
        }

        if let kg = loadedKg {
            // Convert to display units
            displayWeight = units.displayWeight(kg)
        } else {
            // Default based on unit system
            displayWeight = units.isMetric ? 70.0 : 154.0
        }
    }

    private func save() {
        isSaving = true

        // Load or create today's context
        var context: DailyContext
        if let existing = persistenceService.fetchTodayDailyContext() {
            context = existing
        } else {
            context = DailyContext(
                id: UUID(),
                date: Date(),
                sleepHours: 7,
                sleepQuality: .good,
                stressLevel: .moderate,
                energyLevel: .moderate,
                restingHeartRate: nil,
                hrvScore: nil,
                readinessScore: 50
            )
        }

        // Always store in kg
        let kgToSave = weightKg
        context.weightKg = kgToSave

        print("⚖️ WeightLoggingView: Saving \(kgToSave)kg (display: \(displayWeight) \(units.weightUnit))")
        persistenceService.saveDailyContext(context)
        print("⚖️ WeightLoggingView: ✅ Local save complete")

        // BROADCAST: Unified data pipeline
        DataBroadcaster.shared.weightSaved(kg: kgToSave)
        DataBroadcaster.shared.dailyContextSaved()
        print("⚖️ WeightLoggingView: ✅ Broadcast sent")

        // Sync in background
        Task.detached(priority: .utility) { [syncService, context] in
            await syncService.syncDailyContext(context)
        }

        // Show success
        withAnimation {
            isSaving = false
            showSuccess = true
        }

        onSave?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    WeightLoggingView()
}
