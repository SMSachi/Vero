//
//  CalendarDayCell.swift
//  Insio Health
//
//  Calendar day cells for workout history
//

import SwiftUI

struct CalendarDayCell: View {
    let day: Int
    let isCurrentMonth: Bool
    var isToday: Bool = false
    var isSelected: Bool = false
    var hasWorkout: Bool = false
    var workoutIntensity: WorkoutIntensity? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: AppSpacing.xxxs) {
                // Day number
                Text("\(day)")
                    .font(isToday ? AppTypography.titleMedium : AppTypography.bodySmall)
                    .foregroundStyle(dayTextColor)

                // Workout indicator
                if hasWorkout {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 40, height: 44)
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusSmall)
                    .stroke(isToday && !isSelected ? AppColors.navy : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
        .disabled(action == nil)
    }

    private var dayTextColor: Color {
        if isSelected {
            return AppColors.textInverted
        } else if !isCurrentMonth {
            return AppColors.textTertiary
        } else if isToday {
            return AppColors.navy
        } else {
            return AppColors.textPrimary
        }
    }

    private var backgroundStyle: Color {
        if isSelected {
            return AppColors.navy
        } else {
            return Color.clear
        }
    }

    private var indicatorColor: Color {
        guard let intensity = workoutIntensity else {
            return AppColors.olive
        }
        switch intensity {
        case .low: return AppColors.intensityLow
        case .moderate: return AppColors.intensityModerate
        case .high: return AppColors.intensityHigh
        case .max: return AppColors.intensityMax
        }
    }
}

// MARK: - Calendar Week Row

struct CalendarWeekRow: View {
    let days: [CalendarDay]
    let selectedDay: Int?
    let onDaySelected: (Int) -> Void

    struct CalendarDay: Identifiable {
        let id = UUID()
        let day: Int
        let isCurrentMonth: Bool
        var isToday: Bool = false
        var hasWorkout: Bool = false
        var workoutIntensity: WorkoutIntensity? = nil
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                CalendarDayCell(
                    day: day.day,
                    isCurrentMonth: day.isCurrentMonth,
                    isToday: day.isToday,
                    isSelected: selectedDay == day.day && day.isCurrentMonth,
                    hasWorkout: day.hasWorkout,
                    workoutIntensity: day.workoutIntensity
                ) {
                    if day.isCurrentMonth {
                        onDaySelected(day.day)
                    }
                }
            }
        }
    }
}

// MARK: - Week Day Header

struct WeekDayHeader: View {
    // Use enumerated to avoid duplicate IDs (T appears twice, S appears twice)
    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 40)
            }
        }
    }
}

// MARK: - Previews

#Preview("Calendar Components") {
    VStack(spacing: 24) {
        // Week day headers
        WeekDayHeader()

        // Sample week
        CalendarWeekRow(
            days: [
                .init(day: 10, isCurrentMonth: true, hasWorkout: true, workoutIntensity: .moderate),
                .init(day: 11, isCurrentMonth: true),
                .init(day: 12, isCurrentMonth: true, hasWorkout: true, workoutIntensity: .high),
                .init(day: 13, isCurrentMonth: true),
                .init(day: 14, isCurrentMonth: true, hasWorkout: true, workoutIntensity: .low),
                .init(day: 15, isCurrentMonth: true, isToday: true, hasWorkout: true, workoutIntensity: .moderate),
                .init(day: 16, isCurrentMonth: true)
            ],
            selectedDay: 12
        ) { day in
            print("Selected day: \(day)")
        }

        // Another week with some days from next month
        CalendarWeekRow(
            days: [
                .init(day: 28, isCurrentMonth: true),
                .init(day: 29, isCurrentMonth: true, hasWorkout: true, workoutIntensity: .max),
                .init(day: 30, isCurrentMonth: true),
                .init(day: 31, isCurrentMonth: true),
                .init(day: 1, isCurrentMonth: false),
                .init(day: 2, isCurrentMonth: false),
                .init(day: 3, isCurrentMonth: false)
            ],
            selectedDay: nil
        ) { _ in }

        Divider()

        // Individual cells
        HStack(spacing: 8) {
            CalendarDayCell(day: 15, isCurrentMonth: true, isToday: true)
            CalendarDayCell(day: 12, isCurrentMonth: true, isSelected: true, hasWorkout: true)
            CalendarDayCell(day: 8, isCurrentMonth: true, hasWorkout: true, workoutIntensity: .high)
            CalendarDayCell(day: 3, isCurrentMonth: false)
        }
    }
    .padding()
    .background(AppColors.background)
}
