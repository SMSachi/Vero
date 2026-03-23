//
//  NutritionLoggingView.swift
//  Insio Health
//
//  Simple nutrition logging view for water and macros.
//  Designed for quick, easy logging without complexity.
//

import SwiftUI

// MARK: - Nutrition Logging View

struct NutritionLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nutritionService = NutritionService.shared
    @StateObject private var premiumManager = PremiumManager.shared

    @State private var waterIntake: Int = 0
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var showingSaved = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    // Water section
                    WaterSection(
                        waterIntake: $waterIntake,
                        onQuickAdd: { amount in
                            waterIntake += amount
                        }
                    )

                    // Macros section
                    MacrosSection(
                        calories: $calories,
                        protein: $protein,
                        carbs: $carbs,
                        fat: $fat
                    )

                    // Premium upsell if not Plus+
                    if !premiumManager.isPlus {
                        NutritionUpsellCard()
                    }

                    // Save button
                    Button {
                        saveNutrition()
                    } label: {
                        Text("Save")
                            .font(AppTypography.buttonLarge)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.navy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                    }
                    .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationTitle("Log Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .alert("Saved!", isPresented: $showingSaved) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your nutrition data has been saved.")
        }
    }

    private func loadExistingData() {
        if let entry = nutritionService.todayEntry {
            waterIntake = entry.waterIntakeMl ?? 0
            if let c = entry.calories { calories = String(c) }
            if let p = entry.proteinGrams { protein = String(p) }
            if let c = entry.carbsGrams { carbs = String(c) }
            if let f = entry.fatGrams { fat = String(f) }
        }
    }

    private func saveNutrition() {
        // Save water
        if waterIntake > 0 {
            nutritionService.setWaterIntake(waterIntake)
        }

        // Save macros
        let caloriesInt = Int(calories)
        let proteinInt = Int(protein)
        let carbsInt = Int(carbs)
        let fatInt = Int(fat)

        if caloriesInt != nil || proteinInt != nil || carbsInt != nil || fatInt != nil {
            nutritionService.logMacros(
                calories: caloriesInt,
                protein: proteinInt,
                carbs: carbsInt,
                fat: fatInt
            )
        }

        showingSaved = true
    }
}

// MARK: - Water Section

private struct WaterSection: View {
    @Binding var waterIntake: Int
    let onQuickAdd: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(AppColors.olive)

                Text("Water Intake")
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text(formatWater(waterIntake))
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.navy)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppColors.divider)
                        .frame(height: 12)

                    // Progress (2L goal)
                    let progress = min(1.0, Double(waterIntake) / 2000.0)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppColors.olive)
                        .frame(width: geometry.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            // Goal indicator
            HStack {
                Text("Goal: 2L")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()

                Text(hydrationStatus)
                    .font(AppTypography.caption)
                    .foregroundStyle(statusColor)
            }

            // Quick add buttons
            HStack(spacing: AppSpacing.sm) {
                ForEach(WaterQuickAdd.allCases, id: \.rawValue) { amount in
                    QuickAddButton(
                        title: amount.displayName,
                        subtitle: amount.displayAmount,
                        icon: amount.icon
                    ) {
                        onQuickAdd(amount.rawValue)
                    }
                }
            }
        }
        .padding(AppSpacing.Layout.cardPadding)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }

    private func formatWater(_ ml: Int) -> String {
        if ml >= 1000 {
            return String(format: "%.1fL", Double(ml) / 1000.0)
        }
        return "\(ml)ml"
    }

    private var hydrationStatus: String {
        switch waterIntake {
        case 0..<1000: return "Keep drinking!"
        case 1000..<2000: return "Good progress"
        case 2000..<3000: return "Great!"
        default: return "Excellent!"
        }
    }

    private var statusColor: Color {
        switch waterIntake {
        case 0..<1000: return AppColors.orange
        case 1000..<2000: return AppColors.textSecondary
        default: return AppColors.olive
        }
    }
}

private struct QuickAddButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.olive)

                Text(subtitle)
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.oliveTint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Macros Section

private struct MacrosSection: View {
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fat: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(AppColors.orange)

                Text("Macros")
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("Optional")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            // Input fields
            VStack(spacing: AppSpacing.sm) {
                MacroInputRow(
                    label: "Calories",
                    unit: "kcal",
                    value: $calories,
                    icon: "flame.fill",
                    color: AppColors.orange
                )

                MacroInputRow(
                    label: "Protein",
                    unit: "g",
                    value: $protein,
                    icon: "p.circle.fill",
                    color: AppColors.navy
                )

                MacroInputRow(
                    label: "Carbs",
                    unit: "g",
                    value: $carbs,
                    icon: "c.circle.fill",
                    color: AppColors.olive
                )

                MacroInputRow(
                    label: "Fat",
                    unit: "g",
                    value: $fat,
                    icon: "f.circle.fill",
                    color: AppColors.textSecondary
                )
            }
        }
        .padding(AppSpacing.Layout.cardPadding)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

private struct MacroInputRow: View {
    let label: String
    let unit: String
    @Binding var value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                TextField("0", text: $value)
                    .font(AppTypography.bodyMedium)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)

                Text(unit)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
        }
    }
}

// MARK: - Nutrition Upsell Card

private struct NutritionUpsellCard: View {
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.navy)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Nutrition Insights")
                        .font(AppTypography.titleMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("See how nutrition affects your workouts")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Plus")
                    .font(AppTypography.buttonSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.olive)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.Layout.cardPadding)
        .background(AppColors.navyTint)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Quick Water Log Button (for use elsewhere)

struct QuickWaterLogButton: View {
    @StateObject private var nutritionService = NutritionService.shared
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(AppColors.olive)

                if let water = nutritionService.todayEntry?.waterIntakeMl, water > 0 {
                    Text(formatWater(water))
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(AppColors.textPrimary)
                } else {
                    Text("Log Water")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.oliveTint)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showingSheet) {
            NutritionLoggingView()
        }
    }

    private func formatWater(_ ml: Int) -> String {
        if ml >= 1000 {
            return String(format: "%.1fL", Double(ml) / 1000.0)
        }
        return "\(ml)ml"
    }
}

// MARK: - Preview

#Preview {
    NutritionLoggingView()
}
