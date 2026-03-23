//
//  WorkoutsListView.swift
//  Insio Health
//
//  Workout list - loads real data from persistence, shows empty state when needed.
//

import SwiftUI

struct WorkoutsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: WorkoutFilter = .all
    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var showAddWorkout = false

    // Real data from persistence
    @State private var workouts: [Workout] = []
    @State private var workoutsThisWeek: Int = 0
    @State private var currentStreak: Int = 0

    private let persistenceService = PersistenceService.shared

    enum WorkoutFilter: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case strength = "Strength"
        case cycling = "Cycling"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .running: return "figure.run"
            case .strength: return "dumbbell.fill"
            case .cycling: return "bicycle"
            }
        }

        func matches(_ workout: Workout) -> Bool {
            switch self {
            case .all: return true
            case .running: return workout.type == .run || workout.type == .walk
            case .strength: return workout.type == .strength
            case .cycling: return workout.type == .cycle
            }
        }
    }

    private var filteredWorkouts: [Workout] {
        workouts
            .filter { selectedFilter.matches($0) }
            .sorted { $0.startDate > $1.startDate }
    }

    private var hasWorkouts: Bool {
        !workouts.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Header with real stats
                    WorkoutsHeaderView(
                        workoutsThisWeek: workoutsThisWeek,
                        currentStreak: currentStreak,
                        onAddTapped: { showAddWorkout = true }
                    )
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 15)

                    Spacer().frame(height: AppSpacing.Layout.sectionSpacing)

                    if hasWorkouts {
                        // Filter chips
                        FilterChipsRow(selectedFilter: $selectedFilter)
                            .opacity(headerVisible ? 1 : 0)

                        Spacer().frame(height: AppSpacing.Layout.sectionSpacing)

                        // Workout cards
                        LazyVStack(spacing: AppSpacing.Layout.cardSpacing) {
                            ForEach(Array(filteredWorkouts.enumerated()), id: \.element.id) { index, workout in
                                NavigationLink(destination: WorkoutInsightView(workout: workout)) {
                                    MinimalWorkoutCard(workout: workout)
                                }
                                .buttonStyle(CardButtonStyle())
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 15)
                                .animation(
                                    AppAnimation.springGentle.delay(Double(min(index, 5)) * 0.04),
                                    value: cardsVisible
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                    } else {
                        // Empty state
                        WorkoutsEmptyState(onAddWorkout: { showAddWorkout = true })
                            .opacity(cardsVisible ? 1 : 0)
                    }

                    // Bottom spacing
                    Spacer().frame(height: AppSpacing.Layout.bottomScrollPadding)
                }
                .padding(.top, AppSpacing.Layout.topPadding)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
        }
        .onAppear {
            // Refresh workouts on every appearance (picks up newly added workouts)
            loadWorkouts()
            startAnimations()
        }
        .sheet(isPresented: $showAddWorkout) {
            AddWorkoutView(onSave: { workout in
                workouts.insert(workout, at: 0)
                loadStats()
            })
        }
    }

    private func loadWorkouts() {
        // Load from persistence service
        workouts = persistenceService.fetchRecentWorkouts(limit: 100)
        loadStats()
    }

    private func loadStats() {
        workoutsThisWeek = persistenceService.countWorkoutsThisWeek()
        currentStreak = persistenceService.calculateCurrentStreak()
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            cardsVisible = true
        }
    }
}

// MARK: - Header

struct WorkoutsHeaderView: View {
    let workoutsThisWeek: Int
    let currentStreak: Int
    var onAddTapped: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.Layout.titleSpacing) {
                Text("Workouts")
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    StatLabel(value: "\(workoutsThisWeek)", label: "this week")
                    StatLabel(value: "\(currentStreak)", label: "day streak")
                }
            }

            Spacer()

            // Add workout button
            if let onAddTapped = onAddTapped {
                Button(action: onAddTapped) {
                    ZStack {
                        Circle()
                            .fill(AppColors.navy)
                            .frame(width: 40, height: 40)

                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

struct StatLabel: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(AppTypography.cardSubtitle)
                .foregroundStyle(AppColors.navy)

            Text(label)
                .font(AppTypography.miniLabel)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}

// MARK: - Filter Chips

struct FilterChipsRow: View {
    @Binding var selectedFilter: WorkoutsListView.WorkoutFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(WorkoutsListView.WorkoutFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        icon: filter.icon,
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(AppAnimation.springBouncy) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}

struct FilterChip: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: AppSpacing.Icon.small, weight: .medium))

                Text(title)
                    .font(AppTypography.chipText)
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.navy : AppColors.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.divider, lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Minimal Workout Card

struct MinimalWorkoutCard: View {
    let workout: Workout

    private var accentColor: Color {
        switch workout.intensity {
        case .low: return AppColors.olive
        case .moderate: return AppColors.navy
        case .high: return AppColors.coral
        case .max: return AppColors.orange
        }
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startDate) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.startDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: workout.startDate)
        }
    }

    private var oneLiner: String {
        let full = workout.interpretation
        if full.isEmpty {
            return "\(workout.durationFormatted) \(workout.type.rawValue.lowercased()) workout"
        }
        if let dotIndex = full.firstIndex(of: ".") {
            return String(full[...dotIndex])
        }
        return full
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Type icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                Image(systemName: workout.type.icon)
                    .font(.system(size: AppSpacing.Icon.large, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Type + date
                HStack {
                    Text(workout.type.rawValue)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\u{00B7}")
                        .foregroundStyle(AppColors.textTertiary)

                    Text(dateLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                // One sentence insight
                Text(oneLiner)
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Metrics compact
            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.durationFormatted)
                    .font(AppTypography.cardSubtitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(workout.calories) cal")
                    .font(AppTypography.miniLabel)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: AppSpacing.Icon.small, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.Layout.cardPadding)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
        .standardShadow()
    }
}

// MARK: - Preview

#Preview {
    WorkoutsListView()
        .environmentObject(AppState())
}
