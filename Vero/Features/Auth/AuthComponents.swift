//
//  AuthComponents.swift
//  Insio Health
//
//  Reusable form components for authentication screens.
//  Matches Insio's premium design language.
//

import SwiftUI

// MARK: - Auth Text Field

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.labelSmall)
                .foregroundStyle(AppColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                        .stroke(
                            isFocused ? AppColors.navy : AppColors.divider,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .animation(AppAnimation.springQuick, value: isFocused)
        }
    }
}

// MARK: - Auth Secure Field

struct AuthSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.labelSmall)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary)
                .textContentType(.password)
                .autocapitalization(.none)
                .autocorrectionDisabled()

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(
                        isFocused ? AppColors.navy : AppColors.divider,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(AppAnimation.springQuick, value: isFocused)
        }
    }
}

// MARK: - Auth Button

struct AuthButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let style: Style
    let action: () -> Void

    enum Style {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style == .primary ? .white : AppColors.navy))
                        .scaleEffect(0.9)
                }
                Text(title)
                    .font(AppTypography.buttonLarge)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(style == .secondary ? AppColors.navy : .clear, lineWidth: 1)
            )
        }
        .disabled(!isEnabled || isLoading)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? AppColors.navy : AppColors.navy.opacity(0.5)
        case .secondary:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return isEnabled ? AppColors.navy : AppColors.navy.opacity(0.5)
        }
    }
}

// MARK: - Social Auth Button

struct SocialAuthButton: View {
    let provider: Provider
    let action: () -> Void

    enum Provider {
        case apple
        case google

        var icon: String {
            switch self {
            case .apple: return "apple.logo"
            case .google: return "g.circle.fill"
            }
        }

        var title: String {
            switch self {
            case .apple: return "Continue with Apple"
            case .google: return "Continue with Google"
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: provider.icon)
                    .font(.system(size: 18, weight: .medium))

                Text(provider.title)
                    .font(AppTypography.buttonMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.cardBackground)
            .foregroundStyle(AppColors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(AppColors.divider, lineWidth: 1)
            )
        }
    }
}

// MARK: - Auth Divider

struct AuthDivider: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)

            Text("or")
                .font(AppTypography.captionSmall)
                .foregroundStyle(AppColors.textTertiary)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
    }
}

// MARK: - Previews

#Preview("Text Field") {
    VStack(spacing: 20) {
        AuthTextField(
            title: "Email",
            placeholder: "your@email.com",
            text: .constant(""),
            keyboardType: .emailAddress
        )

        AuthTextField(
            title: "Email (Focused)",
            placeholder: "your@email.com",
            text: .constant("test@example.com"),
            keyboardType: .emailAddress,
            isFocused: true
        )
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Secure Field") {
    VStack(spacing: 20) {
        AuthSecureField(
            title: "Password",
            placeholder: "Enter password",
            text: .constant(""),
            showPassword: .constant(false)
        )

        AuthSecureField(
            title: "Password (Visible)",
            placeholder: "Enter password",
            text: .constant("secret123"),
            showPassword: .constant(true)
        )
    }
    .padding()
    .background(AppColors.background)
}
