//
//  AuthContainerView.swift
//  Insio Health
//
//  Container for authentication flow (login/signup).
//  Manages terms acceptance state shared between login and signup.
//

import SwiftUI

// MARK: - Auth Container

struct AuthContainerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showLogin = true
    @State private var isAnimating = false
    @State private var acceptedTerms = false

    var body: some View {
        // NOTE: This view is only mounted when AppRootView route == .auth
        // No need to check isAuthenticated here - AppRootView handles routing
        ZStack {
            // Background
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with logo area
                AuthHeader()
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : -20)

                Spacer()

                // Auth form (login or signup)
                Group {
                    if showLogin {
                        LoginView(showLogin: $showLogin, acceptedTerms: $acceptedTerms)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        SignupView(showLogin: $showLogin, acceptedTerms: $acceptedTerms)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)

                Spacer()

                // Footer
                AuthFooter(showLogin: $showLogin)
                    .opacity(isAnimating ? 1 : 0)
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .padding(.vertical, AppSpacing.xl)
        }
        .onAppear {
            print("🔐 AuthContainerView: APPEARED")
            withAnimation(AppAnimation.entrance.delay(0.1)) {
                isAnimating = true
            }
        }
        .onDisappear {
            print("🔐 AuthContainerView: DISAPPEARED")
        }
    }
}

// MARK: - Auth Header

struct AuthHeader: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Logo/Brand
            ZStack {
                Circle()
                    .fill(AppColors.navy.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppColors.navy)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("Insio")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Your personal fitness companion")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.top, AppSpacing.xxl)
    }
}

// MARK: - Auth Footer

struct AuthFooter: View {
    @Binding var showLogin: Bool

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 4) {
                Text(showLogin ? "Don't have an account?" : "Already have an account?")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    withAnimation(AppAnimation.springQuick) {
                        showLogin.toggle()
                    }
                } label: {
                    Text(showLogin ? "Sign up" : "Log in")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(AppColors.navy)
                }
            }
        }
        .padding(.bottom, AppSpacing.md)
    }
}

// MARK: - Preview

#Preview {
    AuthContainerView()
        .environmentObject(AppState())
}
