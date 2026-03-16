//
//  MountainIntroView.swift
//  Vero
//
//  Premium onboarding screen with stylized mountain/path concept
//

import SwiftUI

struct MountainIntroView: View {
    @EnvironmentObject var state: OnboardingState
    @State private var currentPhase = 0
    @State private var dotsVisible: [Bool] = Array(repeating: false, count: 12)

    private let phrases = [
        "Workouts aren't all the same.",
        "Your workout today won't be the same as last week.",
        "Those differences have meaning.",
        "Vero helps you understand them."
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mountain visualization with dots
            MountainPathView(dotsVisible: dotsVisible)
                .frame(height: 280)
                .padding(.horizontal, AppSpacing.screenHorizontal)

            Spacer()
                .frame(height: AppSpacing.xxl)

            // Animated text
            VStack(spacing: AppSpacing.md) {
                ForEach(0..<phrases.count, id: \.self) { index in
                    Text(phrases[index])
                        .font(index == phrases.count - 1 ? AppTypography.headlineMedium : AppTypography.bodyLarge)
                        .foregroundStyle(index == phrases.count - 1 ? AppColors.navy : AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(currentPhase > index ? 1 : 0)
                        .offset(y: currentPhase > index ? 0 : 15)
                        .animation(AppAnimation.springGentle.delay(Double(index) * 0.12), value: currentPhase)
                }
            }
            .padding(.horizontal, AppSpacing.xl)

            Spacer()

            // CTA
            PrimaryButton("Continue") {
                state.nextStep()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxl)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Animate dots appearing
        for i in 0..<dotsVisible.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation(AppAnimation.springBouncy) {
                    dotsVisible[i] = true
                }
            }
        }

        // Animate text phrases
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(AppAnimation.springGentle) {
                currentPhase = phrases.count
            }
        }
    }
}

// MARK: - Mountain Path Visualization

struct MountainPathView: View {
    let dotsVisible: [Bool]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Mountain silhouette
                MountainShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.navy.opacity(0.08),
                                AppColors.navy.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Path line
                MountainPathLine()
                    .stroke(
                        AppColors.navy.opacity(0.2),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6])
                    )

                // Workout dots along the path
                ForEach(0..<dotsVisible.count, id: \.self) { index in
                    let position = dotPosition(index: index, in: geometry.size)
                    let size = dotSize(index: index)
                    let color = dotColor(index: index)

                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                        .position(position)
                        .opacity(dotsVisible[index] ? 1 : 0)
                        .scaleEffect(dotsVisible[index] ? 1 : 0.3)
                }
            }
        }
    }

    private func dotPosition(index: Int, in size: CGSize) -> CGPoint {
        let progress = Double(index) / Double(dotsVisible.count - 1)
        let x = size.width * 0.1 + (size.width * 0.8 * progress)

        // Create a wave pattern that goes up the mountain
        let baseY = size.height * 0.8
        let peakY = size.height * 0.2
        let verticalProgress = sin(progress * .pi) // Creates arc
        let waveOffset = sin(progress * .pi * 3) * 20 // Small waves
        let y = baseY - (baseY - peakY) * verticalProgress + waveOffset

        return CGPoint(x: x, y: y)
    }

    private func dotSize(index: Int) -> CGFloat {
        // Vary sizes to show different workout intensities
        let sizes: [CGFloat] = [8, 12, 10, 14, 8, 16, 10, 12, 8, 14, 10, 12]
        return sizes[index % sizes.count]
    }

    private func dotColor(index: Int) -> Color {
        // Vary colors to show different workout types
        let colors: [Color] = [
            AppColors.intensityLow,
            AppColors.intensityModerate,
            AppColors.intensityHigh,
            AppColors.olive,
            AppColors.intensityModerate,
            AppColors.coral,
            AppColors.intensityLow,
            AppColors.intensityHigh,
            AppColors.olive,
            AppColors.coral,
            AppColors.intensityModerate,
            AppColors.navy
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Mountain Shape

struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))

        // Left slope
        path.addLine(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.6))
        path.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.7))

        // Main peak
        path.addLine(to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.width * 0.55, y: rect.height * 0.25))

        // Right slope
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.4))

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Mountain Path Line

struct MountainPathLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.8))

        path.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.2),
            control1: CGPoint(x: rect.width * 0.25, y: rect.height * 0.6),
            control2: CGPoint(x: rect.width * 0.4, y: rect.height * 0.3)
        )

        path.addCurve(
            to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.75),
            control1: CGPoint(x: rect.width * 0.6, y: rect.height * 0.1),
            control2: CGPoint(x: rect.width * 0.75, y: rect.height * 0.5)
        )

        return path
    }
}

#Preview {
    MountainIntroView()
        .environmentObject(OnboardingState())
}
