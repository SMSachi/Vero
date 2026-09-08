//
//  NutritionLoggingView.swift
//  WellPattern Health
//
//  Macro logging screen — calories, protein, carbs, fat.
//  Saves directly to today's DailyContext via PersistenceService.
//

import SwiftUI

struct NutritionLoggingView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)?

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var isSaving = false
    @State private var showSuccess = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.navy.opacity(0.06), AppColors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        calorieSection
                        macrosSection
                        Spacer().frame(height: 8)
                        saveButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Log Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.navy)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Calorie Section

    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calories", systemImage: "flame.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.burntOrange)

            HStack {
                TextField("0", text: $calories)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .onChange(of: calories) { _, v in
                        calories = v.filter { $0.isNumber }
                    }

                Text("kcal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.burntOrange.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        }
    }

    // MARK: - Macros Section

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MACROS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 12) {
                macroField(label: "Protein", unit: "g", icon: "p.circle.fill", color: AppColors.olive, binding: $protein)
                macroField(label: "Carbs", unit: "g", icon: "c.circle.fill", color: AppColors.waterAccent, binding: $carbs)
                macroField(label: "Fat", unit: "g", icon: "f.circle.fill", color: AppColors.burntOrange, binding: $fat)
            }
        }
    }

    private func macroField(label: String, unit: String, icon: String, color: Color, binding: Binding<String>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 6) {
                TextField("0", text: binding)
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onChange(of: binding.wrappedValue) { _, v in
                        binding.wrappedValue = v.filter { $0.isNumber }
                    }

                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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

    // MARK: - Logic

    private func loadExisting() {
        guard let ctx = persistenceService.fetchTodayDailyContext() else { return }
        if let c = ctx.calories { calories = String(c) }
        if let p = ctx.proteinGrams { protein = String(p) }
        if let c = ctx.carbsGrams { carbs = String(c) }
        if let f = ctx.fatGrams { fat = String(f) }
    }

    private func save() {
        isSaving = true

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

        if let c = Int(calories) { context.calories = c }
        if let p = Int(protein) { context.proteinGrams = p }
        if let c = Int(carbs) { context.carbsGrams = c }
        if let f = Int(fat) { context.fatGrams = f }

        persistenceService.saveDailyContext(context)
        DataBroadcaster.shared.dailyContextSaved()

        Task.detached(priority: .utility) { [syncService, context] in
            await syncService.syncDailyContextWithTimeout(context, timeout: 10)
        }

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
    NutritionLoggingView()
}
