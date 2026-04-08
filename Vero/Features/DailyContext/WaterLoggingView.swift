//
//  WaterLoggingView.swift
//  Insio Health
//
//  Dedicated water logging screen with visual feedback.
//  Uses UnitPreferences for metric/imperial display.
//  Internal storage is always in liters.
//

import SwiftUI

struct WaterLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var units = UnitPreferences.shared

    /// Callback when water is saved - used to refresh parent views
    var onSave: (() -> Void)?

    // State - internal value is always in display units for slider
    @State private var displayValue: Double = 0
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var animateWave = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Computed liters value for storage
    private var waterLiters: Double {
        units.volumeToLiters(displayValue)
    }

    private var progress: Double {
        min(displayValue / units.dailyHydrationGoal, 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        AppColors.waterAccent.opacity(0.15),
                        AppColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Visual water display
                    waterVisual
                        .padding(.top, 40)

                    Spacer()

                    // Quick add buttons
                    quickAddSection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Slider for fine control
                    sliderSection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Save button
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Water Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.waterAccent)
                }
            }
        }
        .onAppear {
            loadExistingIntake()
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateWave = true
            }
        }
    }

    // MARK: - Water Visual

    private var waterVisual: some View {
        ZStack {
            // Container circle
            Circle()
                .stroke(AppColors.divider, lineWidth: 8)
                .frame(width: 220, height: 220)

            // Water fill (animated)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.waterAccent, AppColors.waterAccent.opacity(0.7)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: displayValue)

            // Inner content
            VStack(spacing: 8) {
                // Drop icon
                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.waterAccent)
                    .scaleEffect(animateWave ? 1.05 : 0.95)

                // Value
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: units.isMetric ? "%.1f" : "%.0f", displayValue))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: displayValue)

                    Text(units.volumeUnit)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                // Progress text
                Text("\(Int(progress * 100))% of daily goal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(spacing: 16) {
            Text("QUICK ADD")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 12) {
                ForEach(units.volumeQuickAddAmounts, id: \.label) { item in
                    quickAddButton(label: item.label, amount: item.displayValue)
                }
            }
        }
    }

    private func quickAddButton(label: String, amount: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                displayValue = min(displayValue + amount, units.volumeSliderRange.upperBound)
            }
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.waterAccent)

                Text(units.isMetric ? "Add" : "Add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.waterAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(spacing: 12) {
            Text("ADJUST")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 8) {
                Slider(
                    value: $displayValue,
                    in: units.volumeSliderRange,
                    step: units.volumeSliderStep
                )
                .tint(AppColors.waterAccent)

                HStack {
                    Text("0 \(units.volumeUnit)")
                    Spacer()
                    Text(units.dailyHydrationGoalFormatted + " goal")
                    Spacer()
                    Text(units.isMetric ? "5 L" : "170 oz")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
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
            .padding(.vertical, 18)
            .background(
                showSuccess ? AppColors.olive :
                (displayValue > 0 ? AppColors.waterAccent : AppColors.waterAccent.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppColors.waterAccent.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(displayValue == 0 || isSaving)
    }

    // MARK: - Actions

    private func loadExistingIntake() {
        if let context = persistenceService.fetchTodayDailyContext(),
           let waterMl = context.waterIntakeMl, waterMl > 0 {
            // Convert stored liters to display units
            let liters = Double(waterMl) / 1000.0
            displayValue = units.displayVolume(liters)
        }
    }

    private func save() {
        print("💧 ════════════════════════════════════════════════════")
        print("💧 WATER LOG START")
        print("💧 ════════════════════════════════════════════════════")

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

        // Convert to liters for storage
        let litersToSave = waterLiters
        let mlToSave = Int(litersToSave * 1000)
        context.waterIntakeMl = mlToSave

        print("💧 WATER: Value = \(String(format: "%.2f", litersToSave))L (\(mlToSave)ml)")

        // Save to persistence
        persistenceService.saveDailyContext(context)
        print("💧 LOCAL SAVE SUCCESS")

        // Broadcast to update Home and Trends
        DataBroadcaster.shared.hydrationSaved(liters: litersToSave)
        DataBroadcaster.shared.dailyContextSaved()

        print("💧 ════════════════════════════════════════════════════")
        print("💧 WATER LOG COMPLETE → Home & Trends will refresh")
        print("💧 ════════════════════════════════════════════════════")

        // Sync in background with timeout protection
        Task.detached(priority: .utility) { [syncService, context] in
            print("💧 BACKGROUND CLOUD SYNC START")
            await syncService.syncDailyContextWithTimeout(context, timeout: 10)
            print("💧 BACKGROUND CLOUD SYNC COMPLETE")
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
    WaterLoggingView()
}
