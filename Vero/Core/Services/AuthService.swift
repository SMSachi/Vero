//
//  AuthService.swift
//  WellPattern Health
//
//  Handles user authentication via Supabase Auth.
//  Supports signup, login, logout, and session persistence.
//

import Foundation
import Supabase
import SwiftUI

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {

    // MARK: - Singleton

    static let shared = AuthService()

    // MARK: - Published State

    /// Current authenticated user (Supabase User type)
    @Published private(set) var currentUser: User?

    /// Whether user is authenticated
    @Published private(set) var isAuthenticated = false

    /// Whether auth state is being loaded
    @Published private(set) var isLoading = true

    /// Current auth error message (user-facing)
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        #if DEBUG
        print("🔐 AuthService: ══════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🔐 AuthService: INITIALIZING")
        #endif
        #if DEBUG
        print("🔐 AuthService: isConfigured = \(SupabaseConfig.isConfigured)")
        #endif
        #if DEBUG
        print("🔐 AuthService: isLoading = \(isLoading) (initial)")
        #endif
        #if DEBUG
        print("🔐 AuthService: ══════════════════════════════════════════════════")
        #endif

        #if targetEnvironment(simulator)
        // On simulator, set isLoading = false immediately to prevent hangs from HealthKit/network
        // But DO NOT return early - we still need proper @Published observation to work
        #if DEBUG
        print("🔐 AuthService: SIMULATOR - setting isLoading = false immediately")
        #endif
        self.isLoading = false
        // Note: We skip setupAuthStateListener on simulator because it can hang
        // The signIn/signOut methods will update state directly
        #if DEBUG
        print("🔐 AuthService: SIMULATOR - skipping auth listener (direct state updates only)")
        #endif
        #else
        // Start listening for auth state changes
        setupAuthStateListener()
        #endif
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
        #if DEBUG
        print("🔐 AuthService: setupAuthStateListener() ENTER")
        #endif
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif

        // CRITICAL: If Supabase is not configured, skip auth and go straight to guest-capable state
        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("🔐 AuthService: ⚡ Supabase NOT configured - setting isLoading = false IMMEDIATELY")
            #endif
            self.isLoading = false
            #if DEBUG
            print("🔐 AuthService: ✅ isLoading is now: \(self.isLoading)")
            #endif
            return
        }

        #if DEBUG
        print("🔐 AuthService: Supabase IS configured, starting auth task...")
        #endif

        authStateTask = Task { [weak self] in
            guard let self = self else {
                #if DEBUG
                print("🔐 AuthService: ❌ Self is nil in auth task - this is a bug")
                #endif
                return
            }

            #if DEBUG
            print("🔐 AuthService: 📍 STEP 1: Inside auth task, about to check session...")
            #endif

            // Check for existing session first with a timeout
            await self.checkExistingSessionWithTimeout()

            #if DEBUG
            print("🔐 AuthService: 📍 STEP 2: Session check complete, isLoading=\(self.isLoading)")
            #endif
            #if DEBUG
            print("🔐 AuthService: 📍 STEP 3: Starting authStateChanges listener...")
            #endif

            // Listen for auth state changes
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                #if DEBUG
                print("🔐 AuthService: 📍 Auth event received: \(event)")
                #endif

                await MainActor.run {
                    switch event {
                    case .initialSession:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: initialSession")
                        #endif
                        self.handleSession(session)
                        self.isLoading = false
                        #if DEBUG
                        print("🔐 AuthService: ✅ isLoading set to false (initialSession)")
                        #endif

                    case .signedIn:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: signedIn")
                        #endif
                        self.handleSession(session)
                        self.isLoading = false
                        #if DEBUG
                        print("🔐 AuthService: ✅ isLoading set to false (signedIn)")
                        #endif

                    case .signedOut:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: signedOut")
                        #endif
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.isLoading = false
                        #if DEBUG
                        print("🔐 AuthService: ✅ isLoading set to false (signedOut)")
                        #endif

                    case .tokenRefreshed:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: tokenRefreshed")
                        #endif
                        self.handleSession(session)

                    case .userUpdated:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: userUpdated")
                        #endif
                        self.handleSession(session)

                    case .userDeleted:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: userDeleted")
                        #endif
                        self.currentUser = nil
                        self.isAuthenticated = false

                    case .passwordRecovery, .mfaChallengeVerified:
                        #if DEBUG
                        print("🔐 AuthService: 📍 Event: \(event) (ignored)")
                        #endif
                        break
                    }
                }
            }
            #if DEBUG
            print("🔐 AuthService: ⚠️ authStateChanges listener ENDED (loop exited)")
            #endif
        }

        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
        #if DEBUG
        print("🔐 AuthService: setupAuthStateListener() EXIT - Task started")
        #endif
        #if DEBUG
        print("🔐 AuthService: NOTE: isLoading is still \(self.isLoading) (Task runs async)")
        #endif
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
    }

    private func handleSession(_ session: Session?) {
        withAnimation(nil) {
            if let session = session {
                #if DEBUG
                print("🔐 AuthService: Session found - user: \(session.user.email ?? "no email")")
                #endif
                self.currentUser = session.user
                self.isAuthenticated = true
            } else {
                #if DEBUG
                print("🔐 AuthService: No session")
                #endif
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }

    /// Check for existing session with a timeout to prevent hanging
    private func checkExistingSessionWithTimeout() async {
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
        #if DEBUG
        print("🔐 AuthService: checkExistingSessionWithTimeout() ENTER")
        #endif
        #if DEBUG
        print("🔐 AuthService: Using 3-second timeout (reduced for faster startup)")
        #endif
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif

        // Use a task group with timeout - REDUCED to 3 seconds
        let result = await withTaskGroup(of: Bool.self) { group in
            // Task 1: Check session
            group.addTask {
                #if DEBUG
                print("🔐 AuthService: 🔄 Session check task STARTED")
                #endif
                do {
                    #if DEBUG
                    print("🔐 AuthService: 🔄 Calling SupabaseConfig.client.auth.session...")
                    #endif
                    let session = try await SupabaseConfig.client.auth.session
                    #if DEBUG
                    print("🔐 AuthService: ✅ Got session for: \(session.user.email ?? "unknown")")
                    #endif
                    await MainActor.run {
                        self.currentUser = session.user
                        self.isAuthenticated = true
                        self.isLoading = false
                        #if DEBUG
                        print("🔐 AuthService: ✅ isLoading = false (session found)")
                        #endif
                    }
                    return true
                } catch {
                    #if DEBUG
                    print("🔐 AuthService: ❌ No session - \(error.localizedDescription)")
                    #endif
                    await MainActor.run {
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.isLoading = false
                        #if DEBUG
                        print("🔐 AuthService: ✅ isLoading = false (no session)")
                        #endif
                    }
                    return true
                }
            }

            // Task 2: Timeout after 3 seconds (reduced from 5)
            group.addTask {
                #if DEBUG
                print("🔐 AuthService: ⏱️ Timeout task STARTED (3 seconds)")
                #endif
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                #if DEBUG
                print("🔐 AuthService: ⏱️ Timeout task FIRED")
                #endif
                return false
            }

            // Wait for first task to complete
            #if DEBUG
            print("🔐 AuthService: ⏳ Waiting for first task to complete...")
            #endif
            if let firstResult = await group.next() {
                #if DEBUG
                print("🔐 AuthService: 📍 First task completed with result: \(firstResult)")
                #endif
                if firstResult {
                    // Session check completed
                    group.cancelAll()
                    return true
                }
            }

            // Timeout occurred - cancel remaining tasks
            #if DEBUG
            print("🔐 AuthService: ⚠️ Timeout occurred, cancelling remaining tasks")
            #endif
            group.cancelAll()
            return false
        }

        #if DEBUG
        print("🔐 AuthService: 📍 Task group completed with result: \(result)")
        #endif

        // If timeout occurred, force resolve loading state
        if !result {
            #if DEBUG
            print("🔐 AuthService: ⚠️ SESSION CHECK TIMED OUT - forcing isLoading = false")
            #endif
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.errorMessage = "Connection timed out. Please try again."
                #if DEBUG
                print("🔐 AuthService: ✅ isLoading = false (timeout)")
                #endif
            }
        }

        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
        #if DEBUG
        print("🔐 AuthService: checkExistingSessionWithTimeout() EXIT")
        #endif
        #if DEBUG
        print("🔐 AuthService: isLoading is now: \(self.isLoading)")
        #endif
        #if DEBUG
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        #endif
    }

    private func checkExistingSession() async {
        #if DEBUG
        print("🔐 AuthService: Checking for existing session...")
        #endif

        do {
            let session = try await SupabaseConfig.client.auth.session
            #if DEBUG
            print("🔐 AuthService: Found existing session for user: \(session.user.email ?? "unknown")")
            #endif
            await MainActor.run {
                self.currentUser = session.user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            #if DEBUG
            print("🔐 AuthService: No existing session - \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign Up

    /// Sign up with email and password
    func signUp(email: String, password: String, fullName: String? = nil) async throws {
        #if DEBUG
        print("🔐 AuthService: ========== SIGNUP ATTEMPT ==========")
        #endif
        #if DEBUG
        print("🔐 AuthService: Email: \(email)")
        #endif
        #if DEBUG
        print("🔐 AuthService: Password length: \(password.count)")
        #endif
        #if DEBUG
        print("🔐 AuthService: Full name: \(fullName ?? "not provided")")
        #endif

        // Clear previous errors
        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes RootView to flash loading screen
        // The button's own loading state (isSubmitting) provides user feedback

        // Validate email format
        guard isValidEmail(email) else {
            #if DEBUG
            print("🔐 AuthService: ❌ Email validation failed")
            #endif
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }
        #if DEBUG
        print("🔐 AuthService: ✓ Email format valid")
        #endif

        // Validate password length
        guard password.count >= 6 else {
            #if DEBUG
            print("🔐 AuthService: ❌ Password too short")
            #endif
            isLoading = false
            errorMessage = "Password must be at least 6 characters"
            throw AuthError.weakPassword
        }
        #if DEBUG
        print("🔐 AuthService: ✓ Password length valid")
        #endif

        // Check Supabase configuration
        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("🔐 AuthService: ❌ Supabase not configured")
            #endif
            isLoading = false
            errorMessage = "Authentication service not configured"
            throw AuthError.notConfigured
        }
        #if DEBUG
        print("🔐 AuthService: ✓ Supabase configured")
        #endif

        // Attempt signup with Supabase
        #if DEBUG
        print("🔐 AuthService: 🚀 Sending signup request to Supabase...")
        #endif

        do {
            let authResponse = try await SupabaseConfig.client.auth.signUp(
                email: email,
                password: password,
                data: fullName != nil ? ["full_name": .string(fullName!)] : nil
            )

            #if DEBUG
            print("🔐 AuthService: ✅ Signup response received")
            #endif
            #if DEBUG
            print("🔐 AuthService: User ID: \(authResponse.user.id.uuidString)")
            #endif
            #if DEBUG
            print("🔐 AuthService: User email: \(authResponse.user.email ?? "nil")")
            #endif
            #if DEBUG
            print("🔐 AuthService: Session: \(authResponse.session != nil ? "present" : "nil")")
            #endif

            // Check if email confirmation is required (no session means confirmation needed)
            if authResponse.session == nil {
                #if DEBUG
                print("🔐 AuthService: 📧 Email confirmation required")
                #endif
                isLoading = false
                errorMessage = nil
                throw AuthError.emailConfirmationRequired
            }

            // User is signed in
            let user = authResponse.user
            #if DEBUG
            print("🔐 AuthService: ✅ User created and signed in: \(user.email ?? "unknown")")
            #endif
            self.currentUser = user
            self.isAuthenticated = authResponse.session != nil
            self.isLoading = false

            #if DEBUG
            print("🔐 AuthService: ✅ State updated: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")
            #endif

        } catch let error as AuthError {
            // Re-throw our custom errors
            #if DEBUG
            print("🔐 AuthService: ❌ Auth error: \(error.localizedDescription)")
            #endif
            isLoading = false
            throw error

        } catch {
            // Handle Supabase errors
            #if DEBUG
            print("🔐 AuthService: ❌ Supabase error: \(error)")
            #endif
            #if DEBUG
            print("🔐 AuthService: Error type: \(type(of: error))")
            #endif
            #if DEBUG
            print("🔐 AuthService: Error description: \(error.localizedDescription)")
            #endif

            isLoading = false
            errorMessage = parseSupabaseError(error)
            throw AuthError.supabaseError(error)
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        #if DEBUG
        print("🔐 ════════════════════════════════════════════════════════════════")
        #endif
        #if DEBUG
        print("🔐 AUTH SERVICE: SIGN-IN ATTEMPT")
        #endif
        #if DEBUG
        print("🔐 AUTH SERVICE: Email: \(email)")
        #endif
        #if DEBUG
        print("🔐 AUTH SERVICE: isAuthenticated BEFORE: \(isAuthenticated)")
        #endif
        #if DEBUG
        print("🔐 ════════════════════════════════════════════════════════════════")
        #endif

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes RootView to flash loading screen
        // The button's own loading state (isSubmitting) provides user feedback

        // Validate inputs
        guard isValidEmail(email) else {
            #if DEBUG
            print("🔐 AUTH SERVICE: ❌ Email validation failed")
            #endif
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            #if DEBUG
            print("🔐 AUTH SERVICE: ❌ Password too short")
            #endif
            isLoading = false
            errorMessage = "Invalid email or password"
            throw AuthError.invalidCredentials
        }

        guard SupabaseConfig.isConfigured else {
            #if DEBUG
            print("🔐 AUTH SERVICE: ❌ Supabase not configured")
            #endif
            isLoading = false
            errorMessage = "Authentication service not configured"
            throw AuthError.notConfigured
        }

        #if DEBUG
        print("🔐 AUTH SERVICE: Sending sign-in request to Supabase...")
        #endif

        do {
            let session = try await SupabaseConfig.client.auth.signIn(
                email: email,
                password: password
            )

            #if DEBUG
            print("🔐 ════════════════════════════════════════════════════════════════")
            #endif
            #if DEBUG
            print("🔐 AUTH SERVICE: ✅ SIGN-IN SUCCESS")
            #endif
            #if DEBUG
            print("🔐 AUTH SERVICE: User: \(session.user.email ?? "unknown")")
            #endif
            #if DEBUG
            print("🔐 AUTH SERVICE: Setting isAuthenticated = true...")
            #endif
            #if DEBUG
            print("🔐 ════════════════════════════════════════════════════════════════")
            #endif

            // withAnimation(nil) ensures the @Published change reaches SwiftUI in a
            // zero-animation transaction. Without this, whatever spring is in flight
            // (keyboard dismiss, entrance animation) becomes the exit animation for
            // AuthContainerView, keeping its CA layer alive indefinitely.
            withAnimation(nil) {
                self.currentUser = session.user
                self.isAuthenticated = true
                self.isLoading = false
            }

            #if DEBUG
            print("🔐 AUTH SERVICE: ✅ isAuthenticated SET TO TRUE")
            #endif
            #if DEBUG
            print("🔐 AUTH SERVICE: AppRootView will recompute route → main")
            #endif
            #if DEBUG
            print("🔐 ════════════════════════════════════════════════════════════════")
            #endif

        } catch {
            #if DEBUG
            print("🔐 AUTH SERVICE: ❌ SIGN-IN FAILED: \(error)")
            #endif
            #if DEBUG
            print("🔐 AUTH SERVICE: Error: \(error.localizedDescription)")
            #endif

            isLoading = false
            errorMessage = parseSupabaseError(error)
            throw AuthError.supabaseError(error)
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() async throws {
        #if DEBUG
        print("🔐 AuthService: ========== SIGNOUT ==========")
        #endif

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes unnecessary loading screen flash

        do {
            try await SupabaseConfig.client.auth.signOut()
            #if DEBUG
            print("🔐 AuthService: ✅ Signout successful")
            #endif

            self.currentUser = nil
            self.isAuthenticated = false
            isLoading = false

        } catch {
            #if DEBUG
            print("🔐 AuthService: ❌ Signout error: \(error)")
            #endif
            isLoading = false
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Account Deletion

    /// Delete the current user's account
    /// This removes the user from Supabase Auth and should trigger cascade deletion of user data
    func deleteAccount() async throws {
        #if DEBUG
        print("🔐 AuthService: ========== ACCOUNT DELETION ==========")
        #endif

        guard isAuthenticated, let user = currentUser else {
            #if DEBUG
            print("🔐 AuthService: ❌ No authenticated user to delete")
            #endif
            throw AuthError.notAuthenticated
        }

        #if DEBUG
        print("🔐 AuthService: Deleting user: \(user.email ?? user.id.uuidString)")
        #endif

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes unnecessary loading screen flash

        do {
            // First, delete user data from Supabase tables
            // This should be handled by RLS policies or database triggers
            // But we'll explicitly delete to be safe
            if let userId = userId {
                #if DEBUG
                print("🔐 AuthService: Deleting user data from tables...")
                #endif

                // Delete from workouts
                try? await SupabaseConfig.client
                    .from(SupabaseConfig.Tables.workouts)
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                // Delete from check_ins
                try? await SupabaseConfig.client
                    .from(SupabaseConfig.Tables.checkIns)
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                // Delete from daily_contexts
                try? await SupabaseConfig.client
                    .from(SupabaseConfig.Tables.dailyContexts)
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                #if DEBUG
                print("🔐 AuthService: ✅ User data deleted from tables")
                #endif
            }

            // Sign out the user (this invalidates the session)
            try await SupabaseConfig.client.auth.signOut()

            #if DEBUG
            print("🔐 AuthService: ✅ User signed out")
            #endif

            // Note: Full user deletion from auth.users requires admin privileges
            // In production, you might need a server-side function to fully delete the user
            // For now, we've cleared their data and signed them out

            self.currentUser = nil
            self.isAuthenticated = false
            isLoading = false

            #if DEBUG
            print("🔐 AuthService: ✅ Account deletion complete")
            #endif

        } catch {
            #if DEBUG
            print("🔐 AuthService: ❌ Account deletion error: \(error)")
            #endif
            isLoading = false
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Password Reset

    /// Send password reset email
    func resetPassword(email: String) async throws {
        #if DEBUG
        print("🔐 AuthService: ========== PASSWORD RESET ==========")
        #endif
        #if DEBUG
        print("🔐 AuthService: Email: \(email)")
        #endif

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - button has its own loading state

        guard isValidEmail(email) else {
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }

        do {
            try await SupabaseConfig.client.auth.resetPasswordForEmail(email)
            #if DEBUG
            print("🔐 AuthService: ✅ Password reset email sent")
            #endif
            isLoading = false

        } catch {
            #if DEBUG
            print("🔐 AuthService: ❌ Password reset error: \(error)")
            #endif
            isLoading = false
            errorMessage = parseSupabaseError(error)
            throw error
        }
    }

    // MARK: - Helpers

    /// Get current user ID
    var userId: UUID? {
        currentUser?.id
    }

    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    /// Parse Supabase errors into user-friendly messages
    private func parseSupabaseError(_ error: Error) -> String {
        // Use both localizedDescription and String(describing:) — Supabase Swift SDK
        // sometimes embeds the actual API message in the type description rather than
        // the localized string (e.g. AuthApiError wrapping an underlying message).
        let localized = error.localizedDescription.lowercased()
        let described = String(describing: error).lowercased()
        let combined = localized + " " + described

        #if DEBUG
        print("🔐 [AUTH-ERROR] Parsing sign-in failure:")
        print("🔐   localizedDescription : \(error.localizedDescription)")
        print("🔐   String(describing:)  : \(String(describing: error))")
        #endif

        // Wrong password / bad credentials — most common path
        if combined.contains("invalid login credentials") ||
           combined.contains("invalid_credentials") ||
           combined.contains("invalid credentials") ||
           combined.contains("email not found") ||
           combined.contains("wrong password") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → wrong credentials")
            #endif
            return "Incorrect email or password"
        }

        if combined.contains("email not confirmed") ||
           combined.contains("email_not_confirmed") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → email not confirmed")
            #endif
            return "Please check your email and confirm your account"
        }

        if combined.contains("user already registered") ||
           combined.contains("already registered") ||
           combined.contains("already exists") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → already registered")
            #endif
            return "An account with this email already exists"
        }

        if combined.contains("signup is disabled") ||
           combined.contains("signups not allowed") ||
           combined.contains("email signups are disabled") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → signups disabled")
            #endif
            return "Sign up is currently disabled. Please enable Email provider in Supabase."
        }

        if combined.contains("password") && combined.contains("weak") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → weak password")
            #endif
            return "Password is too weak. Use at least 6 characters."
        }

        if combined.contains("rate limit") || combined.contains("too many requests") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → rate limited")
            #endif
            return "Too many attempts. Please wait a moment and try again."
        }

        if (error as? URLError)?.code == .timedOut || combined.contains("timed out") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → timeout")
            #endif
            return "Sign in timed out. Please check your connection and try again."
        }

        if combined.contains("network") || combined.contains("connection") ||
           combined.contains("offline") || combined.contains("internet") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → network error")
            #endif
            return "Network error. Please check your internet connection."
        }

        if combined.contains("invalid api key") ||
           combined.contains("invalid key") ||
           combined.contains("apikey") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → invalid API key")
            #endif
            return "Configuration error: Invalid API key"
        }

        if combined.contains("jwt") || combined.contains("token") {
            #if DEBUG
            print("🔐 [AUTH-ERROR] → JWT/token error")
            #endif
            return "Configuration error: Invalid authentication token"
        }

        #if DEBUG
        print("🔐 [AUTH-ERROR] → unrecognized, falling back to raw message")
        #endif
        return "Something went wrong. Please try again."
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidCredentials
    case weakPassword
    case emailConfirmationRequired
    case notConfigured
    case notAuthenticated
    case networkError
    case supabaseError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidCredentials:
            return "Invalid email or password"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .emailConfirmationRequired:
            return "Please check your email to confirm your account"
        case .notConfigured:
            return "Authentication service is not configured"
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .networkError:
            return "Network error. Please check your connection."
        case .supabaseError(let error):
            return error.localizedDescription
        }
    }
}
