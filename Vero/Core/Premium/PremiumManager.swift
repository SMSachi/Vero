//
//  PremiumManager.swift
//  Insio Health
//
//  Manages premium subscription state and feature access.
//  Supports 3-tier system: Free, Plus, Pro.
//
//  TIERS:
//  - FREE: 3-day trial, then workout logging only
//  - PLUS ($4.99/mo): Weekly AI trends, 30-day history
//  - PRO ($12.99/mo): Full per-workout AI, unlimited history
//
//  USAGE:
//  - Check `PremiumManager.shared.currentTier` for tier
//  - Use `PremiumManager.shared.canAccess(.feature)` for feature gating
//

import Foundation
import Combine

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable, Comparable {
    case free = "free"
    case plus = "plus"
    case pro = "pro"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }

    var shortDescription: String {
        switch self {
        case .free: return "Basic features"
        case .plus: return "Weekly AI insights"
        case .pro: return "Full AI experience"
        }
    }

    // Comparable conformance for tier comparison
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.free, .plus, .pro]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Premium Manager

@MainActor
final class PremiumManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PremiumManager()

    // MARK: - Published State

    /// Current subscription tier
    @Published private(set) var currentTier: SubscriptionTier = .free

    /// Whether premium status is currently being verified
    @Published private(set) var isVerifying: Bool = false

    /// The current subscription product ID (if subscribed)
    @Published private(set) var activeProductID: String?

    /// Subscription expiration date (if available)
    @Published private(set) var expirationDate: Date?

    /// Whether user is in free trial period
    @Published private(set) var isInTrial: Bool = false

    /// Days remaining in trial (if applicable)
    @Published private(set) var trialDaysRemaining: Int?

    // MARK: - Convenience Properties

    /// Whether user has any paid subscription
    var isPaid: Bool { currentTier != .free }

    /// Whether user is Plus or higher
    var isPlus: Bool { currentTier >= .plus }

    /// Whether user is Pro
    var isPro: Bool { currentTier == .pro }

    /// Legacy compatibility - true if any paid tier
    var isPremium: Bool { isPaid }

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let tierKey = "insio_subscription_tier"
    private let expirationDateKey = "insio_premium_expiration"
    private let productIDKey = "insio_premium_product_id"
    private let trialStatusKey = "insio_trial_status"
    private let trialStartDateKey = "insio_trial_start_date"

    // MARK: - Initialization

    private init() {
        loadCachedStatus()
    }

    // MARK: - Feature Access

    /// Check if a specific feature is accessible at current tier
    func canAccess(_ feature: PremiumFeature) -> Bool {
        // If premium enforcement is disabled (dev mode), allow all
        if !InsioConfig.Features.premiumEnforced {
            return true
        }

        // During trial, allow Plus-level features
        if isInTrial && currentTier == .free {
            return feature.requiredTier <= .plus
        }

        // Check if feature's required tier is met
        return currentTier >= feature.requiredTier
    }

    /// Check if user can access AI features (tier + configuration)
    func canAccessAI() -> Bool {
        guard InsioConfig.OpenRouter.isConfigured else { return false }

        // Trial users get Plus-level AI access
        if isInTrial { return true }

        switch currentTier {
        case .free:
            return false
        case .plus, .pro:
            return true
        }
    }

    /// Check if user can access per-workout AI summaries (Pro only)
    func canAccessWorkoutAI() -> Bool {
        guard InsioConfig.OpenRouter.isConfigured else { return false }
        return currentTier == .pro
    }

    /// Check if user can access weekly AI trends (Plus or Pro, or during trial)
    func canAccessWeeklyAI() -> Bool {
        guard InsioConfig.OpenRouter.isConfigured else { return false }
        if isInTrial { return true }
        return currentTier >= .plus
    }

    // MARK: - Tier Limits

    /// Maximum history days for current tier
    var maxHistoryDays: Int? {
        // Trial users get Plus-level access
        if isInTrial { return InsioConfig.TierLimits.plusHistoryDays }

        switch currentTier {
        case .free: return InsioConfig.TierLimits.freeHistoryDays
        case .plus: return InsioConfig.TierLimits.plusHistoryDays
        case .pro: return InsioConfig.TierLimits.proHistoryDays // nil = unlimited
        }
    }

    /// Maximum workouts visible for current tier
    var maxWorkoutsVisible: Int? {
        // Trial users get Plus-level access
        if isInTrial { return InsioConfig.TierLimits.plusMaxWorkoutsVisible }

        switch currentTier {
        case .free: return InsioConfig.TierLimits.freeMaxWorkoutsVisible
        case .plus: return InsioConfig.TierLimits.plusMaxWorkoutsVisible
        case .pro: return InsioConfig.TierLimits.proMaxWorkoutsVisible // nil = unlimited
        }
    }

    /// Trend analysis days for current tier
    var trendDays: Int? {
        // Trial users get Plus-level access
        if isInTrial { return InsioConfig.TierLimits.plusTrendDays }

        switch currentTier {
        case .free: return InsioConfig.TierLimits.freeTrendDays
        case .plus: return InsioConfig.TierLimits.plusTrendDays
        case .pro: return InsioConfig.TierLimits.proTrendDays // nil = unlimited
        }
    }

    // MARK: - Status Management

    /// Update subscription status after purchase verification
    func updateSubscriptionStatus(
        tier: SubscriptionTier,
        productID: String? = nil,
        expirationDate: Date? = nil,
        isInTrial: Bool = false
    ) {
        self.currentTier = tier
        self.activeProductID = productID
        self.expirationDate = expirationDate
        self.isInTrial = isInTrial

        // Calculate trial days remaining
        if isInTrial, let expiration = expirationDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
            self.trialDaysRemaining = max(0, days)
        } else {
            self.trialDaysRemaining = nil
        }

        // Cache status
        cacheStatus()

        print("💎 PremiumManager: Status updated")
        print("💎 PremiumManager: tier = \(tier.rawValue)")
        print("💎 PremiumManager: productID = \(productID ?? "none")")
        print("💎 PremiumManager: isInTrial = \(isInTrial)")
        print("💎 PremiumManager: expirationDate = \(expirationDate?.description ?? "none")")
    }

    /// Clear premium status (e.g., on sign out)
    func clearPremiumStatus() {
        currentTier = .free
        activeProductID = nil
        expirationDate = nil
        isInTrial = false
        trialDaysRemaining = nil

        userDefaults.removeObject(forKey: tierKey)
        userDefaults.removeObject(forKey: expirationDateKey)
        userDefaults.removeObject(forKey: productIDKey)
        userDefaults.removeObject(forKey: trialStatusKey)

        print("💎 PremiumManager: Status cleared")
    }

    // MARK: - Verification

    /// Start verifying premium status
    func startVerification() {
        isVerifying = true
    }

    /// End verification
    func endVerification() {
        isVerifying = false
    }

    // MARK: - Product ID to Tier Mapping

    /// Determine tier from product ID
    static func tier(for productID: String) -> SubscriptionTier {
        if InsioConfig.StoreKit.proProductIDs.contains(productID) {
            return .pro
        } else if InsioConfig.StoreKit.plusProductIDs.contains(productID) {
            return .plus
        } else {
            return .free
        }
    }

    // MARK: - Trial Management

    /// Start the free trial (called on first app launch)
    func startFreeTrial() {
        guard userDefaults.object(forKey: trialStartDateKey) == nil else {
            // Trial already started
            return
        }

        let trialEndDate = Calendar.current.date(
            byAdding: .day,
            value: InsioConfig.StoreKit.freeTrialDays,
            to: Date()
        )!

        userDefaults.set(Date(), forKey: trialStartDateKey)

        updateSubscriptionStatus(
            tier: .free,
            productID: nil,
            expirationDate: trialEndDate,
            isInTrial: true
        )

        print("💎 PremiumManager: Free trial started - expires \(trialEndDate)")
    }

    /// Check if the free trial has expired
    var hasTrialExpired: Bool {
        guard let trialStart = userDefaults.object(forKey: trialStartDateKey) as? Date else {
            return false // No trial started
        }

        guard let trialEnd = Calendar.current.date(
            byAdding: .day,
            value: InsioConfig.StoreKit.freeTrialDays,
            to: trialStart
        ) else {
            return true
        }

        return Date() > trialEnd
    }

    /// Check trial status and update if needed
    func checkTrialStatus() {
        // If user has a paid subscription, trial doesn't matter
        if currentTier != .free {
            if isInTrial {
                isInTrial = false
                trialDaysRemaining = nil
                cacheStatus()
            }
            return
        }

        // Check if trial has expired
        if isInTrial && hasTrialExpired {
            isInTrial = false
            trialDaysRemaining = nil
            expirationDate = nil
            cacheStatus()
            print("💎 PremiumManager: Free trial has expired")
        }
    }

    // MARK: - Caching

    private func cacheStatus() {
        userDefaults.set(currentTier.rawValue, forKey: tierKey)
        userDefaults.set(activeProductID, forKey: productIDKey)
        userDefaults.set(isInTrial, forKey: trialStatusKey)

        if let expiration = expirationDate {
            userDefaults.set(expiration, forKey: expirationDateKey)
        } else {
            userDefaults.removeObject(forKey: expirationDateKey)
        }
    }

    private func loadCachedStatus() {
        if let tierString = userDefaults.string(forKey: tierKey),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        } else {
            currentTier = .free
        }

        activeProductID = userDefaults.string(forKey: productIDKey)
        isInTrial = userDefaults.bool(forKey: trialStatusKey)
        expirationDate = userDefaults.object(forKey: expirationDateKey) as? Date

        // Check if cached premium has expired
        if let expiration = expirationDate, expiration < Date() {
            // Subscription has expired based on cached date
            // StoreKitService will verify and update on next check
            print("💎 PremiumManager: Cached subscription may have expired")
        }

        print("💎 PremiumManager: Loaded cached status - tier = \(currentTier.rawValue)")
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension PremiumManager {
    /// Force tier for testing
    func debugSetTier(_ tier: SubscriptionTier) {
        updateSubscriptionStatus(tier: tier, productID: "debug.\(tier.rawValue)", expirationDate: nil)
    }

    /// Force trial status for testing
    func debugSetTrial(tier: SubscriptionTier, daysRemaining: Int) {
        let expiration = Calendar.current.date(byAdding: .day, value: daysRemaining, to: Date())
        updateSubscriptionStatus(
            tier: tier,
            productID: "debug.\(tier.rawValue).trial",
            expirationDate: expiration,
            isInTrial: true
        )
    }
}
#endif
