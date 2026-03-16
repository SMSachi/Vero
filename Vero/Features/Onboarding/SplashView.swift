//
//  SplashView.swift
//  Vero
//
//  Initial splash screen with wordmark and CTA
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var state: OnboardingState
    @State private var isAnimating = false
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and wordmark
            VStack(spacing: AppSpacing.lg) {
                // Wordmark
                Text("Vero")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.navy)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Subtitle
                Text("Understand what your\nworkouts actually mean.")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }

            Spacer()

            // CTA Button
            VStack(spacing: AppSpacing.sm) {
                PrimaryButton("Get Started", icon: "arrow.right") {
                    state.nextStep()
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxl)
        }
        .onAppear {
            withAnimation(AppAnimation.entrance.delay(0.3)) {
                showContent = true
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(OnboardingState())
}
