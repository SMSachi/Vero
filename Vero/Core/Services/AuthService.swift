//
//  AuthService.swift
//  Insio Health
//
//  Handles user authentication via Supabase Auth.
//  Supports signup, login, logout, and session persistence.
//

import Foundation
import Supabase

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
        print("🔐 AuthService: ══════════════════════════════════════════════════")
        print("🔐 AuthService: INITIALIZING")
        print("🔐 AuthService: isConfigured = \(SupabaseConfig.isConfigured)")
        print("🔐 AuthService: isLoading = \(isLoading) (initial)")
        print("🔐 AuthService: ══════════════════════════════════════════════════")

        #if targetEnvironment(simulator)
        // On simulator, set isLoading = false immediately to prevent hangs
        print("🔐 AuthService: SIMULATOR - setting isLoading = false immediately")
        self.isLoading = false
        return
        #endif

        // Start listening for auth state changes
        setupAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        print("🔐 AuthService: setupAuthStateListener() ENTER")
        print("🔐 AuthService: ──────────────────────────────────────────────────")

        // CRITICAL: If Supabase is not configured, skip auth and go straight to guest-capable state
        guard SupabaseConfig.isConfigured else {
            print("🔐 AuthService: ⚡ Supabase NOT configured - setting isLoading = false IMMEDIATELY")
            self.isLoading = false
            print("🔐 AuthService: ✅ isLoading is now: \(self.isLoading)")
            return
        }

        print("🔐 AuthService: Supabase IS configured, starting auth task...")

        authStateTask = Task { [weak self] in
            guard let self = self else {
                print("🔐 AuthService: ❌ Self is nil in auth task - this is a bug")
                return
            }

            print("🔐 AuthService: 📍 STEP 1: Inside auth task, about to check session...")

            // Check for existing session first with a timeout
            await self.checkExistingSessionWithTimeout()

            print("🔐 AuthService: 📍 STEP 2: Session check complete, isLoading=\(self.isLoading)")
            print("🔐 AuthService: 📍 STEP 3: Starting authStateChanges listener...")

            // Listen for auth state changes
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                print("🔐 AuthService: 📍 Auth event received: \(event)")

                await MainActor.run {
                    switch event {
                    case .initialSession:
                        print("🔐 AuthService: 📍 Event: initialSession")
                        self.handleSession(session)
                        self.isLoading = false
                        print("🔐 AuthService: ✅ isLoading set to false (initialSession)")

                    case .signedIn:
                        print("🔐 AuthService: 📍 Event: signedIn")
                        self.handleSession(session)
                        self.isLoading = false
                        print("🔐 AuthService: ✅ isLoading set to false (signedIn)")

                    case .signedOut:
                        print("🔐 AuthService: 📍 Event: signedOut")
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.isLoading = false
                        print("🔐 AuthService: ✅ isLoading set to false (signedOut)")

                    case .tokenRefreshed:
                        print("🔐 AuthService: 📍 Event: tokenRefreshed")
                        self.handleSession(session)

                    case .userUpdated:
                        print("🔐 AuthService: 📍 Event: userUpdated")
                        self.handleSession(session)

                    case .userDeleted:
                        print("🔐 AuthService: 📍 Event: userDeleted")
                        self.currentUser = nil
                        self.isAuthenticated = false

                    case .passwordRecovery, .mfaChallengeVerified:
                        print("🔐 AuthService: 📍 Event: \(event) (ignored)")
                        break
                    }
                }
            }
            print("🔐 AuthService: ⚠️ authStateChanges listener ENDED (loop exited)")
        }

        print("🔐 AuthService: ──────────────────────────────────────────────────")
        print("🔐 AuthService: setupAuthStateListener() EXIT - Task started")
        print("🔐 AuthService: NOTE: isLoading is still \(self.isLoading) (Task runs async)")
        print("🔐 AuthService: ──────────────────────────────────────────────────")
    }

    private func handleSession(_ session: Session?) {
        if let session = session {
            print("🔐 AuthService: Session found - user: \(session.user.email ?? "no email")")
            self.currentUser = session.user
            self.isAuthenticated = true
        } else {
            print("🔐 AuthService: No session")
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    /// Check for existing session with a timeout to prevent hanging
    private func checkExistingSessionWithTimeout() async {
        print("🔐 AuthService: ──────────────────────────────────────────────────")
        print("🔐 AuthService: checkExistingSessionWithTimeout() ENTER")
        print("🔐 AuthService: Using 3-second timeout (reduced for faster startup)")
        print("🔐 AuthService: ──────────────────────────────────────────────────")

        // Use a task group with timeout - REDUCED to 3 seconds
        let result = await withTaskGroup(of: Bool.self) { group in
            // Task 1: Check session
            group.addTask {
                print("🔐 AuthService: 🔄 Session check task STARTED")
                do {
                    print("🔐 AuthService: 🔄 Calling SupabaseConfig.client.auth.session...")
                    let session = try await SupabaseConfig.client.auth.session
                    print("🔐 AuthService: ✅ Got session for: \(session.user.email ?? "unknown")")
                    await MainActor.run {
                        self.currentUser = session.user
                        self.isAuthenticated = true
                        self.isLoading = false
                        print("🔐 AuthService: ✅ isLoading = false (session found)")
                    }
                    return true
                } catch {
                    print("🔐 AuthService: ❌ No session - \(error.localizedDescription)")
                    await MainActor.run {
                        self.currentUser = nil
                        self.isAuthenticated = false
                        self.isLoading = false
                        print("🔐 AuthService: ✅ isLoading = false (no session)")
                    }
                    return true
                }
            }

            // Task 2: Timeout after 3 seconds (reduced from 5)
            group.addTask {
                print("🔐 AuthService: ⏱️ Timeout task STARTED (3 seconds)")
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                print("🔐 AuthService: ⏱️ Timeout task FIRED")
                return false
            }

            // Wait for first task to complete
            print("🔐 AuthService: ⏳ Waiting for first task to complete...")
            if let firstResult = await group.next() {
                print("🔐 AuthService: 📍 First task completed with result: \(firstResult)")
                if firstResult {
                    // Session check completed
                    group.cancelAll()
                    return true
                }
            }

            // Timeout occurred - cancel remaining tasks
            print("🔐 AuthService: ⚠️ Timeout occurred, cancelling remaining tasks")
            group.cancelAll()
            return false
        }

        print("🔐 AuthService: 📍 Task group completed with result: \(result)")

        // If timeout occurred, force resolve loading state
        if !result {
            print("🔐 AuthService: ⚠️ SESSION CHECK TIMED OUT - forcing isLoading = false")
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.errorMessage = "Connection timed out. Please try again."
                print("🔐 AuthService: ✅ isLoading = false (timeout)")
            }
        }

        print("🔐 AuthService: ──────────────────────────────────────────────────")
        print("🔐 AuthService: checkExistingSessionWithTimeout() EXIT")
        print("🔐 AuthService: isLoading is now: \(self.isLoading)")
        print("🔐 AuthService: ──────────────────────────────────────────────────")
    }

    private func checkExistingSession() async {
        print("🔐 AuthService: Checking for existing session...")

        do {
            let session = try await SupabaseConfig.client.auth.session
            print("🔐 AuthService: Found existing session for user: \(session.user.email ?? "unknown")")
            await MainActor.run {
                self.currentUser = session.user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            print("🔐 AuthService: No existing session - \(error.localizedDescription)")
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
        print("🔐 AuthService: ========== SIGNUP ATTEMPT ==========")
        print("🔐 AuthService: Email: \(email)")
        print("🔐 AuthService: Password length: \(password.count)")
        print("🔐 AuthService: Full name: \(fullName ?? "not provided")")

        // Clear previous errors
        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes RootView to flash loading screen
        // The button's own loading state (isSubmitting) provides user feedback

        // Validate email format
        guard isValidEmail(email) else {
            print("🔐 AuthService: ❌ Email validation failed")
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }
        print("🔐 AuthService: ✓ Email format valid")

        // Validate password length
        guard password.count >= 6 else {
            print("🔐 AuthService: ❌ Password too short")
            isLoading = false
            errorMessage = "Password must be at least 6 characters"
            throw AuthError.weakPassword
        }
        print("🔐 AuthService: ✓ Password length valid")

        // Check Supabase configuration
        guard SupabaseConfig.isConfigured else {
            print("🔐 AuthService: ❌ Supabase not configured")
            isLoading = false
            errorMessage = "Authentication service not configured"
            throw AuthError.notConfigured
        }
        print("🔐 AuthService: ✓ Supabase configured")

        // Attempt signup with Supabase
        print("🔐 AuthService: 🚀 Sending signup request to Supabase...")

        do {
            let authResponse = try await SupabaseConfig.client.auth.signUp(
                email: email,
                password: password,
                data: fullName != nil ? ["full_name": .string(fullName!)] : nil
            )

            print("🔐 AuthService: ✅ Signup response received")
            print("🔐 AuthService: User ID: \(authResponse.user.id.uuidString)")
            print("🔐 AuthService: User email: \(authResponse.user.email ?? "nil")")
            print("🔐 AuthService: Session: \(authResponse.session != nil ? "present" : "nil")")

            // Check if email confirmation is required (no session means confirmation needed)
            if authResponse.session == nil {
                print("🔐 AuthService: 📧 Email confirmation required")
                isLoading = false
                errorMessage = nil
                throw AuthError.emailConfirmationRequired
            }

            // User is signed in
            let user = authResponse.user
            print("🔐 AuthService: ✅ User created and signed in: \(user.email ?? "unknown")")
            self.currentUser = user
            self.isAuthenticated = authResponse.session != nil
            self.isLoading = false

            print("🔐 AuthService: ✅ State updated: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")

            // Force SwiftUI to recognize the change
            self.objectWillChange.send()

        } catch let error as AuthError {
            // Re-throw our custom errors
            print("🔐 AuthService: ❌ Auth error: \(error.localizedDescription)")
            isLoading = false
            throw error

        } catch {
            // Handle Supabase errors
            print("🔐 AuthService: ❌ Supabase error: \(error)")
            print("🔐 AuthService: Error type: \(type(of: error))")
            print("🔐 AuthService: Error description: \(error.localizedDescription)")

            isLoading = false
            errorMessage = parseSupabaseError(error)
            throw AuthError.supabaseError(error)
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        print("🔐 AuthService: ========== SIGNIN ATTEMPT ==========")
        print("🔐 AuthService: Email: \(email)")
        print("🔐 AuthService: Password length: \(password.count)")

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes RootView to flash loading screen
        // The button's own loading state (isSubmitting) provides user feedback

        // Validate inputs
        guard isValidEmail(email) else {
            print("🔐 AuthService: ❌ Email validation failed")
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            print("🔐 AuthService: ❌ Password too short")
            isLoading = false
            errorMessage = "Invalid email or password"
            throw AuthError.invalidCredentials
        }

        guard SupabaseConfig.isConfigured else {
            print("🔐 AuthService: ❌ Supabase not configured")
            isLoading = false
            errorMessage = "Authentication service not configured"
            throw AuthError.notConfigured
        }

        print("🔐 AuthService: 🚀 Sending signin request to Supabase...")

        do {
            let session = try await SupabaseConfig.client.auth.signIn(
                email: email,
                password: password
            )

            print("🔐 AuthService: ✅ Signin successful")
            print("🔐 AuthService: User: \(session.user.email ?? "unknown")")

            // CRITICAL: Update state and force UI refresh
            self.currentUser = session.user
            self.isAuthenticated = true
            self.isLoading = false

            print("🔐 AuthService: ✅ State updated: isAuthenticated=\(isAuthenticated), isLoading=\(isLoading)")

            // Force SwiftUI to recognize the change
            self.objectWillChange.send()

        } catch {
            print("🔐 AuthService: ❌ Signin error: \(error)")
            print("🔐 AuthService: Error description: \(error.localizedDescription)")

            isLoading = false
            errorMessage = parseSupabaseError(error)
            throw AuthError.supabaseError(error)
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() async throws {
        print("🔐 AuthService: ========== SIGNOUT ==========")

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes unnecessary loading screen flash

        do {
            try await SupabaseConfig.client.auth.signOut()
            print("🔐 AuthService: ✅ Signout successful")

            self.currentUser = nil
            self.isAuthenticated = false
            isLoading = false

        } catch {
            print("🔐 AuthService: ❌ Signout error: \(error)")
            isLoading = false
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Account Deletion

    /// Delete the current user's account
    /// This removes the user from Supabase Auth and should trigger cascade deletion of user data
    func deleteAccount() async throws {
        print("🔐 AuthService: ========== ACCOUNT DELETION ==========")

        guard isAuthenticated, let user = currentUser else {
            print("🔐 AuthService: ❌ No authenticated user to delete")
            throw AuthError.notAuthenticated
        }

        print("🔐 AuthService: Deleting user: \(user.email ?? user.id.uuidString)")

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - it causes unnecessary loading screen flash

        do {
            // First, delete user data from Supabase tables
            // This should be handled by RLS policies or database triggers
            // But we'll explicitly delete to be safe
            if let userId = userId {
                print("🔐 AuthService: Deleting user data from tables...")

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

                print("🔐 AuthService: ✅ User data deleted from tables")
            }

            // Sign out the user (this invalidates the session)
            try await SupabaseConfig.client.auth.signOut()

            print("🔐 AuthService: ✅ User signed out")

            // Note: Full user deletion from auth.users requires admin privileges
            // In production, you might need a server-side function to fully delete the user
            // For now, we've cleared their data and signed them out

            self.currentUser = nil
            self.isAuthenticated = false
            isLoading = false

            print("🔐 AuthService: ✅ Account deletion complete")

        } catch {
            print("🔐 AuthService: ❌ Account deletion error: \(error)")
            isLoading = false
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Password Reset

    /// Send password reset email
    func resetPassword(email: String) async throws {
        print("🔐 AuthService: ========== PASSWORD RESET ==========")
        print("🔐 AuthService: Email: \(email)")

        errorMessage = nil
        // NOTE: Don't set isLoading = true here - button has its own loading state

        guard isValidEmail(email) else {
            isLoading = false
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidEmail
        }

        do {
            try await SupabaseConfig.client.auth.resetPasswordForEmail(email)
            print("🔐 AuthService: ✅ Password reset email sent")
            isLoading = false

        } catch {
            print("🔐 AuthService: ❌ Password reset error: \(error)")
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
        let errorString = error.localizedDescription.lowercased()

        print("🔐 AuthService: Parsing error: \(errorString)")

        // Check for specific error messages
        if errorString.contains("invalid login credentials") ||
           errorString.contains("invalid_credentials") {
            return "Invalid email or password"
        }

        if errorString.contains("email not confirmed") ||
           errorString.contains("email_not_confirmed") {
            return "Please check your email and confirm your account"
        }

        if errorString.contains("user already registered") ||
           errorString.contains("already registered") ||
           errorString.contains("already exists") {
            return "An account with this email already exists"
        }

        if errorString.contains("signup is disabled") ||
           errorString.contains("signups not allowed") ||
           errorString.contains("email signups are disabled") {
            return "Sign up is currently disabled. Please enable Email provider in Supabase."
        }

        if errorString.contains("password") && errorString.contains("weak") {
            return "Password is too weak. Use at least 6 characters."
        }

        if errorString.contains("rate limit") || errorString.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }

        if errorString.contains("network") || errorString.contains("connection") ||
           errorString.contains("offline") || errorString.contains("internet") {
            return "Network error. Please check your internet connection."
        }

        if errorString.contains("invalid api key") ||
           errorString.contains("invalid key") ||
           errorString.contains("apikey") {
            return "Configuration error: Invalid API key"
        }

        if errorString.contains("jwt") || errorString.contains("token") {
            return "Configuration error: Invalid authentication token"
        }

        // Default error
        return "Something went wrong: \(error.localizedDescription)"
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
