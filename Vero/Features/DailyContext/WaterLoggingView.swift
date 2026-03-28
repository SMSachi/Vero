//
//  WaterLoggingView.swift
//  Insio Health
//
//  Dedicated water logging screen with visual feedback.
//  More immersive experience than the generic daily log.
//

import SwiftUI

struct WaterLoggingView: View {
    @Environment(\.dismiss) private var dismiss

    /// Callback when water is saved - used to refresh parent views
    var onSave: (() -> Void)?

    // State
    @State private var waterLiters: Double = 0
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var animateWave = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Goal of 3L daily
    private let dailyGoal: Double = 3.0

    private var progress: Double {
        min(waterLiters / dailyGoal, 1.0)
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
            // Load existing water intake for today
            loadExistingIntake()

            // Start wave animation
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
                .animation(.easeOut(duration: 0.5), value: waterLiters)

            // Inner content
            VStack(spacing: 8) {
                // Drop icon
                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.waterAccent)
                    .scaleEffect(animateWave ? 1.05 : 0.95)

                // Value
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", waterLiters))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: waterLiters)

                    Text("L")
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
                quickAddButton(label: "+1 Glass", amount: 0.25)
                quickAddButton(label: "+1 Bottle", amount: 0.5)
                quickAddButton(label: "+1 Liter", amount: 1.0)
            }
        }
    }

    private func quickAddButton(label: String, amount: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                waterLiters = min(waterLiters + amount, 5.0)
            }
        } label: {
            VStack(spacing: 6) {
                Text("+\(amount < 1 ? String(format: "%.2gL", amount) : String(format: "%.0fL", amount))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.waterAccent)

                Text(label)
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
                Slider(value: $waterLiters, in: 0...5, step: 0.25)
                    .tint(AppColors.waterAccent)

                HStack {
                    Text("0 L")
                    Spacer()
                    Text("\(String(format: "%.1f", dailyGoal)) L goal")
                    Spacer()
                    Text("5 L")
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
                (waterLiters > 0 ? AppColors.waterAccent : AppColors.waterAccent.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppColors.waterAccent.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(waterLiters == 0 || isSaving)
    }

    // MARK: - Actions

    private func loadExistingIntake() {
        if let context = persistenceService.fetchTodayDailyContext(),
           let waterMl = context.waterIntakeMl, waterMl > 0 {
            waterLiters = Double(waterMl) / 1000.0
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

        // Update water intake
        context.waterIntakeMl = Int(waterLiters * 1000)

        // Save locally
        print("💧 WaterLoggingView: Saving \(waterLiters)L...")
        persistenceService.saveDailyContext(context)
        print("💧 WaterLoggingView: ✅ Local save complete")

        // BROADCAST: Unified data pipeline
        DataBroadcaster.shared.hydrationSaved(liters: waterLiters)
        DataBroadcaster.shared.dailyContextSaved()
        print("💧 WaterLoggingView: ✅ Broadcast sent")

        // Sync in background
        Task.detached(priority: .utility) { [syncService, context] in
            await syncService.syncDailyContext(context)
        }

        // Show success
        withAnimation {
            isSaving = false
            showSuccess = true
        }

        // Call onSave callback (legacy compatibility)
        onSave?()

        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    WaterLoggingView()
}
