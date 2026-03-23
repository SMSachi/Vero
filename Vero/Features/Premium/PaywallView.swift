//
//  PaywallView.swift
//  Insio Health
//
//  Premium subscription paywall with tier comparison.
//  Shows Plus ($4.99/mo) and Pro ($12.99/mo) options.
//

import SwiftUI
import StoreKit

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitService.shared
    @StateObject private var premiumManager = PremiumManager.shared

    @State private var selectedTier: SubscriptionTier = .pro
    @State private var selectedBillingPeriod: BillingPeriod = .yearly
    @State private var isAnimating = false
    @State private var showRestoreSuccess = false

    enum BillingPeriod {
        case monthly, yearly
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    // Hero section
                    PaywallHero()
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)

                    // Show unavailable state if products can't be loaded
                    if storeKit.productsUnavailable {
                        ProductsUnavailableView(reason: storeKit.productsUnavailableReason)
                            .opacity(isAnimating ? 1 : 0)
                    } else {
                        // Tier comparison
                        TierComparisonView(selectedTier: $selectedTier)
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)

                        // Billing period toggle
                        BillingPeriodToggle(selectedPeriod: $selectedBillingPeriod)
                            .opacity(isAnimating ? 1 : 0)

                        // Selected tier pricing
                        SelectedTierPricing(
                            tier: selectedTier,
                            period: selectedBillingPeriod,
                            storeKit: storeKit
                        )
                        .opacity(isAnimating ? 1 : 0)

                        // Error message
                        if let error = storeKit.errorMessage {
                            Text(error)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
                        }

                        // Subscribe button
                        SubscribeButton(
                            tier: selectedTier,
                            period: selectedBillingPeriod,
                            storeKit: storeKit,
                            onSubscribe: subscribe
                        )
                        .opacity(isAnimating ? 1 : 0)

                        // Restore purchases
                        Button {
                            Task {
                                await storeKit.restorePurchases()
                                if premiumManager.isPaid {
                                    showRestoreSuccess = true
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .disabled(storeKit.isLoading)
                        .opacity(isAnimating ? 1 : 0)
                    }

                    // Legal text
                    LegalText()
                        .opacity(isAnimating ? 1 : 0)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.Layout.bottomScrollPadding)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(AppAnimation.entrance.delay(0.1)) {
                isAnimating = true
            }
        }
        .alert("Restored!", isPresented: $showRestoreSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your \(premiumManager.currentTier.displayName) subscription has been restored.")
        }
    }

    private func subscribe() {
        let product: Product?

        switch (selectedTier, selectedBillingPeriod) {
        case (.plus, .monthly):
            product = storeKit.plusMonthlyProduct
        case (.plus, .yearly):
            product = storeKit.plusYearlyProduct
        case (.pro, .monthly):
            product = storeKit.proMonthlyProduct
        case (.pro, .yearly):
            product = storeKit.proYearlyProduct
        default:
            product = nil
        }

        guard let selectedProduct = product else { return }

        Task {
            let success = await storeKit.purchase(selectedProduct)
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Paywall Hero

private struct PaywallHero: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Premium badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.navy, AppColors.navy.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("Unlock Insio Premium")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Choose the plan that fits your goals")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Tier Comparison View

private struct TierComparisonView: View {
    @Binding var selectedTier: SubscriptionTier

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Plus tier card
            TierCard(
                tier: .plus,
                isSelected: selectedTier == .plus,
                onSelect: { selectedTier = .plus }
            )

            // Pro tier card (recommended)
            TierCard(
                tier: .pro,
                isSelected: selectedTier == .pro,
                isRecommended: true,
                onSelect: { selectedTier = .pro }
            )
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

private struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    var isRecommended: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(tier.displayName)
                                .font(AppTypography.headlineMedium)
                                .foregroundStyle(AppColors.textPrimary)

                            if isRecommended {
                                Text("Best Value")
                                    .font(AppTypography.labelSmall)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.olive)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(tier.shortDescription)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppColors.navy : AppColors.divider, lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(AppColors.navy)
                                .frame(width: 16, height: 16)
                        }
                    }
                }

                // Features list
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(featuresForTier(tier), id: \.self) { feature in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppColors.olive)

                            Text(feature)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
            }
            .padding(AppSpacing.Layout.cardPadding)
            .background(isSelected ? AppColors.navyTint : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.Layout.cardRadius, style: .continuous)
                    .stroke(isSelected ? AppColors.navy : AppColors.divider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func featuresForTier(_ tier: SubscriptionTier) -> [String] {
        switch tier {
        case .plus:
            return [
                "Weekly AI trend summaries",
                "Nutrition-aware insights",
                "30-day history access",
                "Deeper trend analysis"
            ]
        case .pro:
            return [
                "AI summary after every workout",
                "Weekly & monthly AI reports",
                "Unlimited history access",
                "Advanced pattern analysis",
                "Smart recommendations"
            ]
        case .free:
            return []
        }
    }
}

// MARK: - Billing Period Toggle

private struct BillingPeriodToggle: View {
    @Binding var selectedPeriod: PaywallView.BillingPeriod

    var body: some View {
        HStack(spacing: 0) {
            PeriodButton(
                title: "Monthly",
                isSelected: selectedPeriod == .monthly,
                onTap: { selectedPeriod = .monthly }
            )

            PeriodButton(
                title: "Yearly",
                subtitle: "Save ~17%",
                isSelected: selectedPeriod == .yearly,
                onTap: { selectedPeriod = .yearly }
            )
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .stroke(AppColors.divider, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

private struct PeriodButton: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(title)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(isSelected ? .white : AppColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : AppColors.olive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.navy : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selected Tier Pricing

private struct SelectedTierPricing: View {
    let tier: SubscriptionTier
    let period: PaywallView.BillingPeriod
    @ObservedObject var storeKit: StoreKitService

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            if let product = selectedProduct {
                // Show actual StoreKit price
                HStack(alignment: .lastTextBaseline, spacing: AppSpacing.xs) {
                    Text(product.displayPrice)
                        .font(AppTypography.displayLarge)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("/ \(product.subscriptionPeriodText)")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if period == .yearly, let perMonth = storeKit.yearlyPricePerMonth(for: tier) {
                    Text("(\(perMonth)/month)")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textTertiary)
                }

                if product.hasFreeTrial {
                    Text("\(product.freeTrialDays ?? InsioConfig.StoreKit.freeTrialDays)-day free trial")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(AppColors.orange)
                        .padding(.top, AppSpacing.xs)
                }
            } else if storeKit.isLoading {
                // Loading state
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading prices...")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else {
                // Fallback display prices when StoreKit products not available
                HStack(alignment: .lastTextBaseline, spacing: AppSpacing.xs) {
                    Text(fallbackPrice)
                        .font(AppTypography.displayLarge)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("/ \(period == .yearly ? "year" : "month")")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // Show 3-day free trial message
                Text("\(InsioConfig.StoreKit.freeTrialDays)-day free trial")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(AppColors.orange)
                    .padding(.top, AppSpacing.xs)

                // Debug hint for developers
                #if DEBUG
                Text("StoreKit products not configured")
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.top, AppSpacing.xs)
                #endif
            }
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }

    private var selectedProduct: Product? {
        switch (tier, period) {
        case (.plus, .monthly): return storeKit.plusMonthlyProduct
        case (.plus, .yearly): return storeKit.plusYearlyProduct
        case (.pro, .monthly): return storeKit.proMonthlyProduct
        case (.pro, .yearly): return storeKit.proYearlyProduct
        default: return nil
        }
    }

    /// Fallback prices when StoreKit is not configured
    private var fallbackPrice: String {
        switch (tier, period) {
        case (.plus, .monthly): return "$4.99"
        case (.plus, .yearly): return "$49.99"
        case (.pro, .monthly): return "$12.99"
        case (.pro, .yearly): return "$99.99"
        default: return "$0.00"
        }
    }
}

// MARK: - Subscribe Button

private struct SubscribeButton: View {
    let tier: SubscriptionTier
    let period: PaywallView.BillingPeriod
    @ObservedObject var storeKit: StoreKitService
    let onSubscribe: () -> Void

    private var buttonText: String {
        if storeKit.isPurchasing {
            return "Processing..."
        }

        if let product = selectedProduct, product.hasFreeTrial {
            return "Start Free Trial"
        }

        return "Subscribe to \(tier.displayName)"
    }

    private var selectedProduct: Product? {
        switch (tier, period) {
        case (.plus, .monthly): return storeKit.plusMonthlyProduct
        case (.plus, .yearly): return storeKit.plusYearlyProduct
        case (.pro, .monthly): return storeKit.proMonthlyProduct
        case (.pro, .yearly): return storeKit.proYearlyProduct
        default: return nil
        }
    }

    var body: some View {
        Button(action: onSubscribe) {
            HStack(spacing: AppSpacing.sm) {
                if storeKit.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }

                Text(buttonText)
                    .font(AppTypography.buttonLarge)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.navy)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        }
        .disabled(selectedProduct == nil || storeKit.isPurchasing)
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
    }
}

// MARK: - Legal Text

private struct LegalText: View {
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period.")
                .font(AppTypography.captionSmall)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.md) {
                Link("Terms of Service", destination: InsioConfig.Legal.termsOfServiceURL)
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.navy)

                Link("Privacy Policy", destination: InsioConfig.Legal.privacyPolicyURL)
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.navy)
            }
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        .padding(.top, AppSpacing.sm)
    }
}

// MARK: - Products Unavailable View

/// Shown when StoreKit products cannot be loaded (simulator, no account, etc.)
private struct ProductsUnavailableView: View {
    let reason: StoreKitService.ProductsUnavailableReason

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(iconBackgroundColor)
            }

            // Title and message
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Developer note (debug builds only)
            #if DEBUG
            VStack(spacing: AppSpacing.xs) {
                Text("Developer Note")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(AppColors.navy)

                Text(developerNote)
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.md)
            .background(AppColors.navy.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall))
            #endif
        }
        .padding(.horizontal, AppSpacing.Layout.horizontalMargin)
        .padding(.vertical, AppSpacing.xl)
    }

    private var icon: String {
        switch reason {
        case .simulator:
            return "desktopcomputer"
        case .noActiveAccount:
            return "person.crop.circle.badge.questionmark"
        case .networkError:
            return "wifi.slash"
        case .configurationError:
            return "gearshape.circle"
        case .none:
            return "questionmark.circle"
        }
    }

    private var iconBackgroundColor: Color {
        switch reason {
        case .simulator:
            return AppColors.navy
        case .noActiveAccount:
            return AppColors.orange
        case .networkError:
            return AppColors.coral
        case .configurationError:
            return AppColors.textTertiary
        case .none:
            return AppColors.textTertiary
        }
    }

    private var title: String {
        switch reason {
        case .simulator:
            return "Simulator Mode"
        case .noActiveAccount:
            return "App Store Unavailable"
        case .networkError:
            return "Connection Error"
        case .configurationError:
            return "Configuration Error"
        case .none:
            return "Products Unavailable"
        }
    }

    private var message: String {
        switch reason {
        case .simulator:
            return "In-app purchases are not available in the iOS Simulator. Test on a real device or use StoreKit Testing."
        case .noActiveAccount:
            return "Please sign in to the App Store to view subscription options."
        case .networkError:
            return "Unable to connect to the App Store. Please check your internet connection and try again."
        case .configurationError:
            return "Subscription products are not configured. Please try again later."
        case .none:
            return "Subscription options are currently unavailable."
        }
    }

    private var developerNote: String {
        switch reason {
        case .simulator:
            return "To test purchases: Use a real device with Sandbox account, or configure a StoreKit Configuration file in Xcode."
        case .noActiveAccount:
            return "User is not signed into App Store. On real device, prompt user to sign in via Settings."
        case .networkError:
            return "Network request to App Store failed. Check connectivity and retry."
        case .configurationError:
            return "Product IDs may not be configured in App Store Connect, or StoreKit Configuration is missing."
        case .none:
            return "Unknown error loading products."
        }
    }
}

// MARK: - Premium Badge (for use elsewhere)

struct PremiumBadge: View {
    var tier: SubscriptionTier = .pro
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier == .pro ? "sparkles" : "star.fill")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))

            if !compact {
                Text(tier.displayName)
                    .font(AppTypography.labelSmall)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            LinearGradient(
                colors: tier == .pro
                    ? [AppColors.navy, AppColors.navy.opacity(0.85)]
                    : [AppColors.olive, AppColors.olive.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Tier Badge (for displaying current tier)

struct TierBadge: View {
    let tier: SubscriptionTier

    var body: some View {
        Text(tier.displayName)
            .font(AppTypography.labelSmall)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch tier {
        case .free: return AppColors.textSecondary
        case .plus: return .white
        case .pro: return .white
        }
    }

    private var backgroundColor: Color {
        switch tier {
        case .free: return AppColors.divider
        case .plus: return AppColors.olive
        case .pro: return AppColors.navy
        }
    }
}

// MARK: - Premium Gate View

/// Overlay view shown when premium feature is accessed by lower-tier user
struct PremiumGateView: View {
    let feature: PremiumFeature
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.navy.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppColors.navy)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("\(feature.requiredTier.displayName) Feature")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(AppColors.textPrimary)

                Text(feature.description)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to \(feature.requiredTier.displayName)")
                    .font(AppTypography.buttonMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            }
        }
        .padding(AppSpacing.xl)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
}

#Preview("Premium Badge") {
    VStack(spacing: 20) {
        PremiumBadge(tier: .pro)
        PremiumBadge(tier: .plus)
        PremiumBadge(tier: .pro, compact: true)
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Tier Badge") {
    VStack(spacing: 10) {
        TierBadge(tier: .free)
        TierBadge(tier: .plus)
        TierBadge(tier: .pro)
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Premium Gate") {
    PremiumGateView(feature: .aiWorkoutSummaries)
        .padding()
        .background(AppColors.background)
}
