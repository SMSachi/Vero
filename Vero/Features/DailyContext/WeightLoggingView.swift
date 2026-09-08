//
//  WeightLoggingView.swift
//  WellPattern Health
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
    @State private var weightText: String = ""
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

                    // Numeric entry
                    numericEntrySection
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
            #if DEBUG
            print("⚖️ [TRACE 11] WeightLoggingView.onAppear START")
            #endif
            loadExistingWeight()
            #if DEBUG
            print("⚖️ [TRACE 11] WeightLoggingView.onAppear END — displayWeight=\(displayWeight) weightText=\(weightText)")
            #endif
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
                .foregroundStyle(AppColors.textSecondary)
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
        let kg = units.weightToKg(displayWeight)
        withAnimation(.spring(response: 0.3)) {
            units.setUnitSystem(.metric)
            displayWeight = kg
            weightText = String(format: "%.1f", kg)
        }
    }

    private func switchToImperial() {
        guard units.isMetric else { return }
        let kg = displayWeight
        withAnimation(.spring(response: 0.3)) {
            units.setUnitSystem(.imperial)
            displayWeight = kg * UnitPreferences.kgToLb
            weightText = String(format: "%.1f", kg * UnitPreferences.kgToLb)
        }
    }

    // MARK: - Numeric Entry Section

    private var numericEntrySection: some View {
        VStack(spacing: 12) {
            Text("ENTER WEIGHT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 0) {
                TextField("0.0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .onChange(of: weightText) { _, newValue in
                        #if DEBUG
                        print("⚖️ [TRACE 11] onChange(weightText) fired — newValue='\(newValue)'")
                        #endif
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if filtered != newValue { weightText = filtered }
                        if let parsed = Double(filtered) {
                            let clamped = max(units.weightSliderRange.lowerBound,
                                             min(units.weightSliderRange.upperBound, parsed))
                            displayWeight = clamped
                        }
                        #if DEBUG
                        print("⚖️ [TRACE 11] onChange(weightText) done — displayWeight=\(displayWeight)")
                        #endif
                    }

                Text(units.weightUnit)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.leading, 6)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.navy.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        }
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
            #if DEBUG
            print("⚖️ [TRACE 11] adjustButton '\(label)' tapped — displayWeight before=\(displayWeight) weightText=\(weightText)")
            #endif
            withAnimation(.spring(response: 0.3)) {
                let newValue = displayWeight + delta
                displayWeight = max(units.weightSliderRange.lowerBound,
                                   min(units.weightSliderRange.upperBound, newValue))
            }
            #if DEBUG
            print("⚖️ [TRACE 11] adjustButton after — displayWeight=\(displayWeight) (note: weightText NOT synced by adjustButton)")
            #endif
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
        #if DEBUG
        print("⚖️ [TRACE 11] loadExistingWeight() START — unit=\(units.weightUnit)")
        #endif
        var loadedKg: Double?

        if let context = persistenceService.fetchTodayDailyContext(),
           let weight = context.weightKg, weight > 0 {
            loadedKg = weight
            #if DEBUG
            print("⚖️ [TRACE 11] loadExistingWeight() — found today's weight: \(weight)kg")
            #endif
        } else if let lastWeight = persistenceService.fetchLastRecordedWeight() {
            loadedKg = lastWeight
            #if DEBUG
            print("⚖️ [TRACE 11] loadExistingWeight() — using last recorded: \(lastWeight)kg")
            #endif
        } else {
            #if DEBUG
            print("⚖️ [TRACE 11] loadExistingWeight() — no weight on record, using default")
            #endif
        }

        if let kg = loadedKg {
            displayWeight = units.displayWeight(kg)
        } else {
            displayWeight = units.isMetric ? 70.0 : 154.0
        }
        weightText = String(format: "%.1f", displayWeight)
        #if DEBUG
        print("⚖️ [TRACE 11] loadExistingWeight() END — displayWeight=\(displayWeight) \(units.weightUnit) weightText=\(weightText)")
        #endif
    }

    private func save() {
        print("⚖️ ════════════════════════════════════════════════════")
        print("⚖️ WEIGHT LOG START")
        print("⚖️ ════════════════════════════════════════════════════")

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
                readinessScore: nil
            )
        }

        // Always store in kg
        let kgToSave = weightKg
        context.weightKg = kgToSave

        print("⚖️ WEIGHT: Value = \(String(format: "%.1f", kgToSave))kg (display: \(String(format: "%.1f", displayWeight)) \(units.weightUnit))")

        // Save to persistence
        persistenceService.saveDailyContext(context)
        print("⚖️ LOCAL SAVE SUCCESS")

        // Broadcast to update Home and Trends
        DataBroadcaster.shared.weightSaved(kg: kgToSave)
        DataBroadcaster.shared.dailyContextSaved()

        print("⚖️ ════════════════════════════════════════════════════")
        print("⚖️ WEIGHT LOG COMPLETE → Home & Trends will refresh")
        print("⚖️ ════════════════════════════════════════════════════")

        // Sync in background with timeout protection
        Task.detached(priority: .utility) { [syncService, context] in
            print("⚖️ BACKGROUND CLOUD SYNC START")
            await syncService.syncDailyContextWithTimeout(context, timeout: 10)
            print("⚖️ BACKGROUND CLOUD SYNC COMPLETE")
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
