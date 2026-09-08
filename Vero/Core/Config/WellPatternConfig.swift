//
//  WellPatternConfig.swift
//  WellPattern Health
//
//  Central configuration for WellPattern Health app services.
//  Contains API keys, product identifiers, and tier limits.
//
//  TIERS:
//  - FREE: $0, workout logging + health data viewing, no AI
//  - PLUS ($7/mo): Daily AI guidance, 30-day history
//  - PRO ($15/mo): Deeper per-workout AI + follow-ups, unlimited history
//
//  SETUP:
//  1. Replace OpenRouter API key with your key from https://openrouter.ai
//  2. Configure StoreKit product IDs to match your App Store Connect setup
//  3. Create a StoreKit Configuration file for local testing
//

import Foundation

// MARK: - WellPattern Configuration

enum WellPatternConfig {

    // MARK: - OpenRouter AI Configuration

    enum OpenRouter {
        /// OpenRouter API key — never hardcode here.
        /// Set OPENROUTER_API_KEY in Secrets.xcconfig (gitignored, never commit).
        /// Build system injects it into Info.plist via INFOPLIST_KEY_OPENROUTER_API_KEY.
        static var apiKey: String {
            if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String,
               !plistKey.isEmpty {
                return plistKey
            }
            return "YOUR_OPENROUTER_API_KEY"
        }

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
        // MARK: Plus Tier ($7/month)
        // App Store Connect: create product ID "com.sachishah.wellpattern.plus.monthly" priced at $6.99
        // (App Store rounds to nearest tier: $6.99 is Tier 7)

        /// Product identifier for Plus monthly subscription
        static let plusMonthlyProductID = "com.sachishah.wellpattern.plus.monthly"

        // MARK: Pro Tier ($15/month)
        // App Store Connect: create product ID "com.sachishah.wellpattern.pro.monthly" priced at $14.99
        // (App Store rounds to nearest tier: $14.99 is Tier 15)

        /// Product identifier for Pro monthly subscription
        static let proMonthlyProductID = "com.sachishah.wellpattern.pro.monthly"

        // MARK: Pricing (for display, actual prices come from App Store)

        /// Plus monthly price (display only - App Store is source of truth)
        static let plusMonthlyPrice: Decimal = 6.99

        /// Pro monthly price (display only - App Store is source of truth)
        static let proMonthlyPrice: Decimal = 14.99

        // MARK: Product Sets (LAUNCH: Monthly only — no yearly products)

        /// All Plus subscription product identifiers
        static let plusProductIDs: Set<String> = [plusMonthlyProductID]

        /// All Pro subscription product identifiers
        static let proProductIDs: Set<String> = [proMonthlyProductID]

        /// All subscription product identifiers to request from App Store
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

        /// DEBUG only: bypass Pro-tier check for workout AI so you can test without a subscription.
        /// Set to false to test the real gate. Has no effect in release builds.
        #if DEBUG
        static let bypassWorkoutAITier = true
        #else
        static let bypassWorkoutAITier = false
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
    // TODO: Replace all four values below before App Store submission.

    enum Legal {
        /// Privacy Policy URL — TODO: replace with WellPattern privacy policy URL
        static let privacyPolicyURL = URL(string: "https://pickle-wall-bb8.notion.site/Insio-Privacy-Policy-33d1ba29da8e80b1a00fc750457b6473")!

        /// Terms of Service URL — TODO: replace with a SEPARATE WellPattern terms URL (must differ from privacy policy)
        static let termsOfServiceURL = URL(string: "https://pickle-wall-bb8.notion.site/Insio-Privacy-Policy-33d1ba29da8e80b1a00fc750457b6473")!

        /// Support email — TODO: replace with WellPattern support address before shipping
        static let supportEmail = "insiohealth@gmail.com"

        /// App Store URL — TODO: replace id0000000000 with real Apple ID after App Store Connect record is created
        static let appStoreURL = URL(string: "https://apps.apple.com/app/wellpattern/id0000000000")!
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

extension WellPatternConfig {

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

