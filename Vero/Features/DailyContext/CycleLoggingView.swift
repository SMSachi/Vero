//
//  CycleLoggingView.swift
//  WellPattern Health
//
//  Manual cycle phase logging. HealthKit menstrual data is read to pre-fill
//  the phase when available, but the user always has the final say.
//

import SwiftUI

struct CycleLoggingView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)?

    @State private var selectedPhase: CyclePhase? = nil
    @State private var cycleDay: String = ""
    @State private var isSaving = false
    @State private var isLoadingHK = true

    private let persistenceService = PersistenceService.shared
    private let syncService = SupabaseSyncService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    headerSection
                    phaseSection
                    cycleDaySection
                    saveButton
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Cycle Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .task {
            await prefillFromHealthKit()
        }
        .task {
            prefillFromTodayContext()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.olive)

            Text("How are you feeling today?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Text("Cycle phase is optional and used only to personalise your AI insights.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 8) {
                ForEach(CyclePhase.allCases, id: \.self) { phase in
                    PhaseRow(phase: phase, isSelected: selectedPhase == phase) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedPhase == phase {
                                selectedPhase = nil
                            } else {
                                selectedPhase = phase
                            }
                        }
                    }
                }
            }
        }
    }

    private var cycleDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Day (optional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                TextField("e.g. 14", text: $cycleDay)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)

                Text("of your cycle")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedPhase == nil ? "Skip" : "Save")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(selectedPhase == nil ? AppColors.cardBackground : AppColors.olive)
            .foregroundStyle(selectedPhase == nil ? AppColors.textSecondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isSaving)
        .padding(.top, 8)
    }

    // MARK: - Logic

    private func prefillFromTodayContext() {
        if let existing = persistenceService.fetchTodayDailyContext() {
            selectedPhase = existing.cyclePhase
            if let day = existing.cycleDay {
                cycleDay = "\(day)"
            }
        }
    }

    private func prefillFromHealthKit() async {
        isLoadingHK = true
        let hasMenstrual = await HealthKitService.shared.hasTodayMenstrualFlow()
        isLoadingHK = false
        if hasMenstrual && selectedPhase == nil {
            selectedPhase = .menstruation
        }
    }

    private func save() {
        isSaving = true

        let dayValue = Int(cycleDay)

        var context: DailyContext
        if let existing = persistenceService.fetchTodayDailyContext() {
            context = existing
        } else {
            context = DailyContext(
                id: UUID(),
                date: Date(),
                sleepHours: 0,
                sleepQuality: .good,
                stressLevel: .moderate,
                energyLevel: .moderate
            )
        }

        context.cyclePhase = selectedPhase
        context.cycleDay = dayValue

        persistenceService.saveDailyContext(context)
        DataBroadcaster.shared.dailyContextSaved()

        Task.detached(priority: .utility) { [syncService, context] in
            await syncService.syncDailyContextWithTimeout(context, timeout: 10)
        }

        isSaving = false
        onSave?()
        dismiss()
    }
}

// MARK: - Phase Row

private struct PhaseRow: View {
    let phase: CyclePhase
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: phase.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : AppColors.olive)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? AppColors.olive : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
