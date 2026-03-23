//
//  VeroScreenLayout.swift
//  Insio Health
//
//  Unified layout system for all screens
//  Structure: Header → Content → Footer (optional)
//

import SwiftUI

// MARK: - Screen Layout

/// Reusable screen layout wrapper that enforces consistent structure
/// Usage:
/// ```
/// VeroScreenLayout(
///     title: "Goals",
///     subtitle: "Select all that apply"
/// ) {
///     // Content goes here (cards, lists, etc.)
/// } footer: {
///     PrimaryButton("Continue") { }
/// }
/// ```
struct VeroScreenLayout<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let showBackButton: Bool
    let backAction: (() -> Void)?
    let content: Content
    let footer: Footer

    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var footerVisible = false

    init(
        title: String,
        subtitle: String? = nil,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ═══════════════════════════════════════════
            // HEADER SECTION
            // ═══════════════════════════════════════════

            VStack(alignment: .leading, spacing: 0) {
                // Back button (if shown)
                if showBackButton {
                    Button {
                        backAction?()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, -AppSpacing.sm)
                }

                Spacer().frame(height: showBackButton ? AppSpacing.xs : AppSpacing.Layout.topPadding)

                // Title
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                // Subtitle
                if let subtitle = subtitle {
                    Spacer().frame(height: AppSpacing.Layout.titleSpacing)
                    Text(subtitle)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 15)

            Spacer().frame(height: AppSpacing.Layout.sectionSpacing)

            // ═══════════════════════════════════════════
            // CONTENT SECTION (scrollable)
            // ═══════════════════════════════════════════

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.Layout.cardSpacing) {
                    content
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)

                // Bottom padding for scroll content
                Spacer().frame(height: AppSpacing.Layout.sectionSpacing)
            }
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 15)

            // ═══════════════════════════════════════════
            // FOOTER SECTION (fixed at bottom)
            // ═══════════════════════════════════════════

            VStack(spacing: AppSpacing.md) {
                footer
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
            .padding(.bottom, AppSpacing.Layout.bottomMargin)
            .opacity(footerVisible ? 1 : 0)
            .offset(y: footerVisible ? 0 : 15)
        }
        .background(AppColors.background)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            contentVisible = true
        }
        withAnimation(AppAnimation.entrance.delay(0.35)) {
            footerVisible = true
        }
    }
}

// MARK: - Without Footer

extension VeroScreenLayout where Footer == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.content = content()
        self.footer = EmptyView()
    }
}

// MARK: - Scrolling Content Layout (for main tabs)

/// Layout for main tab screens where content scrolls under a fixed header
struct VeroScrollLayout<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailing: AnyView?
    let content: Content

    @State private var headerVisible = false
    @State private var contentVisible = false

    init(
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ═══════════════════════════════════════════
                // HEADER
                // ═══════════════════════════════════════════

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppSpacing.Layout.titleSpacing) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    if let trailing = trailing {
                        trailing
                    }
                }
                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                .padding(.top, AppSpacing.Layout.topPadding)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 15)

                Spacer().frame(height: AppSpacing.Layout.sectionSpacing)

                // ═══════════════════════════════════════════
                // CONTENT
                // ═══════════════════════════════════════════

                VStack(spacing: AppSpacing.Layout.sectionSpacing) {
                    content
                }
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 15)

                // Bottom spacing for tab bar
                Spacer().frame(height: 120)
            }
        }
        .background(AppColors.background)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(AppAnimation.entrance.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(AppAnimation.springGentle.delay(0.2)) {
            contentVisible = true
        }
    }
}

// MARK: - Preview

#Preview("Screen Layout") {
    VeroScreenLayout(
        title: "What are your goals?",
        subtitle: "Select all that apply",
        showBackButton: true,
        backAction: {}
    ) {
        ForEach(0..<4, id: \.self) { index in
            VeroCard {
                HStack {
                    Text("Goal \(index + 1)")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
            }
        }
    } footer: {
        PrimaryButton("Continue") {}
    }
}

#Preview("Scroll Layout") {
    VeroScrollLayout(
        title: "Trends",
        subtitle: "Your patterns this month"
    ) {
        ForEach(0..<5, id: \.self) { index in
            VeroCard {
                Text("Section \(index + 1)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        }
    }
}
