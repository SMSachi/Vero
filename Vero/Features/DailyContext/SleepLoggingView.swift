//
//  SleepLoggingView.swift
//  Insio Health
//
//  Dedicated sleep logging screen with visual feedback.
//  More immersive experience than the generic daily log.
//

import SwiftUI

struct SleepLoggingView: View {
    @Environment(\.dismiss) private var dismiss

    /// Callback when sleep is saved - used to refresh parent views
    var onSave: (() -> Void)?

    // State
    @State private var sleepHours: Double = 7.0
    @State private var sleepQuality: SleepQuality = .good
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var animateMoon = false

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    // Goal of 8 hours
    private let dailyGoal: Double = 8.0

    private var progress: Double {
        min(sleepHours / dailyGoal, 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background - calming night theme
                LinearGradient(
                    colors: [
                        AppColors.olive.opacity(0.15),
                        AppColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Visual sleep display
                    sleepVisual
                        .padding(.top, 40)

                    Spacer()

                    // Quality selector
                    qualitySection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Slider for hours
                    sliderSection
                        .padding(.horizontal, 24)

                    Spacer()

                    // Save button
                    saveButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Sleep Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.olive)
                }
            }
        }
        .onAppear {
            // Load existing sleep for today
            loadExistingSleep()

            // Start moon animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateMoon = true
            }
        }
    }

    // MARK: - Sleep Visual

    private var sleepVisual: some View {
        ZStack {
            // Container circle
            Circle()
                .stroke(AppColors.divider, lineWidth: 8)
                .frame(width: 220, height: 220)

            // Sleep fill (animated arc)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.olive, AppColors.olive.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: sleepHours)

            // Inner content
            VStack(spacing: 8) {
                // Moon icon
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.olive)
                    .scaleEffect(animateMoon ? 1.05 : 0.95)
                    .rotationEffect(.degrees(animateMoon ? 5 : -5))

                // Value
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", sleepHours))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: sleepHours)

                    Text("hrs")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                // Quality badge
                Text(sleepQuality.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(qualityColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(qualityColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var qualityColor: Color {
        switch sleepQuality {
        case .excellent: return AppColors.olive
        case .good: return AppColors.olive
        case .fair: return .orange
        case .poor: return AppColors.coral
        }
    }

    // MARK: - Quality Section

    private var qualitySection: some View {
        VStack(spacing: 16) {
            Text("SLEEP QUALITY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 8) {
                ForEach(SleepQuality.allCases, id: \.self) { quality in
                    qualityButton(quality)
                }
            }
        }
    }

    private func qualityButton(_ quality: SleepQuality) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sleepQuality = quality
            }
        } label: {
            VStack(spacing: 6) {
                Text(qualityEmoji(quality))
                    .font(.system(size: 24))

                Text(quality.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(sleepQuality == quality ? .white : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                sleepQuality == quality ?
                AppColors.olive :
                Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(sleepQuality == quality ? 0.1 : 0.05), radius: 8, y: 3)
        }
    }

    private func qualityEmoji(_ quality: SleepQuality) -> String {
        switch quality {
        case .excellent: return "😴"
        case .good: return "😌"
        case .fair: return "😐"
        case .poor: return "😫"
        }
    }

    // MARK: - Slider Section

    private var sliderSection: some View {
        VStack(spacing: 12) {
            Text("HOURS SLEPT")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 8) {
                // Quick hour buttons
                HStack(spacing: 8) {
                    quickHourButton("5h") { sleepHours = 5 }
                    quickHourButton("6h") { sleepHours = 6 }
                    quickHourButton("7h") { sleepHours = 7 }
                    quickHourButton("8h") { sleepHours = 8 }
                    quickHourButton("9h") { sleepHours = 9 }
                }

                Slider(value: $sleepHours, in: 0...12, step: 0.5)
                    .tint(AppColors.olive)

                HStack {
                    Text("0 hrs")
                    Spacer()
                    Text("\(Int(dailyGoal)) hrs goal")
                    Spacer()
                    Text("12 hrs")
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

    private func quickHourButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.olive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.olive.opacity(0.1))
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
            .padding(.vertical, 18)
            .background(showSuccess ? AppColors.olive : AppColors.olive)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppColors.olive.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isSaving)
    }

    // MARK: - Actions

    private func loadExistingSleep() {
        if let context = persistenceService.fetchTodayDailyContext() {
            sleepHours = context.sleepHours
            sleepQuality = context.sleepQuality
        }
    }

    private func save() {
        print("😴 ════════════════════════════════════════════════════")
        print("😴 SLEEP LOG START")
        print("😴 ════════════════════════════════════════════════════")

        isSaving = true

        // Load or create today's context
        var context: DailyContext
        if let existing = persistenceService.fetchTodayDailyContext() {
            context = existing
        } else {
            context = DailyContext(
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
        }

        // Update sleep values
        context.sleepHours = sleepHours
        context.sleepQuality = sleepQuality

        print("😴 SLEEP: Value = \(String(format: "%.1f", sleepHours))h (\(sleepQuality.rawValue))")

        // Save to persistence
        persistenceService.saveDailyContext(context)
        print("😴 LOCAL SAVE SUCCESS")

        // Broadcast to update Home and Trends
        DataBroadcaster.shared.sleepSaved(hours: sleepHours)
        DataBroadcaster.shared.dailyContextSaved()

        print("😴 ════════════════════════════════════════════════════")
        print("😴 SLEEP LOG COMPLETE → Home & Trends will refresh")
        print("😴 ════════════════════════════════════════════════════")

        // Sync in background with timeout protection
        Task.detached(priority: .utility) { [syncService, context] in
            print("😴 BACKGROUND CLOUD SYNC START")
            await syncService.syncDailyContextWithTimeout(context, timeout: 10)
            print("😴 BACKGROUND CLOUD SYNC COMPLETE")
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
    SleepLoggingView()
}
