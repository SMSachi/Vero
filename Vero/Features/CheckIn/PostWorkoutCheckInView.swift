//
//  PostWorkoutCheckInView.swift
//  Vero
//
//  Full-screen post-workout check-in - unified design system
//

import SwiftUI

struct PostWorkoutCheckInView: View {
    let workout: Workout

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFeeling: WorkoutFeeling?
    @State private var showFollowUp = false
    @State private var additionalNote = ""
    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var footerVisible = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HEADER
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: AppSpacing.Icon.circleSmall, height: AppSpacing.Icon.circleSmall)
                            .background(AppColors.divider.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.top, 16)
                .opacity(headerVisible ? 1 : 0)

                // TITLE SECTION
                VStack(spacing: AppSpacing.Layout.titleSpacing) {
                    // Workout type badge
                    HStack(spacing: 6) {
                        Image(systemName: workout.type.icon)
                            .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                        Text(workout.type.rawValue)
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundStyle(AppColors.navy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.navyTint)
                    .clipShape(Capsule())

                    // Main question
                    Text("How did that feel?")
                        .font(AppTypography.screenTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    // Context
                    Text("\(workout.durationFormatted) \u{00B7} \(workout.calories) cal")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.top, AppSpacing.Layout.sectionSpacing)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 15)

                // SELECTION CARDS (centered)
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(WorkoutFeeling.allCases.enumerated()), id: \.element) { index, feeling in
                        WorkoutFeelingButton(
                            feeling: feeling,
                            isSelected: selectedFeeling == feeling
                        ) {
                            withAnimation(AppAnimation.springBouncy) {
                                selectedFeeling = feeling
                            }

                            if feeling == .hard || feeling == .brutal {
                                withAnimation(AppAnimation.springGentle.delay(0.2)) {
                                    showFollowUp = true
                                }
                            }
                        }
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : CGFloat(15 + index * 5))
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

                Spacer()

                // FOOTER
                VStack(spacing: AppSpacing.Layout.cardSpacing) {
                    if showFollowUp {
                        VStack(spacing: AppSpacing.sm) {
                            Text("Anything worth noting?")
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppColors.textSecondary)

                            TextField("Optional note...", text: $additionalNote, axis: .vertical)
                                .font(AppTypography.bodyMedium)
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                                        .stroke(AppColors.divider, lineWidth: 1)
                                )
                                .lineLimit(3...5)
                        }
                        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if selectedFeeling != nil {
                        PrimaryButton("Done", icon: "checkmark") {
                            dismiss()
                        }
                        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        TextButton("Skip for now") {
                            dismiss()
                        }
                    }
                }
                .padding(.bottom, AppSpacing.Layout.bottomMargin)
                .opacity(footerVisible ? 1 : 0)
                .offset(y: footerVisible ? 0 : 15)
            }
        }
        .background(AppColors.background)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            cardsVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.4)) {
            footerVisible = true
        }
    }
}

// MARK: - Workout Feeling

enum WorkoutFeeling: String, CaseIterable {
    case easy = "Easy"
    case good = "Good"
    case hard = "Hard"
    case brutal = "Brutal"

    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .good: return "hand.thumbsup.fill"
        case .hard: return "flame.fill"
        case .brutal: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: return AppColors.intensityLow
        case .good: return AppColors.olive
        case .hard: return AppColors.intensityHigh
        case .brutal: return AppColors.intensityMax
        }
    }

    var description: String {
        switch self {
        case .easy: return "Felt smooth and comfortable"
        case .good: return "Challenged but in control"
        case .hard: return "Really pushed myself"
        case .brutal: return "Everything I had"
        }
    }
}

// MARK: - Workout Feeling Button

struct WorkoutFeelingButton: View {
    let feeling: WorkoutFeeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? feeling.color : feeling.color.opacity(0.12))
                        .frame(width: AppSpacing.Icon.circleMedium, height: AppSpacing.Icon.circleMedium)

                    Image(systemName: feeling.icon)
                        .font(.system(size: AppSpacing.Icon.large, weight: .medium))
                        .foregroundStyle(isSelected ? .white : feeling.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(feeling.rawValue)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(feeling.description)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: AppSpacing.Icon.xlarge, weight: .medium))
                        .foregroundStyle(feeling.color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(
                isSelected ? feeling.color.opacity(0.08) : AppColors.cardBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(isSelected ? feeling.color.opacity(0.4) : AppColors.divider, lineWidth: isSelected ? 2 : 1)
            )
            .standardShadow()
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    PostWorkoutCheckInView(workout: MockData.detailedWorkout)
}
