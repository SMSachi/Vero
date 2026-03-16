//
//  OnboardingCompleteView.swift
//  Vero
//
//  Final success screen - using unified layout system
//

import SwiftUI

struct OnboardingCompleteView: View {
    @EnvironmentObject var state: OnboardingState

    // Animation states
    @State private var ringVisible = false
    @State private var checkmarkVisible = false
    @State private var particlesVisible = false
    @State private var textVisible = false
    @State private var ctaVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ═══════════════════════════════════════════
            // CHECKMARK ANIMATION
            // ═══════════════════════════════════════════

            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(AppColors.navy.opacity(0.15), lineWidth: 3)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringVisible ? 1.2 : 0.8)
                    .opacity(ringVisible ? 0 : 0.8)

                // Success particles
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(particleColor(index: index))
                        .frame(width: 10, height: 10)
                        .offset(particleOffset(index: index))
                        .opacity(particlesVisible ? 0 : 1)
                        .scaleEffect(particlesVisible ? 0.2 : 1)
                }

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.navy, AppColors.navy.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(checkmarkVisible ? 1 : 0.3)
                    .opacity(checkmarkVisible ? 1 : 0)
                    .shadow(color: AppColors.navy.opacity(0.3), radius: 20, x: 0, y: 8)

                // Checkmark icon
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(checkmarkVisible ? 1 : 0)
                    .opacity(checkmarkVisible ? 1 : 0)
            }
            .frame(height: 160)

            Spacer().frame(height: AppSpacing.Layout.sectionSpacing * 2)

            // ═══════════════════════════════════════════
            // TEXT
            // ═══════════════════════════════════════════

            VStack(spacing: AppSpacing.Layout.titleSpacing) {
                Text("You're all set")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Your workouts now tell a story.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .multilineTextAlignment(.center)
            .opacity(textVisible ? 1 : 0)
            .offset(y: textVisible ? 0 : 20)

            Spacer()

            // ═══════════════════════════════════════════
            // CTA
            // ═══════════════════════════════════════════

            PrimaryButton("Start Using Vero", icon: "arrow.right") {
                state.completeOnboarding()
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .padding(.bottom, AppSpacing.Layout.bottomMargin)
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 20)
        }
        .background(AppColors.background)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(AppAnimation.springGentle.delay(0.1)) {
            ringVisible = true
        }

        withAnimation(AppAnimation.springBouncy.delay(0.2)) {
            checkmarkVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.6)) {
                particlesVisible = true
            }
        }

        withAnimation(AppAnimation.entrance.delay(0.5)) {
            textVisible = true
        }

        withAnimation(AppAnimation.entrance.delay(0.7)) {
            ctaVisible = true
        }
    }

    private func particleOffset(index: Int) -> CGSize {
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180
        let radius: Double = particlesVisible ? 90 : 45
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }

    private func particleColor(index: Int) -> Color {
        let colors: [Color] = [
            AppColors.navy,
            AppColors.olive,
            AppColors.coral,
            AppColors.navy.opacity(0.6)
        ]
        return colors[index % colors.count]
    }
}

#Preview {
    OnboardingCompleteView()
        .environmentObject(OnboardingState())
}
