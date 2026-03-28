//
//  WeightLoggingView.swift
//  Insio Health
//
//  Dedicated weight logging screen with slider input and unit conversion.
//  Supports both metric (kg) and imperial (lb) units.
//

import SwiftUI

struct WeightLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useMetricUnits") private var useMetricUnits = true

    /// Callback when weight is saved
    var onSave: (() -> Void)?

    // State - stored in kg internally
    @State private var weightKg: Double = 70.0
    @State private var isSaving = false
    @State private var showSuccess = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Unit conversion
    private let kgToLb: Double = 2.20462
    private let lbToKg: Double = 0.453592

    // Slider ranges
    private var minWeight: Double { useMetricUnits ? 40.0 : 88.0 }
    private var maxWeight: Double { useMetricUnits ? 150.0 : 330.0 }
    private var sliderStep: Double { useMetricUnits ? 0.1 : 0.5 }

    private var displayWeight: Double {
        useMetricUnits ? weightKg : weightKg * kgToLb
    }

    private var unitLabel: String {
        useMetricUnits ? "kg" : "lb"
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
                    weightDisplay
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

    private var weightDisplay: some View {
        VStack(spacing: 12) {
            // Large weight number
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", displayWeight))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: displayWeight)

                Text(unitLabel)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Conversion hint
            Text(useMetricUnits
                ? String(format: "%.1f lb", weightKg * kgToLb)
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
                unitButton("kg", isSelected: useMetricUnits) {
                    withAnimation(.spring(response: 0.3)) {
                        useMetricUnits = true
                    }
                }

                unitButton("lb", isSelected: !useMetricUnits) {
                    withAnimation(.spring(response: 0.3)) {
                        useMetricUnits = false
                    }
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

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { displayWeight },
                    set: { newValue in
                        if useMetricUnits {
                            weightKg = newValue
                        } else {
                            weightKg = newValue * lbToKg
                        }
                    }
                ),
                in: minWeight...maxWeight,
                step: sliderStep
            )
            .tint(AppColors.navy)

            HStack {
                Text(String(format: "%.0f %@", minWeight, unitLabel))
                Spacer()
                Text(String(format: "%.0f %@", maxWeight, unitLabel))
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
                adjustButton("-1.0", delta: useMetricUnits ? -1.0 : -2.2)
                adjustButton("-0.5", delta: useMetricUnits ? -0.5 : -1.1)
                adjustButton("+0.5", delta: useMetricUnits ? 0.5 : 1.1)
                adjustButton("+1.0", delta: useMetricUnits ? 1.0 : 2.2)
            }
        }
    }

    private func adjustButton(_ label: String, delta: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if useMetricUnits {
                    weightKg = max(40, min(150, weightKg + delta))
                } else {
                    weightKg = max(40, min(150, weightKg + delta * lbToKg))
                }
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
        if let context = persistenceService.fetchTodayDailyContext(),
           let weight = context.weightKg, weight > 0 {
            weightKg = weight
        } else {
            // Try to load last recorded weight
            if let lastWeight = persistenceService.fetchLastRecordedWeight() {
                weightKg = lastWeight
            }
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

        // Update weight (always stored in kg)
        context.weightKg = weightKg

        // Save locally
        print("⚖️ WeightLoggingView: Saving \(weightKg)kg...")
        persistenceService.saveDailyContext(context)
        print("⚖️ WeightLoggingView: ✅ Local save complete")

        // BROADCAST: Unified data pipeline
        DataBroadcaster.shared.weightSaved(kg: weightKg)
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

        // Call onSave callback
        onSave?()

        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    WeightLoggingView()
}
