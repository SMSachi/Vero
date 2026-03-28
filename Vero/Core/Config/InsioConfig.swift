//
//  InsioConfig.swift
//  Insio Health
//
//  Central configuration for Insio Health app services.
//  Contains API keys, product identifiers, and tier limits.
//
//  TIERS:
//  - FREE: 3-day trial, then workout logging only
//  - PLUS ($4.99/mo): Weekly AI trends, 30-day history
//  - PRO ($12.99/mo): Full per-workout AI, unlimited history
//
//  SETUP:
//  1. Replace OpenRouter API key with your key from https://openrouter.ai
//  2. Configure StoreKit product IDs to match your App Store Connect setup
//  3. Create a StoreKit Configuration file for local testing
//

import Foundation

// MARK: - Insio Configuration

enum InsioConfig {

    // MARK: - OpenRouter AI Configuration

    enum OpenRouter {
        /// Your OpenRouter API key
        /// Get this from: https://openrouter.ai/keys
        /// IMPORTANT: In production, use environment variables or secure storage
        static let apiKey = "YOUR_OPENROUTER_API_KEY"

        /// The AI model to use for text enhancement
        /// Recommended models for natural language:
        /// - "anthropic/claude-3-haiku" (fast, affordable)
        /// - "anthropic/claude-3-sonnet" (balanced)
        /// - "openai/gpt-4o-mini" (fast, affordable)
        static let model = "anthropic/claude-3-haiku"

        /// OpenRouter API endpoint
        static let baseURL = "https://openrouter.ai/api/v1"

        /// Maximum tokens for response
        static let maxTokens = 500

        /// Temperature for response generation (0.0 - 1.0)
        /// Lower = more focused, Higher = more creative
        static let temperature = 0.7

        /// Whether OpenRouter is configured
        static var isConfigured: Bool {
            !apiKey.hasPrefix("YOUR_") && apiKey.count > 20
        }
    }

    // MARK: - StoreKit Configuration

    enum StoreKit {
        // MARK: Plus Tier ($4.99/month)

        /// Product identifier for Plus monthly subscription
        static let plusMonthlyProductID = "insio_plus_monthly"

        /// Product identifier for Plus yearly subscription (NOT used at launch)
        /// Kept for future use
        static let plusYearlyProductID = "insio_plus_yearly"

        // MARK: Pro Tier ($12.99/month)

        /// Product identifier for Pro monthly subscription
        static let proMonthlyProductID = "insio_pro_monthly"

        /// Product identifier for Pro yearly subscription (NOT used at launch)
        /// Kept for future use
        static let proYearlyProductID = "insio_pro_yearly"

        // MARK: Pricing (for display, actual prices come from App Store)

        /// Plus monthly price (display only - App Store is source of truth)
        static let plusMonthlyPrice: Decimal = 4.99

        /// Pro monthly price (display only - App Store is source of truth)
        static let proMonthlyPrice: Decimal = 12.99

        // MARK: Product Sets (LAUNCH: Monthly only)

        /// All Plus subscription product identifiers (monthly only at launch)
        static let plusProductIDs: Set<String> = [
            plusMonthlyProductID
            // plusYearlyProductID  // Commented out - not available at launch
        ]

        /// All Pro subscription product identifiers (monthly only at launch)
        static let proProductIDs: Set<String> = [
            proMonthlyProductID
            // proYearlyProductID  // Commented out - not available at launch
        ]

        /// All subscription product identifiers to request from App Store
        /// LAUNCH: Monthly subscriptions only
        static let allProductIDs: Set<String> = [
            plusMonthlyProductID,
            proMonthlyProductID
        ]

        /// Free trial duration in days
        static let freeTrialDays = 3

        /// App Store shared secret for receipt validation (if needed)
        static let sharedSecret = "YOUR_APP_STORE_SHARED_SECRET"
    }

    // MARK: - Feature Flags

    enum Features {
        /// Whether AI enhancement is enabled
        static var aiEnhancementEnabled: Bool {
            OpenRouter.isConfigured
        }

        /// Whether premium features are enforced
        /// Set to false during development to test premium features
        static let premiumEnforced = true

        /// Whether to show debug info in UI
        #if DEBUG
        static let showDebugInfo = true
        #else
        static let showDebugInfo = false
        #endif
    }

    // MARK: - Cache Configuration

    enum Cache {
        /// How long to cache AI-enhanced text (in seconds)
        static let aiEnhancementTTL: TimeInterval = 60 * 60 * 24 * 7 // 7 days

        /// Maximum number of cached AI enhancements
        static let aiEnhancementMaxCount = 100
    }

    // MARK: - Tier Limits

    enum TierLimits {
        // MARK: Free Tier (after 3-day trial expires)
        static let freeHistoryDays = 7
        static let freeMaxWorkoutsVisible = 10
        static let freeTrendDays = 0 // No trends on free after trial

        // MARK: Plus Tier
        static let plusHistoryDays = 30
        static let plusMaxWorkoutsVisible = 50
        static let plusTrendDays = 30

        // MARK: Pro Tier (unlimited represented by nil)
        static let proHistoryDays: Int? = nil // Unlimited
        static let proMaxWorkoutsVisible: Int? = nil // Unlimited
        static let proTrendDays: Int? = nil // Unlimited
    }

    // MARK: - Legal & Support

    enum Legal {
        /// Privacy Policy URL
        /// Update this with your actual privacy policy URL
        static let privacyPolicyURL = URL(string: "https://insiohealth.com/privacy")!

        /// Terms of Service URL
        /// Update this with your actual terms of service URL
        static let termsOfServiceURL = URL(string: "https://insiohealth.com/terms")!

        /// Support email address
        static let supportEmail = "support@insiohealth.com"

        /// App Store URL (update with actual App Store ID)
        static let appStoreURL = URL(string: "https://apps.apple.com/app/insio-health/id0000000000")!
    }

    // MARK: - AI Rules

    enum AIRules {
        /// AI is only for rewriting deterministic analysis - never hallucinate
        static let aiIsRewriteOnly = true

        /// Minimum workouts required for AI analysis
        static let minimumWorkoutsForAI = 1

        /// Fallback text for first workout
        static let firstWorkoutFallback = "Welcome to your fitness journey! Complete more workouts to unlock personalized insights."

        /// Fallback text for insufficient data
        static let lowDataFallback = "Keep logging your workouts to see trends and patterns emerge."
    }
}

// MARK: - Environment Helper

extension InsioConfig {

    /// Check if running in debug/development mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Check if running on simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Legacy VeroConfig Compatibility

/// Typealias for backward compatibility during migration
typealias VeroConfig = InsioConfig
