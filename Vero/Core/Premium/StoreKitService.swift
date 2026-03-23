//
//  StoreKitService.swift
//  Insio Health
//
//  Handles StoreKit 2 subscriptions for premium features.
//  Supports 3-tier system: Free, Plus ($4.99/mo), Pro ($12.99/mo)
//  Includes free trial and restore functionality.
//
//  SETUP:
//  1. Configure products in App Store Connect
//  2. Create a StoreKit Configuration file for testing
//  3. Update product IDs in InsioConfig.swift
//

import Foundation
import StoreKit

// MARK: - StoreKit Service

@MainActor
final class StoreKitService: ObservableObject {

    // MARK: - Singleton

    static let shared = StoreKitService()

    // MARK: - Published State

    /// All available products
    @Published private(set) var products: [Product] = []

    /// Plus tier products
    @Published private(set) var plusProducts: [Product] = []

    /// Pro tier products
    @Published private(set) var proProducts: [Product] = []

    /// Currently active subscription
    @Published private(set) var purchasedSubscription: Product?

    /// Current subscription tier
    @Published private(set) var currentTier: SubscriptionTier = .free

    /// Whether products are being loaded
    @Published private(set) var isLoading = false

    /// Whether a purchase is in progress
    @Published private(set) var isPurchasing = false

    /// Error message for display
    @Published var errorMessage: String?

    /// Whether running in simulator (StoreKit won't work properly)
    @Published private(set) var isSimulator = false

    /// Whether products failed to load (no account, network error, etc.)
    @Published private(set) var productsUnavailable = false

    /// Reason products are unavailable
    @Published private(set) var productsUnavailableReason: ProductsUnavailableReason = .none

    enum ProductsUnavailableReason {
        case none
        case simulator
        case noActiveAccount
        case networkError
        case configurationError
    }

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?
    private let premiumManager = PremiumManager.shared

    // MARK: - Initialization

    private init() {
        // Check if running in simulator
        #if targetEnvironment(simulator)
        isSimulator = true
        print("🛒 StoreKit: ⚠️ Running in SIMULATOR - StoreKit functionality limited")
        #endif

        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load products
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Load available products from the App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        productsUnavailable = false
        productsUnavailableReason = .none

        do {
            print("🛒 StoreKit: Loading products...")
            let productIDs = InsioConfig.StoreKit.allProductIDs
            print("🛒 StoreKit: Requesting product IDs: \(productIDs)")

            let storeProducts = try await Product.products(for: productIDs)

            // Check if we got any products
            if storeProducts.isEmpty {
                print("🛒 StoreKit: ⚠️ No products returned from App Store")

                // Determine the reason
                if isSimulator {
                    print("🛒 StoreKit: Running in simulator - this is expected")
                    productsUnavailableReason = .simulator
                } else {
                    print("🛒 StoreKit: No active account or products not configured")
                    productsUnavailableReason = .noActiveAccount
                }

                productsUnavailable = true
                isLoading = false
                return
            }

            // Sort all products by tier, then by billing period (yearly first)
            products = storeProducts.sorted { p1, p2 in
                let tier1 = tierForProduct(p1)
                let tier2 = tierForProduct(p2)

                if tier1 != tier2 {
                    return tier1 < tier2
                }

                // Within same tier, yearly first
                return isYearly(p1) && !isYearly(p2)
            }

            // Separate by tier
            plusProducts = products.filter { InsioConfig.StoreKit.plusProductIDs.contains($0.id) }
            proProducts = products.filter { InsioConfig.StoreKit.proProductIDs.contains($0.id) }

            print("🛒 StoreKit: ✅ Loaded \(products.count) products")
            print("🛒 StoreKit: Plus products: \(plusProducts.count)")
            print("🛒 StoreKit: Pro products: \(proProducts.count)")

            for product in products {
                print("🛒 StoreKit: - \(product.id): \(product.displayPrice)")
            }

        } catch {
            print("🛒 StoreKit: ❌ Failed to load products: \(error)")

            // Determine error type
            let errorString = String(describing: error).lowercased()
            if errorString.contains("no active account") || errorString.contains("not signed in") {
                productsUnavailableReason = .noActiveAccount
            } else if errorString.contains("network") || errorString.contains("connection") {
                productsUnavailableReason = .networkError
            } else if isSimulator {
                productsUnavailableReason = .simulator
            } else {
                productsUnavailableReason = .configurationError
            }

            productsUnavailable = true
            errorMessage = "Unable to load subscription options."
        }

        isLoading = false
    }

    // MARK: - Purchasing

    /// Purchase a subscription product
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil

        do {
            print("🛒 StoreKit: Purchasing \(product.id)...")

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check verification
                let transaction = try checkVerified(verification)

                // Update premium status
                await updateSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                print("🛒 StoreKit: Purchase successful!")
                isPurchasing = false
                return true

            case .userCancelled:
                print("🛒 StoreKit: User cancelled purchase")
                isPurchasing = false
                return false

            case .pending:
                print("🛒 StoreKit: Purchase pending (Ask to Buy)")
                errorMessage = "Purchase is pending approval"
                isPurchasing = false
                return false

            @unknown default:
                print("🛒 StoreKit: Unknown purchase result")
                isPurchasing = false
                return false
            }

        } catch {
            print("🛒 StoreKit: Purchase failed: \(error)")
            errorMessage = "Purchase failed. Please try again."
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async {
        print("🛒 StoreKit: Restoring purchases...")
        isLoading = true
        errorMessage = nil

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update subscription status
            await updateSubscriptionStatus()

            if premiumManager.isPaid {
                print("🛒 StoreKit: Restore successful - \(premiumManager.currentTier.rawValue) active")
            } else {
                print("🛒 StoreKit: Restore complete - no active subscription found")
                errorMessage = "No active subscription found"
            }

        } catch {
            print("🛒 StoreKit: Restore failed: \(error)")
            errorMessage = "Unable to restore purchases. Please try again."
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    /// Update the current subscription status
    func updateSubscriptionStatus() async {
        print("🛒 StoreKit: Updating subscription status...")
        premiumManager.startVerification()

        var highestTier: SubscriptionTier = .free
        var activeProduct: Product?
        var expirationDate: Date?
        var isInTrial = false

        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if this is one of our subscription products
                if InsioConfig.StoreKit.allProductIDs.contains(transaction.productID) {
                    let transactionTier = PremiumManager.tier(for: transaction.productID)

                    // Keep track of highest tier
                    if transactionTier > highestTier {
                        highestTier = transactionTier
                        activeProduct = products.first { $0.id == transaction.productID }
                        expirationDate = transaction.expirationDate

                        // Check for trial
                        if let offer = transaction.offer {
                            isInTrial = offer.type == .introductory
                        }
                    }

                    print("🛒 StoreKit: Found subscription: \(transaction.productID) (\(transactionTier.rawValue))")
                }

            } catch {
                print("🛒 StoreKit: Failed to verify transaction: \(error)")
            }
        }

        // Update premium manager
        premiumManager.updateSubscriptionStatus(
            tier: highestTier,
            productID: activeProduct?.id,
            expirationDate: expirationDate,
            isInTrial: isInTrial
        )

        currentTier = highestTier
        purchasedSubscription = activeProduct
        premiumManager.endVerification()

        print("🛒 StoreKit: Current tier: \(highestTier.rawValue)")
        print("🛒 StoreKit: Expires: \(expirationDate?.description ?? "unknown")")
        print("🛒 StoreKit: Is trial: \(isInTrial)")
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Update subscription status
                    await self.updateSubscriptionStatus()

                    // Finish the transaction
                    await transaction.finish()

                } catch {
                    print("🛒 StoreKit: Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    /// Verify a transaction result
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Product Helpers

    private func tierForProduct(_ product: Product) -> SubscriptionTier {
        PremiumManager.tier(for: product.id)
    }

    private func isYearly(_ product: Product) -> Bool {
        product.id.contains("yearly")
    }

    /// Get the monthly Plus product
    var plusMonthlyProduct: Product? {
        products.first { $0.id == InsioConfig.StoreKit.plusMonthlyProductID }
    }

    /// Get the yearly Plus product
    var plusYearlyProduct: Product? {
        products.first { $0.id == InsioConfig.StoreKit.plusYearlyProductID }
    }

    /// Get the monthly Pro product
    var proMonthlyProduct: Product? {
        products.first { $0.id == InsioConfig.StoreKit.proMonthlyProductID }
    }

    /// Get the yearly Pro product
    var proYearlyProduct: Product? {
        products.first { $0.id == InsioConfig.StoreKit.proYearlyProductID }
    }

    /// Calculate savings percentage for yearly vs monthly
    func yearlySavingsPercent(for tier: SubscriptionTier) -> Int? {
        let monthly: Product?
        let yearly: Product?

        switch tier {
        case .plus:
            monthly = plusMonthlyProduct
            yearly = plusYearlyProduct
        case .pro:
            monthly = proMonthlyProduct
            yearly = proYearlyProduct
        case .free:
            return nil
        }

        guard let m = monthly, let y = yearly else { return nil }

        let yearlyMonthlyEquivalent = y.price / 12
        let savings = (1 - (yearlyMonthlyEquivalent / m.price)) * 100

        return NSDecimalNumber(decimal: savings).intValue
    }

    /// Format price per month for yearly subscription
    func yearlyPricePerMonth(for tier: SubscriptionTier) -> String? {
        let yearly: Product?

        switch tier {
        case .plus:
            yearly = plusYearlyProduct
        case .pro:
            yearly = proYearlyProduct
        case .free:
            return nil
        }

        guard let y = yearly else { return nil }

        let monthlyPrice = y.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = y.priceFormatStyle.locale

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    // MARK: - Legacy Compatibility

    /// Legacy: yearly product (maps to Pro yearly)
    var yearlyProduct: Product? { proYearlyProduct }

    /// Legacy: monthly product (maps to Pro monthly)
    var monthlyProduct: Product? { proMonthlyProduct }

    /// Legacy: savings percent (maps to Pro)
    var yearlySavingsPercent: Int? { yearlySavingsPercent(for: .pro) }

    /// Legacy: yearly per month price (maps to Pro)
    var yearlyPricePerMonth: String? { yearlyPricePerMonth(for: .pro) }
}

// MARK: - Product Extensions

extension Product {
    /// Whether this product has a free trial
    var hasFreeTrial: Bool {
        guard let subscription = subscription else { return false }
        return subscription.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Free trial duration in days
    var freeTrialDays: Int? {
        guard let subscription = subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }

        switch offer.period.unit {
        case .day:
            return offer.period.value
        case .week:
            return offer.period.value * 7
        case .month:
            return offer.period.value * 30
        case .year:
            return offer.period.value * 365
        @unknown default:
            return nil
        }
    }

    /// Formatted subscription period
    var subscriptionPeriodText: String {
        guard let subscription = subscription else { return "" }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "day" : "\(subscription.subscriptionPeriod.value) days"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "week" : "\(subscription.subscriptionPeriod.value) weeks"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "month" : "\(subscription.subscriptionPeriod.value) months"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "year" : "\(subscription.subscriptionPeriod.value) years"
        @unknown default:
            return ""
        }
    }

    /// Tier for this product
    var tier: SubscriptionTier {
        if InsioConfig.StoreKit.proProductIDs.contains(id) {
            return .pro
        } else if InsioConfig.StoreKit.plusProductIDs.contains(id) {
            return .plus
        } else {
            return .free
        }
    }
}
