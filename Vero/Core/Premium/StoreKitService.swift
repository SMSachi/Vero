//
//  StoreKitService.swift
//  WellPattern Health
//
//  Handles StoreKit 2 subscriptions for premium features.
//  Supports 3-tier system: Free, Plus ($6.99/mo), Pro ($14.99/mo)
//  Includes free trial and restore functionality.
//
//  SETUP:
//  1. Configure products in App Store Connect
//  2. Create a StoreKit Configuration file for testing
//  3. Update product IDs in WellPatternConfig.swift
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

    /// Whether products failed to load (no account, network error, etc.)
    @Published private(set) var productsUnavailable = false

    /// Reason products are unavailable
    @Published private(set) var productsUnavailableReason: ProductsUnavailableReason = .none

    enum ProductsUnavailableReason {
        case none
        case noActiveAccount
        case networkError
        case configurationError
    }

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?
    private let premiumManager = PremiumManager.shared

    // MARK: - Initialization

    private init() {
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
            #if DEBUG
            print("🛒 StoreKit: Loading products...")
            #endif
            let productIDs = WellPatternConfig.StoreKit.allProductIDs
            #if DEBUG
            print("🛒 StoreKit: Requesting product IDs: \(productIDs)")
            #endif

            let storeProducts = try await Product.products(for: productIDs)

            // Check if we got any products
            if storeProducts.isEmpty {
                #if DEBUG
                print("🛒 StoreKit: ⚠️ No products returned from App Store")
                #endif
                #if DEBUG
                print("🛒 StoreKit: No active account or products not configured")
                #endif
                productsUnavailableReason = .noActiveAccount
                productsUnavailable = true
                isLoading = false
                return
            }

            // Sort all products by tier (no yearly products at launch)
            products = storeProducts.sorted { p1, p2 in
                let tier1 = tierForProduct(p1)
                let tier2 = tierForProduct(p2)
                return tier1 < tier2
            }

            // Separate by tier
            plusProducts = products.filter { WellPatternConfig.StoreKit.plusProductIDs.contains($0.id) }
            proProducts = products.filter { WellPatternConfig.StoreKit.proProductIDs.contains($0.id) }

            #if DEBUG
            print("🛒 StoreKit: ✅ Loaded \(products.count) products")
            #endif
            #if DEBUG
            print("🛒 StoreKit: Plus products: \(plusProducts.count)")
            #endif
            #if DEBUG
            print("🛒 StoreKit: Pro products: \(proProducts.count)")
            #endif

            for product in products {
                #if DEBUG
                print("🛒 StoreKit: - \(product.id): \(product.displayPrice)")
                #endif
            }

        } catch {
            #if DEBUG
            print("🛒 StoreKit: ❌ Failed to load products: \(error)")
            #endif

            // Determine error type
            let errorString = String(describing: error).lowercased()
            if errorString.contains("no active account") || errorString.contains("not signed in") {
                productsUnavailableReason = .noActiveAccount
            } else if errorString.contains("network") || errorString.contains("connection") {
                productsUnavailableReason = .networkError
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
            #if DEBUG
            print("🛒 StoreKit: Purchasing \(product.id)...")
            #endif

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check verification
                let transaction = try checkVerified(verification)

                // Update premium status
                await updateSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                #if DEBUG
                print("🛒 StoreKit: Purchase successful!")
                #endif
                isPurchasing = false
                return true

            case .userCancelled:
                #if DEBUG
                print("🛒 StoreKit: User cancelled purchase")
                #endif
                isPurchasing = false
                return false

            case .pending:
                #if DEBUG
                print("🛒 StoreKit: Purchase pending (Ask to Buy)")
                #endif
                errorMessage = "Purchase is pending approval"
                isPurchasing = false
                return false

            @unknown default:
                #if DEBUG
                print("🛒 StoreKit: Unknown purchase result")
                #endif
                isPurchasing = false
                return false
            }

        } catch {
            #if DEBUG
            print("🛒 StoreKit: Purchase failed: \(error)")
            #endif
            errorMessage = "Purchase failed. Please try again."
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async {
        #if DEBUG
        print("🛒 StoreKit: Restoring purchases...")
        #endif
        isLoading = true
        errorMessage = nil

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update subscription status
            await updateSubscriptionStatus()

            if premiumManager.isPaid {
                #if DEBUG
                print("🛒 StoreKit: Restore successful - \(premiumManager.currentTier.rawValue) active")
                #endif
            } else {
                #if DEBUG
                print("🛒 StoreKit: Restore complete - no active subscription found")
                #endif
                errorMessage = "No active subscription found"
            }

        } catch {
            #if DEBUG
            print("🛒 StoreKit: Restore failed: \(error)")
            #endif
            errorMessage = "Unable to restore purchases. Please try again."
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    /// Update the current subscription status
    func updateSubscriptionStatus() async {
        #if DEBUG
        print("🛒 StoreKit: Updating subscription status...")
        #endif
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
                if WellPatternConfig.StoreKit.allProductIDs.contains(transaction.productID) {
                    let transactionTier = PremiumManager.tier(for: transaction.productID)

                    // Keep track of highest tier
                    if transactionTier > highestTier {
                        highestTier = transactionTier
                        activeProduct = products.first { $0.id == transaction.productID }
                        expirationDate = transaction.expirationDate

                        // Check for trial (transaction.offer requires iOS 17.2+)
                        if #available(iOS 17.2, *) {
                            if let offer = transaction.offer {
                                isInTrial = offer.type == .introductory
                            }
                        }
                    }

                    #if DEBUG
                    print("🛒 StoreKit: Found subscription: \(transaction.productID) (\(transactionTier.rawValue))")
                    #endif
                }

            } catch {
                #if DEBUG
                print("🛒 StoreKit: Failed to verify transaction: \(error)")
                #endif
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

        #if DEBUG
        print("🛒 StoreKit: Current tier: \(highestTier.rawValue)")
        #endif
        #if DEBUG
        print("🛒 StoreKit: Expires: \(expirationDate?.description ?? "unknown")")
        #endif
        #if DEBUG
        print("🛒 StoreKit: Is trial: \(isInTrial)")
        #endif
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
                    #if DEBUG
                    print("🛒 StoreKit: Transaction verification failed: \(error)")
                    #endif
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

    /// Get the monthly Plus product
    var plusMonthlyProduct: Product? {
        products.first { $0.id == WellPatternConfig.StoreKit.plusMonthlyProductID }
    }

    /// Get the monthly Pro product
    var proMonthlyProduct: Product? {
        products.first { $0.id == WellPatternConfig.StoreKit.proMonthlyProductID }
    }

    // MARK: - Legacy Compatibility (monthly-only launch — no yearly products)

    var monthlyProduct: Product? { proMonthlyProduct }
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
        if WellPatternConfig.StoreKit.proProductIDs.contains(id) {
            return .pro
        } else if WellPatternConfig.StoreKit.plusProductIDs.contains(id) {
            return .plus
        } else {
            return .free
        }
    }
}
