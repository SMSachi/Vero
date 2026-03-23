//
//  SignupView.swift
//  Insio Health
//
//  Signup screen with email/password registration.
//  Includes required terms acceptance checkbox.
//

import SwiftUI

// MARK: - Signup View

struct SignupView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var showLogin: Bool
    @Binding var acceptedTerms: Bool

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var showEmailConfirmation = false

    @FocusState private var focusedField: Field?

    enum Field {
        case fullName, email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Title
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Create account")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Start your fitness journey today")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Form
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.md) {
                    // Full name field
                    AuthTextField(
                        title: "Full name",
                        placeholder: "Your name",
                        text: $fullName,
                        keyboardType: .default,
                        textContentType: .name,
                        isFocused: focusedField == .fullName
                    )
                    .focused($focusedField, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }

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
                        placeholder: "At least 6 characters",
                        text: $password,
                        showPassword: $showPassword,
                        isFocused: focusedField == .password
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .confirmPassword
                    }

                    // Confirm password field
                    AuthSecureField(
                        title: "Confirm password",
                        placeholder: "Re-enter your password",
                        text: $confirmPassword,
                        showPassword: $showPassword,
                        isFocused: focusedField == .confirmPassword
                    )
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        signUp()
                    }

                    // Password requirements
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirement(
                                text: "At least 6 characters",
                                isMet: password.count >= 6
                            )
                            PasswordRequirement(
                                text: "Passwords match",
                                isMet: !confirmPassword.isEmpty && password == confirmPassword
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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

            // Signup button
            Button {
                signUp()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    Text(isSubmitting ? "Creating account..." : "Create account")
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
        .alert("Check your email", isPresented: $showEmailConfirmation) {
            Button("OK") {
                showLogin = true
            }
        } message: {
            Text("We've sent a confirmation link to \(email). Please verify your email to continue.")
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword &&
        acceptedTerms
    }

    // MARK: - Actions

    private func signUp() {
        guard isFormValid else { return }

        print("🔐 SignupView: signUp() started")
        focusedField = nil
        isSubmitting = true

        Task {
            do {
                print("🔐 SignupView: Calling authService.signUp...")
                try await authService.signUp(
                    email: email,
                    password: password,
                    fullName: fullName.isEmpty ? nil : fullName
                )
                print("🔐 SignupView: ✅ signUp completed successfully")
            } catch AuthError.emailConfirmationRequired {
                print("🔐 SignupView: Email confirmation required")
                showEmailConfirmation = true
            } catch {
                print("🔐 SignupView: ❌ signUp failed: \(error)")
            }
            isSubmitting = false
            print("🔐 SignupView: signUp() finished, isSubmitting=false")
        }
    }
}

// MARK: - Password Requirement

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isMet ? AppColors.olive : AppColors.textTertiary)

            Text(text)
                .font(AppTypography.captionSmall)
                .foregroundStyle(isMet ? AppColors.textSecondary : AppColors.textTertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    SignupView(showLogin: .constant(false), acceptedTerms: .constant(false))
        .padding()
        .background(AppColors.background)
}
