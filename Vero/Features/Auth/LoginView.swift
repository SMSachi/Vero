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

        print("🔐 LoginView: [v4] login() STARTED")

        // Dismiss keyboard
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        isSubmitting = true

        Task { @MainActor in
            do {
                print("🔐 LoginView: [v4] Calling authService.signIn...")
                try await authService.signIn(email: email, password: password)
                print("🔐 LoginView: [v4] ✅ signIn returned, isAuthenticated=\(authService.isAuthenticated)")

                // Reset state - view will be replaced by MainTabView
                isSubmitting = false

                // Post notification to force UI transition
                NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                print("🔐 LoginView: [v4] ✅ DONE - posted authStateDidChange notification")

            } catch {
                print("🔐 LoginView: [v4] ❌ Error: \(error)")
                isSubmitting = false
            }
        }
    }
}

// MARK: - Terms Acceptance Checkbox

struct TermsAcceptanceCheckbox: View {
    @Binding var isAccepted: Bool
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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

                    // Text
                    Text("I agree to the Terms of Service and Privacy Policy")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // In-app links for Terms and Privacy
            HStack(spacing: AppSpacing.md) {
                Spacer().frame(width: 20) // Align with text above

                Button {
                    showTerms = true
                } label: {
                    Text("Terms of Service")
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.navy)
                        .underline()
                }

                Button {
                    showPrivacy = true
                } label: {
                    Text("Privacy Policy")
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.navy)
                        .underline()
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyView()
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
