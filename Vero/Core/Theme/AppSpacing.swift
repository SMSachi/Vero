//
//  AppSpacing.swift
//  Vero
//
//  Unified design system - spacing, sizing, and layout constants
//

import SwiftUI

struct AppSpacing {
    // MARK: - Base Unit

    static let unit: CGFloat = 4

    // MARK: - Spacing Scale

    /// 4pt - Minimal spacing
    static let xxxs: CGFloat = 4

    /// 6pt - Tiny spacing
    static let xxs: CGFloat = 6

    /// 8pt - Tight spacing
    static let xs: CGFloat = 8

    /// 12pt - Compact spacing
    static let sm: CGFloat = 12

    /// 16pt - Standard spacing
    static let md: CGFloat = 16

    /// 20pt - Comfortable spacing
    static let lg: CGFloat = 20

    /// 24pt - Section spacing
    static let xl: CGFloat = 24

    /// 32pt - Large section gaps
    static let xxl: CGFloat = 32

    /// 40pt - Major section breaks
    static let xxxl: CGFloat = 40

    /// 48pt - Hero spacing
    static let huge: CGFloat = 48

    /// 64pt - Extra hero spacing
    static let massive: CGFloat = 64

    // MARK: - Semantic Spacing

    static let screenHorizontal: CGFloat = 20
    static let screenVertical: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let cardPaddingCompact: CGFloat = 16
    static let cardPaddingLarge: CGFloat = 24
    static let cardGap: CGFloat = 16
    static let sectionGap: CGFloat = 28
    static let headerToContent: CGFloat = 16
    static let iconToLabel: CGFloat = 10
    static let textLineGap: CGFloat = 4

    // MARK: - Unified Layout System

    /// Standard layout spacing values used across all screens
    enum Layout {
        /// Top safe area padding (24pt)
        static let topPadding: CGFloat = 24

        /// Spacing under title/header (12pt)
        static let titleSpacing: CGFloat = 12

        /// Spacing between major sections (24pt)
        static let sectionSpacing: CGFloat = 24

        /// Spacing between cards (16pt)
        static let cardSpacing: CGFloat = 16

        /// Bottom button margin (32pt)
        static let bottomMargin: CGFloat = 32

        /// Standard card corner radius (16pt)
        static let cardRadius: CGFloat = 16

        /// Standard card internal padding (16pt)
        static let cardPadding: CGFloat = 16

        /// Screen horizontal margins (20pt)
        static let horizontalMargin: CGFloat = 20

        /// Bottom scroll padding for tab bar (100pt)
        static let bottomScrollPadding: CGFloat = 100
    }

    // MARK: - Unified Icon Sizes

    /// Consistent icon sizing across the app
    enum Icon {
        /// Small icons in chips/labels (12pt)
        static let small: CGFloat = 12

        /// Medium icons in cards (16pt)
        static let medium: CGFloat = 16

        /// Large icons in hero areas (20pt)
        static let large: CGFloat = 20

        /// Extra large icons (24pt)
        static let xlarge: CGFloat = 24

        /// Icon circle - small (36pt)
        static let circleSmall: CGFloat = 36

        /// Icon circle - medium (44pt)
        static let circleMedium: CGFloat = 44

        /// Icon circle - large (52pt)
        static let circleLarge: CGFloat = 52
    }

    // MARK: - Corner Radii

    static let radiusTiny: CGFloat = 6
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXLarge: CGFloat = 20
    static let radiusHero: CGFloat = 24
    static let radiusFull: CGFloat = 100
}

// MARK: - Animation Presets

struct AppAnimation {
    // Spring animations for playful feel
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.65)
    static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springSnappy = Animation.spring(response: 0.25, dampingFraction: 0.75)

    // Smooth easing
    static let smooth = Animation.easeInOut(duration: 0.35)
    static let smoothSlow = Animation.easeInOut(duration: 0.5)
    static let smoothFast = Animation.easeInOut(duration: 0.2)

    // Entrance animations
    static let entrance = Animation.spring(response: 0.6, dampingFraction: 0.75)
    static let entranceDelayed = Animation.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)
    static let staggerBase: Double = 0.08

    // Exit animations
    static let exit = Animation.easeOut(duration: 0.25)
}

// MARK: - Padding Modifiers

extension View {
    func screenPadding() -> some View {
        self.padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.screenVertical)
    }

    func horizontalPadding() -> some View {
        self.padding(.horizontal, AppSpacing.screenHorizontal)
    }

    func cardPadding() -> some View {
        self.padding(AppSpacing.cardPadding)
    }

    func cardPaddingCompact() -> some View {
        self.padding(AppSpacing.cardPaddingCompact)
    }

    func cardPaddingLarge() -> some View {
        self.padding(AppSpacing.cardPaddingLarge)
    }
}

// MARK: - Animation Modifiers

extension View {
    /// Animate appearance with spring
    func appearAnimation(delay: Double = 0) -> some View {
        self.animation(AppAnimation.entrance.delay(delay), value: true)
    }

    /// Staggered entrance for lists
    func staggeredEntrance(index: Int, baseDelay: Double = 0.1) -> some View {
        self.animation(
            AppAnimation.entrance.delay(baseDelay + Double(index) * AppAnimation.staggerBase),
            value: true
        )
    }
}

// MARK: - Interactive Modifiers

extension View {
    /// Subtle press effect for cards
    func pressable(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.springSnappy, value: isPressed)
    }

    /// Bounce effect on tap
    func bounceOnTap() -> some View {
        self.buttonStyle(BounceButtonStyle())
    }
}

// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.springBouncy, value: configuration.isPressed)
    }
}

// MARK: - Organic Shapes

struct BlobShape: Shape {
    var complexity: CGFloat = 0.3

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2

        var path = Path()

        let points = 8
        var firstPoint: CGPoint?

        for i in 0..<points {
            let angle = (Double(i) / Double(points)) * 2 * .pi
            let variation = 1.0 + complexity * sin(Double(i) * 2.5)
            let r = radius * variation

            let x = centerX + CGFloat(cos(angle)) * r
            let y = centerY + CGFloat(sin(angle)) * r

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
                firstPoint = CGPoint(x: x, y: y)
            } else {
                let prevAngle = (Double(i - 1) / Double(points)) * 2 * .pi
                let midAngle = (prevAngle + angle) / 2
                let controlR = radius * (1.0 + complexity * 0.5)

                let controlX = centerX + CGFloat(cos(midAngle)) * controlR
                let controlY = centerY + CGFloat(sin(midAngle)) * controlR

                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: controlX, y: controlY)
                )
            }
        }

        if let first = firstPoint {
            let lastAngle = (Double(points - 1) / Double(points)) * 2 * .pi
            let midAngle = (lastAngle + 2 * .pi) / 2
            let controlR = radius * (1.0 + complexity * 0.5)

            path.addQuadCurve(
                to: first,
                control: CGPoint(
                    x: centerX + CGFloat(cos(midAngle)) * controlR,
                    y: centerY + CGFloat(sin(midAngle)) * controlR
                )
            )
        }

        return path
    }
}

// MARK: - Soft Rounded Rectangle

struct SoftRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    var smoothness: CGFloat = 0.6

    func path(in rect: CGRect) -> Path {
        // Creates a superellipse-like shape (squircle) for Apple-style corners
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        return path
    }
}

// MARK: - Convenience

extension CGFloat {
    static let spacing = AppSpacing.self
}
