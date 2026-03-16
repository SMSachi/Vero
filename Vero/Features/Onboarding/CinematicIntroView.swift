//
//  CinematicIntroView.swift
//  Vero
//
//  Cinematic mountain journey with zoom animation
//  Starts zoomed-in, climbs upward, zooms out to reveal the mountain
//

import SwiftUI

struct CinematicIntroView: View {
    @EnvironmentObject var state: OnboardingState

    // Animation states
    @State private var currentStep: Int = 0
    @State private var textOpacity: Double = 0
    @State private var showContinue: Bool = false
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.9

    // Zoom/pan states
    @State private var zoomScale: CGFloat = 3.5
    @State private var offsetY: CGFloat = 200
    @State private var pathProgress: CGFloat = 0

    private let steps: [JourneyStep] = [
        JourneyStep(
            text: "Every workout tells a story.",
            zoomScale: 3.2,
            offsetY: 180,
            pathProgress: 0.15
        ),
        JourneyStep(
            text: "Some sessions feel stronger.",
            zoomScale: 2.6,
            offsetY: 120,
            pathProgress: 0.35
        ),
        JourneyStep(
            text: "Some cost more recovery.",
            zoomScale: 2.0,
            offsetY: 60,
            pathProgress: 0.55
        ),
        JourneyStep(
            text: "Those differences have meaning.",
            zoomScale: 1.4,
            offsetY: 0,
            pathProgress: 0.75
        ),
        JourneyStep(
            text: "Vero helps you understand them.",
            zoomScale: 1.0,
            offsetY: -20,
            pathProgress: 1.0
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                AppColors.background
                    .ignoresSafeArea()

                // Mountain visualization with zoom
                MountainJourneyView(
                    progress: pathProgress,
                    geometry: geometry
                )
                .scaleEffect(zoomScale)
                .offset(y: offsetY)

                // Gradient overlays for depth
                VStack {
                    LinearGradient(
                        colors: [AppColors.background, AppColors.background.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.15)

                    Spacer()

                    LinearGradient(
                        colors: [AppColors.background.opacity(0), AppColors.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.4)
                }
                .ignoresSafeArea()

                // Content overlay
                VStack(spacing: 0) {
                    Spacer()

                    // Story text
                    if currentStep < steps.count {
                        Text(steps[currentStep].text)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                            .padding(.horizontal, AppSpacing.xl)
                    }

                    Spacer()
                        .frame(height: geometry.size.height * 0.08)

                    // Tap to continue indicator (during journey)
                    if !showContinue && currentStep < steps.count {
                        Button {
                            advanceStep()
                        } label: {
                            VStack(spacing: AppSpacing.xs) {
                                Text("Tap to continue")
                                    .font(AppTypography.captionMedium)
                                    .foregroundStyle(AppColors.textTertiary)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .opacity(textOpacity * 0.7)
                        }
                    }

                    // Final CTA
                    if showContinue {
                        VStack(spacing: AppSpacing.lg) {
                            // Logo reveal
                            VStack(spacing: AppSpacing.xs) {
                                Text("vero")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.navy)

                                Text("Understand your effort")
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .opacity(logoOpacity)
                            .scaleEffect(logoScale)

                            Spacer()
                                .frame(height: AppSpacing.lg)

                            PrimaryButton("Begin", icon: "arrow.right") {
                                state.nextStep()
                            }
                            .padding(.horizontal, AppSpacing.screenHorizontal)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()
                        .frame(height: AppSpacing.xxl)
                }
            }
        }
        .onAppear {
            startSequence()
        }
    }

    private func startSequence() {
        // Initial state
        zoomScale = 3.5
        offsetY = 200
        pathProgress = 0

        // Begin animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showStep(0)
        }
    }

    private func showStep(_ step: Int) {
        guard step < steps.count else {
            completeJourney()
            return
        }

        currentStep = step
        let journeyStep = steps[step]

        // Animate zoom, offset, and path together
        withAnimation(.easeInOut(duration: 1.2)) {
            zoomScale = journeyStep.zoomScale
            offsetY = journeyStep.offsetY
            pathProgress = journeyStep.pathProgress
        }

        // Fade in text
        withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
            textOpacity = 1
        }
    }

    private func advanceStep() {
        // Fade out current text
        withAnimation(.easeOut(duration: 0.25)) {
            textOpacity = 0
        }

        // Show next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showStep(currentStep + 1)
        }
    }

    private func completeJourney() {
        withAnimation(.easeOut(duration: 0.3)) {
            textOpacity = 0
        }

        withAnimation(AppAnimation.springGentle.delay(0.3)) {
            showContinue = true
        }

        withAnimation(AppAnimation.springGentle.delay(0.5)) {
            logoOpacity = 1
            logoScale = 1
        }
    }
}

// MARK: - Journey Step

struct JourneyStep {
    let text: String
    let zoomScale: CGFloat
    let offsetY: CGFloat
    let pathProgress: CGFloat
}

// MARK: - Mountain Journey View

struct MountainJourneyView: View {
    let progress: CGFloat
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // Background mountain layers (parallax)
            MountainLayer(
                peaks: [0.3, 0.5, 0.7],
                heights: [0.35, 0.45, 0.38],
                color: AppColors.navy.opacity(0.04)
            )
            .offset(y: 40)

            MountainLayer(
                peaks: [0.2, 0.45, 0.75],
                heights: [0.42, 0.55, 0.48],
                color: AppColors.navy.opacity(0.06)
            )
            .offset(y: 20)

            // Main mountain
            MountainShape()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.navy.opacity(0.12),
                            AppColors.navy.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Journey path
            ClimbingPath(progress: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.navy.opacity(0.2),
                            AppColors.navy.opacity(0.6),
                            AppColors.navy
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

            // Workout markers along path
            ForEach(0..<7, id: \.self) { index in
                let markerProgress = CGFloat(index + 1) / 8.0
                if markerProgress <= progress {
                    JourneyMarker(
                        position: pathPosition(at: markerProgress, in: geometry.size),
                        style: markerStyle(for: index),
                        delay: Double(index) * 0.1
                    )
                }
            }

            // Current position indicator
            if progress > 0 {
                Circle()
                    .fill(AppColors.navy)
                    .frame(width: 10, height: 10)
                    .shadow(color: AppColors.navy.opacity(0.5), radius: 8)
                    .position(pathPosition(at: progress, in: geometry.size))
            }

            // Summit flag (appears at end)
            if progress >= 0.95 {
                SummitFlag()
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    private func pathPosition(at t: CGFloat, in size: CGSize) -> CGPoint {
        let path = ClimbingPath.createPath(in: size)
        return path.point(at: t) ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func markerStyle(for index: Int) -> JourneyMarker.Style {
        let styles: [JourneyMarker.Style] = [.moderate, .strong, .recovery, .strong, .moderate, .recovery, .strong]
        return styles[index % styles.count]
    }
}

// MARK: - Mountain Layer

struct MountainLayer: View {
    let peaks: [CGFloat]
    let heights: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                path.move(to: CGPoint(x: 0, y: height))

                for i in 0..<peaks.count {
                    let peakX = width * peaks[i]
                    let peakY = height * (1 - heights[i])
                    let prevX = i == 0 ? 0 : width * peaks[i-1]

                    path.addLine(to: CGPoint(x: (prevX + peakX) / 2, y: height * 0.7))
                    path.addLine(to: CGPoint(x: peakX, y: peakY))
                }

                path.addLine(to: CGPoint(x: width, y: height * 0.6))
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Climbing Path

struct ClimbingPath: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let fullPath = ClimbingPath.createPath(in: rect.size)
        return fullPath.trimmedPath(from: 0, to: progress)
    }

    static func createPath(in size: CGSize) -> Path {
        var path = Path()

        let width = size.width
        let height = size.height

        // Start at bottom left
        let startPoint = CGPoint(x: width * 0.1, y: height * 0.85)
        path.move(to: startPoint)

        // Climb upward with switchbacks
        path.addQuadCurve(
            to: CGPoint(x: width * 0.25, y: height * 0.72),
            control: CGPoint(x: width * 0.18, y: height * 0.78)
        )

        path.addQuadCurve(
            to: CGPoint(x: width * 0.35, y: height * 0.60),
            control: CGPoint(x: width * 0.32, y: height * 0.68)
        )

        path.addQuadCurve(
            to: CGPoint(x: width * 0.28, y: height * 0.50),
            control: CGPoint(x: width * 0.30, y: height * 0.55)
        )

        path.addQuadCurve(
            to: CGPoint(x: width * 0.42, y: height * 0.38),
            control: CGPoint(x: width * 0.35, y: height * 0.44)
        )

        path.addQuadCurve(
            to: CGPoint(x: width * 0.50, y: height * 0.25),
            control: CGPoint(x: width * 0.48, y: height * 0.32)
        )

        path.addQuadCurve(
            to: CGPoint(x: width * 0.50, y: height * 0.12),
            control: CGPoint(x: width * 0.52, y: height * 0.18)
        )

        return path
    }
}

// MARK: - Journey Marker

struct JourneyMarker: View {
    let position: CGPoint
    let style: Style
    let delay: Double

    @State private var isVisible = false

    enum Style {
        case strong, moderate, recovery

        var color: Color {
            switch self {
            case .strong: return AppColors.navy
            case .moderate: return AppColors.olive
            case .recovery: return AppColors.coral
            }
        }

        var size: CGFloat {
            switch self {
            case .strong: return 14
            case .moderate: return 10
            case .recovery: return 12
            }
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(style.color.opacity(0.25))
                .frame(width: style.size + 10, height: style.size + 10)

            Circle()
                .fill(style.color)
                .frame(width: style.size, height: style.size)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.5), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: style.size / 2
                    )
                )
                .frame(width: style.size, height: style.size)
        }
        .position(position)
        .scaleEffect(isVisible ? 1 : 0.3)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(AppAnimation.springBouncy.delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Summit Flag

struct SummitFlag: View {
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Flag
            ZStack {
                Triangle()
                    .fill(AppColors.olive)
                    .frame(width: 24, height: 18)
                    .offset(x: 12)

                Triangle()
                    .fill(AppColors.olive.opacity(0.7))
                    .frame(width: 24, height: 18)
                    .offset(x: 12, y: 2)
            }

            // Pole
            Rectangle()
                .fill(AppColors.navy)
                .frame(width: 2, height: 20)
        }
        .scaleEffect(isVisible ? 1 : 0)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(AppAnimation.springBouncy.delay(0.3)) {
                isVisible = true
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Path Extension

extension Path {
    func point(at fraction: CGFloat) -> CGPoint? {
        let totalLength = self.length
        let targetLength = totalLength * fraction

        var currentLength: CGFloat = 0
        var previousPoint: CGPoint?

        self.forEach { element in
            switch element {
            case .move(to: let point):
                previousPoint = point
            case .line(to: let point):
                if let prev = previousPoint {
                    let segmentLength = hypot(point.x - prev.x, point.y - prev.y)
                    if currentLength + segmentLength >= targetLength {
                        let remainingFraction = (targetLength - currentLength) / segmentLength
                        let x = prev.x + (point.x - prev.x) * remainingFraction
                        let y = prev.y + (point.y - prev.y) * remainingFraction
                        previousPoint = CGPoint(x: x, y: y)
                        return
                    }
                    currentLength += segmentLength
                }
                previousPoint = point
            case .quadCurve(to: let point, control: let control):
                if let prev = previousPoint {
                    let steps = 20
                    for i in 1...steps {
                        let t = CGFloat(i) / CGFloat(steps)
                        let newPoint = quadraticPoint(from: prev, to: point, control: control, t: t)
                        let prevStep = i == 1 ? prev : quadraticPoint(from: prev, to: point, control: control, t: CGFloat(i-1) / CGFloat(steps))
                        let segmentLength = hypot(newPoint.x - prevStep.x, newPoint.y - prevStep.y)

                        if currentLength + segmentLength >= targetLength {
                            previousPoint = newPoint
                            return
                        }
                        currentLength += segmentLength
                    }
                }
                previousPoint = point
            case .curve(to: let point, control1: _, control2: _):
                previousPoint = point
            case .closeSubpath:
                break
            }
        }

        return previousPoint
    }

    private var length: CGFloat {
        var totalLength: CGFloat = 0
        var previousPoint: CGPoint?

        self.forEach { element in
            switch element {
            case .move(to: let point):
                previousPoint = point
            case .line(to: let point):
                if let prev = previousPoint {
                    totalLength += hypot(point.x - prev.x, point.y - prev.y)
                }
                previousPoint = point
            case .quadCurve(to: let point, control: let control):
                if let prev = previousPoint {
                    let steps = 20
                    for i in 1...steps {
                        let t = CGFloat(i) / CGFloat(steps)
                        let newPoint = quadraticPoint(from: prev, to: point, control: control, t: t)
                        let prevStep = i == 1 ? prev : quadraticPoint(from: prev, to: point, control: control, t: CGFloat(i-1) / CGFloat(steps))
                        totalLength += hypot(newPoint.x - prevStep.x, newPoint.y - prevStep.y)
                    }
                }
                previousPoint = point
            case .curve(to: let point, control1: _, control2: _):
                previousPoint = point
            case .closeSubpath:
                break
            }
        }

        return totalLength
    }

    private func quadraticPoint(from start: CGPoint, to end: CGPoint, control: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x
        let y = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    CinematicIntroView()
        .environmentObject(OnboardingState())
}
