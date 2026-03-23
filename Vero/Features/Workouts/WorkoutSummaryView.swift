//
//  WorkoutSummaryView.swift
//  Insio Health
//
//  Premium, editorial workout summary screen
//

import SwiftUI

struct WorkoutSummaryView: View {
    let workout: Workout
    @State private var selectedEffort: PerceivedEffort?
    @State private var showingEffortPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                // 1. Header
                WorkoutSummaryHeader(workout: workout)

                // 2. What happened
                NumberedInsightCard(
                    number: 1,
                    title: "What happened",
                    icon: "doc.text.fill",
                    iconColor: AppColors.navy,
                    content: workout.whatHappened ?? workout.interpretation
                )

                // 3. What it may mean
                NumberedInsightCard(
                    number: 2,
                    title: "What it may mean",
                    icon: "lightbulb.fill",
                    iconColor: AppColors.olive,
                    content: workout.whatItMeans ?? "Your body responded well to this workout. The intensity was appropriate for your current fitness level."
                )

                // 4. What to do next
                NumberedInsightCard(
                    number: 3,
                    title: "What to do next",
                    icon: "arrow.right.circle.fill",
                    iconColor: AppColors.orange,
                    content: workout.whatToDoNext ?? "Allow adequate recovery before your next session. Listen to your body."
                )

                // 5. Supporting metrics
                MetricsGridSection(workout: workout)

                // 6. Context section
                ContextSection(workout: workout)

                // 7. User response
                UserResponseSection(
                    workout: workout,
                    selectedEffort: $selectedEffort
                )

                // Bottom spacing
                Spacer()
                    .frame(height: AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(AppColors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Workout Summary")
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.navy)
                }
            }
        }
    }
}

// MARK: - 1. Header

struct WorkoutSummaryHeader: View {
    let workout: Workout

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Workout type icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: workout.type.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(categoryColor)
            }

            // Workout type and category
            VStack(spacing: AppSpacing.xxs) {
                Text(workout.type.rawValue)
                    .font(AppTypography.displaySmall)
                    .foregroundStyle(AppColors.textPrimary)

                // Category badge
                Text(workout.category.rawValue)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxxs)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Duration (hero metric)
            Text(workout.durationFormatted)
                .font(AppTypography.metricLarge)
                .foregroundStyle(AppColors.textPrimary)

            // Date and time
            VStack(spacing: 2) {
                Text(workout.dateFormatted)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)

                Text(workout.timeFormatted)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textTertiary)
            }

            // Intensity badge
            HStack(spacing: AppSpacing.xxs) {
                Circle()
                    .fill(intensityColor)
                    .frame(width: 8, height: 8)

                Text("\(workout.intensity.rawValue) intensity")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())
            .cardShadow()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private var categoryColor: Color {
        switch workout.category {
        case .cardio: return AppColors.info
        case .strength: return .purple
        case .highIntensity: return AppColors.orange
        case .recovery: return AppColors.olive
        case .mixed: return AppColors.textSecondary
        }
    }

    private var intensityColor: Color {
        switch workout.intensity {
        case .low: return AppColors.intensityLow
        case .moderate: return AppColors.intensityModerate
        case .high: return AppColors.intensityHigh
        case .max: return AppColors.intensityMax
        }
    }
}

// MARK: - 2, 3, 4. Numbered Insight Cards

struct NumberedInsightCard: View {
    let number: Int
    let title: String
    let icon: String
    let iconColor: Color
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack(spacing: AppSpacing.xs) {
                // Number badge
                Text("\(number)")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(AppColors.divider)
                    .clipShape(Circle())

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)

                // Title
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Content
            Text(content)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPadding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
        .cardShadow()
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - 5. Metrics Grid

struct MetricsGridSection: View {
    let workout: Workout

    private var metrics: [(label: String, value: String, unit: String?, icon: String, color: Color)] {
        var result: [(String, String, String?, String, Color)] = []

        if let avgHR = workout.averageHeartRate {
            result.append(("Avg HR", "\(avgHR)", "bpm", "heart.fill", .red))
        }

        if let maxHR = workout.maxHeartRate {
            result.append(("Peak HR", "\(maxHR)", "bpm", "heart.circle.fill", AppColors.intensityMax))
        }

        if let recovery = workout.recoveryHeartRate {
            result.append(("Recovery HR", "\(recovery)", "bpm", "arrow.down.heart.fill", AppColors.olive))
        }

        result.append(("Active Energy", "\(workout.calories)", "cal", "flame.fill", AppColors.orange))

        if let distance = workout.distanceFormatted {
            result.append(("Distance", distance, nil, "figure.walk.motion", AppColors.info))
        }

        if let elevation = workout.elevationGain {
            result.append(("Elevation", "\(Int(elevation))", "m", "arrow.up.right", AppColors.olive))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Metrics")
                .font(AppTypography.labelLarge)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.xs),
                    GridItem(.flexible(), spacing: AppSpacing.xs),
                    GridItem(.flexible(), spacing: AppSpacing.xs)
                ],
                spacing: AppSpacing.xs
            ) {
                ForEach(0..<metrics.count, id: \.self) { index in
                    MetricGridCell(
                        label: metrics[index].label,
                        value: metrics[index].value,
                        unit: metrics[index].unit,
                        icon: metrics[index].icon,
                        color: metrics[index].color
                    )
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
}

struct MetricGridCell: View {
    let label: String
    let value: String
    let unit: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)

            // Value
            HStack(spacing: 2) {
                Text(value)
                    .font(AppTypography.metricMini)
                    .foregroundStyle(AppColors.textPrimary)

                if let unit = unit {
                    Text(unit)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            // Label
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
        .cardShadow()
    }
}

// MARK: - 6. Context Section

struct ContextSection: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Context")
                .font(AppTypography.labelLarge)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: 1) {
                if let sleep = workout.sleepBeforeWorkout {
                    ContextRow(
                        icon: "moon.fill",
                        iconColor: .indigo,
                        label: "Sleep before workout",
                        value: String(format: "%.1f hours", sleep),
                        status: sleep >= 7 ? .good : (sleep >= 6 ? .moderate : .low)
                    )
                }

                if let hydration = workout.hydrationLevel {
                    ContextRow(
                        icon: "drop.fill",
                        iconColor: .blue,
                        label: "Hydration",
                        value: hydration.rawValue,
                        status: hydration == .excellent || hydration == .good ? .good : .moderate
                    )
                }

                if let nutrition = workout.nutritionStatus {
                    ContextRow(
                        icon: "fork.knife",
                        iconColor: AppColors.orange,
                        label: "Nutrition",
                        value: nutrition.rawValue,
                        status: .neutral
                    )
                }

                if let note = workout.preWorkoutNote {
                    ContextRow(
                        icon: "note.text",
                        iconColor: AppColors.olive,
                        label: "Note",
                        value: note,
                        status: .neutral,
                        isMultiline: true
                    )
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
            .cardShadow()
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
}

struct ContextRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var status: ContextStatus = .neutral
    var isMultiline: Bool = false

    enum ContextStatus {
        case good, moderate, low, neutral

        var color: Color {
            switch self {
            case .good: return AppColors.recoveryGood
            case .moderate: return AppColors.recoveryModerate
            case .low: return AppColors.recoveryLow
            case .neutral: return AppColors.textSecondary
            }
        }
    }

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: AppSpacing.xs) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Label
            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            // Value
            if isMultiline {
                Text(value)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180, alignment: .trailing)
            } else {
                HStack(spacing: AppSpacing.xxxs) {
                    if status != .neutral {
                        Circle()
                            .fill(status.color)
                            .frame(width: 6, height: 6)
                    }
                    Text(value)
                        .font(AppTypography.titleSmall)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
    }
}

// MARK: - 7. User Response Section

struct UserResponseSection: View {
    let workout: Workout
    @Binding var selectedEffort: PerceivedEffort?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your response")
                .font(AppTypography.labelLarge)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            VStack(spacing: AppSpacing.sm) {
                // Perceived effort
                PerceivedEffortCard(
                    selectedEffort: $selectedEffort,
                    existingEffort: workout.perceivedEffort
                )

                // How did it compare
                AdaptiveQuestionCard()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
}

struct PerceivedEffortCard: View {
    @Binding var selectedEffort: PerceivedEffort?
    let existingEffort: PerceivedEffort?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.navy)

                Text("How hard did it feel?")
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Effort scale
            HStack(spacing: AppSpacing.xxxs) {
                ForEach(PerceivedEffort.allCases, id: \.self) { effort in
                    let isSelected = (selectedEffort ?? existingEffort) == effort

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEffort = effort
                        }
                    } label: {
                        VStack(spacing: AppSpacing.xxxs) {
                            Text("\(effort.rawValue)")
                                .font(AppTypography.titleMedium)
                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)

                            Text(effort.label)
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : AppColors.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .background(isSelected ? effortColor(for: effort) : AppColors.divider.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.95))
                }
            }

            // Selected description
            if let effort = selectedEffort ?? existingEffort {
                Text(effort.description)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, AppSpacing.xxxs)
            }
        }
        .cardPadding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
        .cardShadow()
    }

    private func effortColor(for effort: PerceivedEffort) -> Color {
        switch effort {
        case .veryLight: return AppColors.intensityLow
        case .light: return AppColors.recoveryGood
        case .moderate: return AppColors.intensityModerate
        case .hard: return AppColors.intensityHigh
        case .veryHard: return AppColors.intensityMax
        }
    }
}

struct AdaptiveQuestionCard: View {
    @State private var selectedAnswer: Int? = nil

    private let question = "Compared to similar runs, this felt..."
    private let answers = ["Easier than usual", "About the same", "Harder than usual"]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.olive)

                Text(question)
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.textPrimary)
            }

            VStack(spacing: AppSpacing.xxs) {
                ForEach(0..<answers.count, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAnswer = index
                        }
                    } label: {
                        HStack {
                            Text(answers[index])
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(selectedAnswer == index ? .white : AppColors.textPrimary)

                            Spacer()

                            if selectedAnswer == index {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(selectedAnswer == index ? AppColors.navy : AppColors.divider.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.98))
                }
            }

            // Feedback after selection
            if selectedAnswer != nil {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.olive)

                    Text("Thanks! This helps us understand your progress.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardPadding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge))
        .cardShadow()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutSummaryView(workout: MockData.detailedWorkout)
    }
}
