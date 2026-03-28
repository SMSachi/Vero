//
//  AppColors.swift
//  Insio Health
//
//  STRICT COLOR SYSTEM:
//  - NAVY = primary (headers, selected states, nav bar)
//  - OLIVE = secondary (cards, subtle highlights)
//  - BURNT ORANGE = accent (buttons, CTAs, progress, selected)
//  - OFF-WHITE = background
//

import SwiftUI

struct AppColors {
    // MARK: - Core Brand Colors (STRICT SYSTEM)

    /// NAVY - Primary: headers, selected states, nav bar
    static let navy = Color(red: 0.11, green: 0.16, blue: 0.25)

    /// OLIVE - Secondary: cards, subtle highlights
    static let olive = Color(red: 0.42, green: 0.50, blue: 0.38)

    /// BURNT ORANGE - Accent: buttons, CTAs, progress indicators
    static let burntOrange = Color(red: 0.80, green: 0.40, blue: 0.20)

    /// OFF-WHITE - Background
    static let offWhite = Color(red: 0.975, green: 0.965, blue: 0.945)

    // MARK: - Convenience Aliases

    /// Primary accent for CTAs and buttons
    static let accent = burntOrange

    /// Legacy orange alias (use burntOrange for new code)
    static let orange = burntOrange

    /// Soft coral - warmth, friendliness (secondary accent)
    static let coral = Color(red: 0.95, green: 0.62, blue: 0.52)

    // MARK: - Backgrounds

    /// Main background - off-white (NOT pure white)
    static let background = offWhite

    /// Card background - clean white for contrast against off-white
    static let cardBackground = Color.white

    /// Hero card background - subtle warm tint
    static let heroBackground = Color(red: 0.98, green: 0.97, blue: 0.96)

    /// Elevated surface - for modals and overlays
    static let elevatedSurface = Color(red: 0.99, green: 0.99, blue: 0.98)

    /// Subtle divider color
    static let divider = Color(red: 0.92, green: 0.90, blue: 0.87)

    // MARK: - Tinted Backgrounds (for cards with personality)

    static let navyTint = navy.opacity(0.06)
    static let oliveTint = olive.opacity(0.08)
    static let accentTint = burntOrange.opacity(0.08)
    static let orangeTint = accentTint  // Legacy alias
    static let warmTint = Color(red: 0.98, green: 0.95, blue: 0.92)

    // MARK: - Section Colors (for Daily Context UI)

    /// Water section - blue/teal derived from navy
    static let waterTint = Color(red: 0.20, green: 0.45, blue: 0.65).opacity(0.12)
    static let waterAccent = Color(red: 0.20, green: 0.45, blue: 0.65)

    /// Nutrition section - olive tinted
    static let nutritionTint = oliveTint
    static let nutritionAccent = olive

    // MARK: - Text Colors

    /// Primary text - deep navy for readability
    static let textPrimary = Color(red: 0.11, green: 0.14, blue: 0.20)

    /// Secondary text - softer for supporting content
    static let textSecondary = Color(red: 0.42, green: 0.44, blue: 0.48)

    /// Tertiary text - subtle labels and metadata
    static let textTertiary = Color(red: 0.60, green: 0.62, blue: 0.65)

    /// Inverted text for dark backgrounds
    static let textInverted = Color.white

    /// Warm text - for friendly messages
    static let textWarm = Color(red: 0.52, green: 0.42, blue: 0.35)

    // MARK: - Semantic Colors

    static let success = olive
    static let warning = Color(red: 0.90, green: 0.70, blue: 0.30)
    static let error = Color(red: 0.85, green: 0.38, blue: 0.35)
    static let info = Color(red: 0.40, green: 0.58, blue: 0.78)

    // MARK: - Recovery Spectrum

    static let recoveryExcellent = Color(red: 0.38, green: 0.58, blue: 0.45)
    static let recoveryGood = Color(red: 0.52, green: 0.65, blue: 0.50)
    static let recoveryModerate = Color(red: 0.80, green: 0.70, blue: 0.45)
    static let recoveryLow = Color(red: 0.85, green: 0.52, blue: 0.42)

    // MARK: - Intensity Spectrum

    static let intensityLow = Color(red: 0.60, green: 0.70, blue: 0.58)
    static let intensityModerate = Color(red: 0.78, green: 0.72, blue: 0.50)
    static let intensityHigh = Color(red: 0.90, green: 0.58, blue: 0.38)
    static let intensityMax = Color(red: 0.88, green: 0.42, blue: 0.35)

    // MARK: - Interactive States (STRICT SYSTEM)

    /// Primary button = BURNT ORANGE filled
    static let buttonPrimaryBackground = burntOrange
    static let buttonPrimaryForeground = Color.white

    /// Secondary button = NAVY outline
    static let buttonSecondaryBackground = Color.white
    static let buttonSecondaryForeground = navy
    static let buttonSecondaryBorder = navy

    /// Selected states = BURNT ORANGE or NAVY (never gray)
    static let selectedBackground = burntOrange.opacity(0.12)
    static let selectedBorder = burntOrange

    // MARK: - Gradient Presets

    /// Hero header gradient: NAVY → subtle OLIVE
    static let heroGradient = LinearGradient(
        colors: [navy, Color(red: 0.18, green: 0.24, blue: 0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Header gradient: NAVY → OLIVE (for top sections)
    static let headerGradient = LinearGradient(
        colors: [navy, olive.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [offWhite, Color(red: 0.96, green: 0.94, blue: 0.91)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let oliveGradient = LinearGradient(
        colors: [olive, Color(red: 0.48, green: 0.55, blue: 0.42)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent gradient for CTAs
    static let accentGradient = LinearGradient(
        colors: [burntOrange, Color(red: 0.85, green: 0.45, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Shadows

    static let shadowColor = Color.black.opacity(0.05)
    static let shadowColorMedium = Color.black.opacity(0.08)
    static let shadowColorWarm = Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.08)
}

// MARK: - View Modifiers for Shadows

extension View {
    /// Standard card shadow - used consistently across all cards
    func standardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    /// Soft card shadow with warmth
    func cardShadow() -> some View {
        self
            .shadow(color: AppColors.shadowColorWarm, radius: 16, x: 0, y: 6)
            .shadow(color: AppColors.shadowColor, radius: 4, x: 0, y: 2)
    }

    /// Hero card shadow - more prominent
    func heroShadow() -> some View {
        self
            .shadow(color: AppColors.shadowColorMedium, radius: 24, x: 0, y: 10)
            .shadow(color: AppColors.shadowColorWarm, radius: 8, x: 0, y: 4)
    }

    /// Subtle shadow for floating elements
    func softShadow() -> some View {
        self.shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 3)
    }
}

// MARK: - Unified Card Modifier

extension View {
    /// Standard card styling with consistent corner radius, background, and shadow
    func standardCard() -> some View {
        self
            .padding(AppSpacing.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .standardShadow()
    }

    /// Standard card with horizontal margin
    func standardCardWithMargin() -> some View {
        self
            .standardCard()
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Color Convenience

extension Color {
    static let vero = AppColors.self
}
