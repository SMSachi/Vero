//
//  NextDayCheckInView.swift
//  Vero
//
//  Full-screen next-day recovery check-in - unified design system
//

import SwiftUI

struct NextDayCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFeeling: BodyFeeling?
    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var footerVisible = false

    private let previousWorkout = MockData.detailedWorkout

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
                    // Context badge
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: AppSpacing.Icon.medium, weight: .semibold))
                        Text("Morning check-in")
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundStyle(AppColors.olive)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.oliveTint)
                    .clipShape(Capsule())

                    // Main question
                    Text("How does your body feel?")
                        .font(AppTypography.screenTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    // Context from yesterday
                    Text("After yesterday's \(previousWorkout.type.rawValue.lowercased())")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.top, AppSpacing.Layout.sectionSpacing)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 15)

                // SELECTION CARDS (centered)
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(BodyFeeling.allCases.enumerated()), id: \.element) { index, feeling in
                        BodyFeelingButton(
                            feeling: feeling,
                            isSelected: selectedFeeling == feeling
                        ) {
                            withAnimation(AppAnimation.springBouncy) {
                                selectedFeeling = feeling
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

// MARK: - Body Feeling

enum BodyFeeling: String, CaseIterable {
    case fresh = "Fresh"
    case slightlySore = "Slightly sore"
    case prettySore = "Pretty sore"
    case drained = "Drained"

    var icon: String {
        switch self {
        case .fresh: return "sparkles"
        case .slightlySore: return "figure.walk"
        case .prettySore: return "bandage.fill"
        case .drained: return "battery.25percent"
        }
    }

    var color: Color {
        switch self {
        case .fresh: return AppColors.recoveryExcellent
        case .slightlySore: return AppColors.recoveryGood
        case .prettySore: return AppColors.recoveryModerate
        case .drained: return AppColors.recoveryLow
        }
    }

    var description: String {
        switch self {
        case .fresh: return "Ready for anything"
        case .slightlySore: return "A little tight, but good"
        case .prettySore: return "Feeling yesterday's effort"
        case .drained: return "Need more recovery time"
        }
    }
}

// MARK: - Body Feeling Button

struct BodyFeelingButton: View {
    let feeling: BodyFeeling
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
    NextDayCheckInView()
}
