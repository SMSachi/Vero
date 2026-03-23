//
//  LoginView.swift
//  Insio Health
//
//  Login screen with email/password authentication.
//  Includes required terms acceptance checkbox.
//

import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Binding var showLogin: Bool
    @Binding var acceptedTerms: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var showResetPassword = false

    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Title
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Welcome back")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Sign in to continue your journey")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Form
            VStack(spacing: AppSpacing.md) {
                // Email field
                AuthTextField(
                    title: "Email",
                    placeholder: "your@email.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    isFocused: focusedField == .email
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }

                // Password field
                AuthSecureField(
                    title: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    showPassword: $showPassword,
                    isFocused: focusedField == .password
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    login()
                }

                // Forgot password
                HStack {
                    Spacer()
                    Button {
                        showResetPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(AppColors.navy)
                    }
                }
            }

            // Terms acceptance checkbox
            TermsAcceptanceCheckbox(isAccepted: $acceptedTerms)

            // Error message
            if let error = authService.errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text(error)
                        .font(AppTypography.bodySmall)
                }
                .foregroundStyle(AppColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Login button
            Button {
                login()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    Text(isSubmitting ? "Signing in..." : "Sign in")
                        .font(AppTypography.buttonLarge)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(isFormValid ? AppColors.navy : AppColors.navy.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            }
            .disabled(!isFormValid || isSubmitting)
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordView()
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6 && acceptedTerms
    }

    // MARK: - Actions

    private func login() {
        guard isFormValid else { return }

        print("🔐 LoginView: [v2] login() started")

        // CRITICAL: Dismiss keyboard FIRST before any async work
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Force end editing on all windows
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.endEditing(true)
                }
            }
        }

        isSubmitting = true

        Task {
            // Small delay to let keyboard dismiss complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            do {
                print("🔐 LoginView: [v2] Calling authService.signIn...")
                try await authService.signIn(email: email, password: password)
                print("🔐 LoginView: [v2] ✅ signIn completed successfully")
            } catch {
                print("🔐 LoginView: [v2] ❌ signIn failed: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
            // Note: isSubmitting is NOT set to false here on success
            // The view will be replaced by MainTabView, so no need
            print("🔐 LoginView: [v2] login() task finished")
        }
    }
}

// MARK: - Terms Acceptance Checkbox

struct TermsAcceptanceCheckbox: View {
    @Binding var isAccepted: Bool

    var body: some View {
        Button {
            withAnimation(AppAnimation.springQuick) {
                isAccepted.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isAccepted ? AppColors.navy : AppColors.divider, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isAccepted {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.navy)
                            .frame(width: 20, height: 20)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Text with links
                VStack(alignment: .leading, spacing: 2) {
                    Text("I agree to the ")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                    +
                    Text("Terms of Service")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.navy)
                        .underline()
                    +
                    Text(" and ")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                    +
                    Text("Privacy Policy")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.navy)
                        .underline()
                }
                .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            // Invisible link buttons for Terms and Privacy
            HStack(spacing: 0) {
                Spacer().frame(width: 28) // Checkbox + spacing

                // Terms link
                Link(destination: InsioConfig.Legal.termsOfServiceURL) {
                    Color.clear
                        .frame(width: 100, height: 20)
                }

                // Privacy link
                Link(destination: InsioConfig.Legal.privacyPolicyURL) {
                    Color.clear
                        .frame(width: 90, height: 20)
                }
            }
            .allowsHitTesting(true)
        }
    }
}

// MARK: - Reset Password View

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var isSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Reset password")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Enter your email and we'll send you a link to reset your password")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSuccess {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.olive)
                        Text("Check your email for reset instructions")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.olive.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium))
                } else {
                    AuthTextField(
                        title: "Email",
                        placeholder: "your@email.com",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        isFocused: false
                    )

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        resetPassword()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            }
                            Text(isSubmitting ? "Sending..." : "Send reset link")
                                .font(AppTypography.buttonLarge)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(email.contains("@") ? AppColors.navy : AppColors.navy.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                    }
                    .disabled(!email.contains("@") || isSubmitting)
                }

                Spacer()
            }
            .padding(AppSpacing.Layout.horizontalMargin)
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.navy)
                }
            }
        }
    }

    private func resetPassword() {
        isSubmitting = true
        Task {
            do {
                try await authService.resetPassword(email: email)
                isSuccess = true
            } catch {
                // Error handled by authService
            }
            isSubmitting = false
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView(showLogin: .constant(true), acceptedTerms: .constant(false))
        .padding()
        .background(AppColors.background)
}
