# Auth Transition Fix - SAVE THIS

## Problem
After successful sign-in, the UI stays stuck on "Signing in..." screen even though:
- AuthService.isAuthenticated = true
- MainTabView body evaluates
- But MainTabView never appears (onAppear doesn't fire)

## Root Cause
SwiftUI's reactive observation with @EnvironmentObject and @StateObject doesn't reliably trigger view replacement when using singletons. The view body evaluates but SwiftUI doesn't mount the new view.

## The Fix

### 1. Use NotificationCenter to force the transition

In `LoginView.swift`, after successful sign-in, post a notification:
```swift
// After signIn succeeds:
NotificationCenter.default.post(name: .authStateDidChange, object: nil)
```

### 2. Define the notification name in `InsioApp.swift`:
```swift
extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}
```

### 3. AppRootView structure that works:
```swift
struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    @State private var showMainApp = false

    var body: some View {
        ZStack {
            if showMainApp {
                MainTabView()
                    .transition(.move(edge: .trailing))
                    .onAppear {
                        print("🧭 ✅ MainTabView APPEARED")
                        appState.onAuthenticationSuccess()
                    }
            } else {
                authFlow
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showMainApp)
        .onAppear {
            showMainApp = authService.isAuthenticated
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            withAnimation {
                showMainApp = true
            }
        }
    }

    @ViewBuilder
    private var authFlow: some View {
        if authService.isLoading {
            SplashLoadingView()
        } else if !appState.hasSeenOnboarding {
            OnboardingContainerView()
        } else {
            AuthContainerView()
        }
    }
}
```

## Key Points
1. Use `@State private var showMainApp` - local state that SwiftUI definitely observes
2. Use `NotificationCenter` to bypass SwiftUI's reactive system
3. Use `ZStack` with separate if branches (not if-else chain in Group)
4. Use `withAnimation` when setting `showMainApp = true`
5. Use `@ObservedObject` (not `@StateObject`) for singletons in InsioApp

## Files Changed
- `/Vero/App/InsioApp.swift` - AppRootView + Notification.Name extension
- `/Vero/Features/Auth/LoginView.swift` - Post notification after sign-in

## If It Breaks Again
1. Check that LoginView posts `.authStateDidChange` notification after sign-in
2. Check that AppRootView listens for the notification with `.onReceive`
3. Check that `showMainApp` is a `@State` variable
4. Ensure using ZStack, not Group
5. Clean build: Cmd+Shift+K, then Cmd+R
