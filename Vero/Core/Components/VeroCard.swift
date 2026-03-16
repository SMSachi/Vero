//
//  VeroCard.swift
//  Vero
//
//  Standardized card component for consistent styling
//  Corner radius: 16, Padding: 16, Spacing: 16
//

import SwiftUI

// MARK: - Standard Card

/// Base card with consistent styling across the app
struct VeroCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color
    var showBorder: Bool
    var borderColor: Color

    init(
        backgroundColor: Color = AppColors.cardBackground,
        showBorder: Bool = false,
        borderColor: Color = AppColors.divider,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(showBorder ? borderColor : Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Selectable Card

/// Card that can be selected/deselected with visual feedback
struct VeroSelectableCard<Content: View>: View {
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    let content: Content

    init(
        isSelected: Bool,
        accentColor: Color = AppColors.navy,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.accentColor = accentColor
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(AppSpacing.Layout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? accentColor.opacity(0.08) : AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                        .stroke(
                            isSelected ? accentColor : AppColors.divider,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.06 : 0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Tappable Card

/// Card with tap action and chevron indicator
struct VeroTappableCard<Content: View>: View {
    let action: () -> Void
    let content: Content
    var showChevron: Bool

    init(
        showChevron: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.showChevron = showChevron
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                content

                if showChevron {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Icon Card (for selections with icon)

/// Selection card with icon, title, and optional description
struct VeroIconCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        icon: String,
        iconColor: Color = AppColors.navy,
        title: String,
        description: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? iconColor : iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if let description = description {
                        Text(description)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.navy : AppColors.divider)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(isSelected ? iconColor.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(
                        isSelected ? iconColor.opacity(0.3) : AppColors.divider,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Toggle Card

/// Card with toggle switch
struct VeroToggleCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(AppAnimation.springBouncy) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isOn ? iconColor : iconColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isOn ? .white : iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(description)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Toggle indicator
                ZStack {
                    Circle()
                        .fill(isOn ? AppColors.navy : AppColors.divider)
                        .frame(width: 24, height: 24)

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(isOn ? iconColor.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(
                        isOn ? iconColor.opacity(0.3) : AppColors.divider,
                        lineWidth: isOn ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.springBouncy, value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            VeroCard {
                Text("Basic Card")
                    .font(.system(size: 16, weight: .semibold))
            }

            VeroSelectableCard(isSelected: true, action: {}) {
                Text("Selected Card")
                    .font(.system(size: 16, weight: .semibold))
            }

            VeroSelectableCard(isSelected: false, action: {}) {
                Text("Unselected Card")
                    .font(.system(size: 16, weight: .semibold))
            }

            VeroTappableCard(action: {}) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tappable Card")
                        .font(.system(size: 16, weight: .semibold))
                    Text("With chevron indicator")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            VeroIconCard(
                icon: "flame.fill",
                iconColor: AppColors.coral,
                title: "Build Endurance",
                description: "Improve aerobic capacity",
                isSelected: true,
                action: {}
            )

            VeroIconCard(
                icon: "dumbbell.fill",
                iconColor: AppColors.navy,
                title: "Build Strength",
                description: "Power and muscle",
                isSelected: false,
                action: {}
            )
        }
        .padding(20)
    }
    .background(AppColors.background)
}
