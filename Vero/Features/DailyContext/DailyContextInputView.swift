//
//  DailyContextInputView.swift
//  Insio Health
//
//  Input view for daily context: water, nutrition, weight (if goal == weight_loss).
//  Saves locally first, then syncs to Supabase.
//

import SwiftUI

struct DailyContextInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var goalService = UserGoalService.shared
    @ObservedObject private var units = UnitPreferences.shared

    /// Callback when save completes - used to refresh parent views
    var onSave: (() -> Void)?

    // Input state - display values in current unit system
    @State private var sleepHours: Double = 7
    @State private var sleepQuality: SleepQuality = .good
    @State private var waterDisplayValue: Double = 0  // In display units (L or oz)
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var weightDisplayValue: String = ""  // In display units (kg or lb)

    // UI state
    @State private var isSaving = false
    @State private var showSuccess = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Computed values for storage (always metric)
    private var waterLiters: Double {
        units.volumeToLiters(waterDisplayValue)
    }

    private var weightKg: Double? {
        guard let displayValue = Double(weightDisplayValue), displayValue > 0 else { return nil }
        return units.weightToKg(displayValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    headerSection

                    // Sleep tracking
                    sleepSection

                    // Water intake
                    waterSection

                    // Weight (only for weight loss goal)
                    if goalService.shouldShowWeightUI {
                        weightSection
                    }

                    // Nutrition (if goal emphasizes it)
                    if goalService.shouldEmphasizeNutrition {
                        nutritionSection
                    }

                    // Save button
                    saveButton
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Log Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(Date(), style: .date)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(AppColors.textPrimary)

            Text("Track your daily habits")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.md)
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Sleep", systemImage: "bed.double.fill")
                .font(AppTypography.titleMedium)
                .foregroundStyle(AppColors.navy)

            VStack(spacing: AppSpacing.sm) {
                // Hours slider
                HStack {
                    Text(String(format: "%.1f hrs", sleepHours))
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    Spacer()

                    // Quick set buttons
                    HStack(spacing: AppSpacing.xs) {
                        quickSleepButton("6h") { sleepHours = 6 }
                        quickSleepButton("7h") { sleepHours = 7 }
                        quickSleepButton("8h") { sleepHours = 8 }
                    }
                }

                Slider(value: $sleepHours, in: 0...12, step: 0.5)
                    .tint(AppColors.navy)

                // Quality picker
                HStack {
                    Text("Quality")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Picker("Quality", selection: $sleepQuality) {
                        ForEach(SleepQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private func quickSleepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.labelSmall)
                .foregroundStyle(AppColors.navy)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.navy.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
        }
    }

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // WATER = blue/teal derived from NAVY
            Label("Water Intake", systemImage: "drop.fill")
                .font(AppTypography.titleMedium)
                .foregroundStyle(AppColors.waterAccent)

            VStack(spacing: AppSpacing.sm) {
                HStack {
                    Text(String(format: units.isMetric ? "%.1f %@" : "%.0f %@", waterDisplayValue, units.volumeUnit))
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    Spacer()

                    // Quick add buttons (unit-aware)
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(units.volumeQuickAddAmounts.prefix(2), id: \.label) { item in
                            quickAddButton(item.label, color: AppColors.waterAccent) {
                                waterDisplayValue += item.displayValue
                            }
                        }
                    }
                }

                Slider(value: $waterDisplayValue, in: units.volumeSliderRange, step: units.volumeSliderStep)
                    .tint(AppColors.waterAccent)

                HStack {
                    Text("0 \(units.volumeUnit)")
                    Spacer()
                    Text(units.isMetric ? "5 L" : "170 oz")
                }
                .font(AppTypography.captionSmall)
                .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.waterTint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // NUTRITION = OLIVE
            Label("Nutrition", systemImage: "fork.knife")
                .font(AppTypography.titleMedium)
                .foregroundStyle(AppColors.olive)

            VStack(spacing: AppSpacing.sm) {
                nutritionField(label: "Calories", value: $calories, unit: "kcal")
                nutritionField(label: "Protein", value: $protein, unit: "g")
                nutritionField(label: "Carbs", value: $carbs, unit: "g")
            }
            .padding(AppSpacing.md)
            .background(AppColors.oliveTint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Weight", systemImage: "scalemass")
                .font(AppTypography.titleMedium)
                .foregroundStyle(AppColors.navy)

            HStack {
                TextField("0.0", text: $weightDisplayValue)
                    .keyboardType(.decimalPad)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)

                Text(units.weightUnit)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                Text(isSaving ? "Saving..." : (showSuccess ? "Saved!" : "Save"))
                    .font(AppTypography.labelLarge)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            // STRICT: CTA = BURNT ORANGE
            .background(showSuccess ? AppColors.olive : AppColors.burntOrange)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        }
        .disabled(isSaving)
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - Helpers

    private func quickAddButton(_ label: String, color: Color = AppColors.navy, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.labelSmall)
                .foregroundStyle(color)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
        }
    }

    private func nutritionField(label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 80, alignment: .leading)

            TextField("0", text: value)
                .keyboardType(.numberPad)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)

            Text(unit)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 40, alignment: .leading)
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true

        // Create daily context with all fields
        var context = DailyContext(
            id: UUID(),
            date: Date(),
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            stressLevel: .moderate,
            energyLevel: .moderate,
            restingHeartRate: nil,
            hrvScore: nil,
            readinessScore: 50
        )

        // Set nutrition/water values
        context.waterIntakeMl = Int(waterLiters * 1000)
        if let cal = Int(calories), cal > 0 {
            context.calories = cal
        }
        if let prot = Int(protein), prot > 0 {
            context.proteinGrams = prot
        }
        if let carb = Int(carbs), carb > 0 {
            context.carbsGrams = carb
        }

        // Set weight (only if goal is weight_loss and value entered)
        // weightKg computed property already converts from display units
        if goalService.shouldShowWeightUI, let kg = weightKg, kg > 0 {
            context.weightKg = kg
        }

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 1: LOCAL SAVE (SwiftData)
        // ══════════════════════════════════════════════════════════════════════════
        print("📊 ════════════════════════════════════════════════════════════════")
        print("📊 DAILY_CONTEXT: SAVE FLOW STARTED")
        print("📊 ════════════════════════════════════════════════════════════════")
        print("📊 [LOCAL] Saving to SwiftData...")
        print("📊 [LOCAL] ID: \(context.id)")
        print("📊 [LOCAL] Date: \(context.date)")
        print("📊 [LOCAL] Sleep: \(context.sleepHours)h (\(context.sleepQuality.rawValue))")
        print("📊 [LOCAL] Water: \(context.waterIntakeMl ?? 0)ml")
        print("📊 [LOCAL] Calories: \(context.calories ?? 0)")
        print("📊 [LOCAL] Protein: \(context.proteinGrams ?? 0)g")
        print("📊 [LOCAL] Carbs: \(context.carbsGrams ?? 0)g")
        print("📊 [LOCAL] Weight: \(context.weightKg ?? 0)kg")

        persistenceService.saveDailyContext(context)
        print("📊 [LOCAL] ✅ SwiftData save SUCCESS")

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 2: BROADCAST (Unified Data Pipeline)
        // ══════════════════════════════════════════════════════════════════════════
        print("📊 [BROADCAST] Broadcasting dailyContext change...")
        DataBroadcaster.shared.dailyContextSaved()

        // Also broadcast specific metrics for granular listeners
        if context.sleepHours > 0 {
            DataBroadcaster.shared.sleepSaved(hours: context.sleepHours)
        }
        if let waterMl = context.waterIntakeMl, waterMl > 0 {
            DataBroadcaster.shared.hydrationSaved(liters: Double(waterMl) / 1000.0)
        }
        if let weightKg = context.weightKg, weightKg > 0 {
            DataBroadcaster.shared.weightSaved(kg: weightKg)
        }
        if let calories = context.calories, calories > 0 {
            DataBroadcaster.shared.caloriesSaved(calories: calories)
        }

        // ══════════════════════════════════════════════════════════════════════════
        // PHASE 3: CLOUD SYNC (Supabase - non-blocking with timeout)
        // ══════════════════════════════════════════════════════════════════════════
        Task.detached(priority: .utility) { [syncService, context] in
            print("📊 BACKGROUND CLOUD SYNC START")
            print("📊 Context ID: \(context.id)")

            await syncService.syncDailyContextWithTimeout(context, timeout: 10)

            print("📊 BACKGROUND CLOUD SYNC COMPLETE")
        }

        // Show success
        withAnimation {
            isSaving = false
            showSuccess = true
        }

        // Call onSave callback (legacy - keeping for compatibility)
        onSave?()
        print("📊 [LOCAL] ✅ Save complete, broadcast sent")

        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    DailyContextInputView()
}
