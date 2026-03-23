//
//  SupabaseConfig.swift
//  Insio Health
//
//  Supabase configuration and client initialization.
//
//  SETUP:
//  1. Add the Supabase Swift Package to your Xcode project:
//     - File > Add Package Dependencies
//     - Enter: https://github.com/supabase/supabase-swift
//     - Add the "Supabase" product to your target
//  2. Create a Supabase project at https://supabase.com
//  3. Copy your project URL and anon key from Settings > API
//  4. Replace the placeholder values below
//  5. Set SUPABASE_ENABLED = true below
//

import Foundation
import Supabase

// MARK: - Feature Flag

/// Set to true after adding Supabase Swift Package and configuring credentials
let SUPABASE_ENABLED = true

// MARK: - Supabase Configuration

enum SupabaseConfig {

    // MARK: - Credentials

    /// Your Supabase project URL (e.g., "https://xxxx.supabase.co")
    /// Get this from Supabase Dashboard > Settings > API > Project URL
    static let projectURL = "https://guycbtrdworovjqdfiea.supabase.co"

    /// Your Supabase anon/public key
    /// Get this from Supabase Dashboard > Settings > API > Project API keys > anon public
    static let anonKey = "sb_publishable_rFeDM4nkgkoYge6nFNZ2Mw_mMzWAAdF"

    // MARK: - Validation

    /// Check if credentials are configured
    static var isConfigured: Bool {
        SUPABASE_ENABLED &&
        !projectURL.hasPrefix("YOUR_") &&
        !anonKey.hasPrefix("YOUR_") &&
        anonKey.count > 20  // Basic check for non-placeholder key
    }

    // MARK: - Client

    /// Shared Supabase client instance
    static let client: SupabaseClient = {
        guard let url = URL(string: projectURL) else {
            fatalError("SupabaseConfig: Invalid project URL: \(projectURL)")
        }

        print("SupabaseConfig: ══════════════════════════════════════════════════")
        print("SupabaseConfig: INITIALIZING SUPABASE CLIENT")
        print("SupabaseConfig: ══════════════════════════════════════════════════")
        print("SupabaseConfig: Project URL: \(projectURL)")
        print("SupabaseConfig: Anon key length: \(anonKey.count) chars")
        print("SupabaseConfig: Anon key prefix: \(String(anonKey.prefix(20)))...")

        // Validate key format (Supabase uses JWT format "eyJ..." or publishable format "sb_...")
        let isValidFormat = anonKey.hasPrefix("eyJ") || anonKey.hasPrefix("sb_")
        if !isValidFormat {
            print("SupabaseConfig: ⚠️ WARNING: Anon key format not recognized")
            print("SupabaseConfig: ⚠️ Expected JWT (eyJ...) or publishable (sb_...) format")
            print("SupabaseConfig: ⚠️ If auth/sync fails, verify your anon key from Supabase Dashboard")
        } else {
            print("SupabaseConfig: ✓ Anon key format valid")
        }

        print("SupabaseConfig: isConfigured: \(isConfigured)")
        print("SupabaseConfig: ══════════════════════════════════════════════════")

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }()
}

// MARK: - Database Table Names

extension SupabaseConfig {

    enum Tables {
        static let workouts = "workouts"
        static let dailyContexts = "daily_contexts"
        static let checkIns = "check_ins"
        static let postWorkoutCheckIns = "post_workout_check_ins"
        static let nextDayRecoveries = "next_day_recoveries"
        static let trendInsights = "trend_insights"
        static let userProfiles = "user_profiles"
    }
}
