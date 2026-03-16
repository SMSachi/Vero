//
//  CheckInOptionButton.swift
//  Vero
//
//  Selection buttons for check-in flows
//

import SwiftUI

struct CheckInOptionButton: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? AppColors.textInverted : AppColors.navy)
                        .frame(width: 28)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.titleMedium)
                        .foregroundStyle(isSelected ? AppColors.textInverted : AppColors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(isSelected ? AppColors.textInverted.opacity(0.8) : AppColors.textSecondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.textInverted)
                }
            }
            .cardPaddingCompact()
            .background(isSelected ? AppColors.navy : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(isSelected ? Color.clear : AppColors.divider, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
    }
}

// MARK: - Emoji Check-In Option

struct EmojiCheckInOption: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xxs) {
                Text(emoji)
                    .font(.system(size: 32))

                Text(label)
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(isSelected ? AppColors.navy : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.navy.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(isSelected ? AppColors.navy : AppColors.divider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }
}

// MARK: - Scale Check-In Option (1-5 scale)

struct ScaleCheckInOption: View {
    let value: Int
    let maxValue: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(AppTypography.titleMedium)
                .foregroundStyle(isSelected ? AppColors.textInverted : AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .background(isSelected ? AppColors.navy : AppColors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.clear : AppColors.divider, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.9))
    }
}

// MARK: - Previews

#Preview("Check-In Options") {
    VStack(spacing: 24) {
        // Standard options
        VStack(spacing: 12) {
            Text("How are you feeling?")
                .font(AppTypography.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            CheckInOptionButton(
                title: "Great",
                subtitle: "Ready to train hard",
                icon: "sun.max.fill",
                isSelected: true
            ) {}

            CheckInOptionButton(
                title: "Good",
                subtitle: "Feeling normal",
                icon: "cloud.sun.fill",
                isSelected: false
            ) {}

            CheckInOptionButton(
                title: "Tired",
                subtitle: "Need rest",
                icon: "moon.fill",
                isSelected: false
            ) {}
        }

        Divider()

        // Emoji options
        VStack(spacing: 12) {
            Text("Rate your energy")
                .font(AppTypography.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                EmojiCheckInOption(emoji: "😴", label: "Low", isSelected: false) {}
                EmojiCheckInOption(emoji: "😐", label: "Okay", isSelected: false) {}
                EmojiCheckInOption(emoji: "😊", label: "Good", isSelected: true) {}
                EmojiCheckInOption(emoji: "🔥", label: "High", isSelected: false) {}
            }
        }

        Divider()

        // Scale options
        VStack(spacing: 12) {
            Text("Soreness level")
                .font(AppTypography.headlineSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    ScaleCheckInOption(
                        value: value,
                        maxValue: 5,
                        isSelected: value == 2
                    ) {}
                }
            }
        }
    }
    .padding()
    .background(AppColors.background)
}
