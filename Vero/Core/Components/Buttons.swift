//
//  Buttons.swift
//  Vero
//
//  Premium button components with personality
//

import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var size: ButtonSize = .large
    var style: PrimaryButtonStyle = .navy

    enum PrimaryButtonStyle {
        case navy, olive, orange

        var backgroundColor: Color {
            switch self {
            case .navy: return AppColors.navy
            case .olive: return AppColors.olive
            case .orange: return AppColors.orange
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        size: ButtonSize = .large,
        style: PrimaryButtonStyle = .navy,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.size = size
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    Text(title)
                        .font(size.textFont)

                    if let icon = icon {
                        Image(systemName: icon)
                            .font(size.iconFont)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .foregroundStyle(AppColors.buttonPrimaryForeground)
            .background(
                isDisabled ? AppColors.textTertiary : style.backgroundColor
            )
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    var size: ButtonSize = .large

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        size: ButtonSize = .large,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                Text(title)
                    .font(size.textFont)
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .foregroundStyle(isDisabled ? AppColors.textTertiary : AppColors.buttonSecondaryForeground)
            .background(AppColors.buttonSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(AppColors.buttonSecondaryBorder, lineWidth: 1.5)
            )
        }
        .disabled(isDisabled)
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Soft Button (tinted background)

struct SoftButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var tint: Color = AppColors.navy
    var size: ButtonSize = .medium

    init(
        _ title: String,
        icon: String? = nil,
        tint: Color = AppColors.navy,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }
                Text(title)
                    .font(size.textFont)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: size.height)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Text Button

struct TextButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var color: Color = AppColors.navy
    var iconPosition: IconPosition = .trailing

    enum IconPosition {
        case leading, trailing
    }

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = AppColors.navy,
        iconPosition: IconPosition = .trailing,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.iconPosition = iconPosition
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxxs) {
                if iconPosition == .leading, let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(title)
                    .font(AppTypography.buttonSmall)

                if iconPosition == .trailing, let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(color)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 44
    var tint: Color = AppColors.navy
    var background: Color = AppColors.navyTint

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Pill Button (for selections)

struct PillButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(AppTypography.labelMedium)
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
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

// MARK: - Button Size

enum ButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 54
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return AppSpacing.radiusSmall
        case .medium: return AppSpacing.radiusMedium
        case .large: return AppSpacing.radiusMedium
        }
    }

    var textFont: Font {
        switch self {
        case .small: return AppTypography.buttonSmall
        case .medium: return AppTypography.buttonMedium
        case .large: return AppTypography.buttonLarge
        }
    }

    var iconFont: Font {
        switch self {
        case .small: return .system(size: 12, weight: .semibold)
        case .medium: return .system(size: 14, weight: .semibold)
        case .large: return .system(size: 16, weight: .semibold)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(AppAnimation.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Buttons") {
    ScrollView {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Primary").font(AppTypography.labelLarge)
                PrimaryButton("Get Started", icon: "arrow.right") {}
                PrimaryButton("Recovery", icon: "leaf.fill", style: .olive) {}
                PrimaryButton("Loading...", isLoading: true) {}
            }

            VStack(spacing: 12) {
                Text("Secondary").font(AppTypography.labelLarge)
                SecondaryButton("Learn More", icon: "book") {}
            }

            VStack(spacing: 12) {
                Text("Soft").font(AppTypography.labelLarge)
                HStack {
                    SoftButton("Filter", icon: "line.3.horizontal.decrease") {}
                    SoftButton("Today", tint: AppColors.olive) {}
                }
            }

            VStack(spacing: 12) {
                Text("Pills").font(AppTypography.labelLarge)
                HStack {
                    PillButton(title: "Week", icon: nil, isSelected: true) {}
                    PillButton(title: "Month", icon: nil, isSelected: false) {}
                    PillButton(title: "Year", icon: nil, isSelected: false) {}
                }
            }
        }
        .padding()
    }
    .background(AppColors.background)
}
