//
//  MainTabView.swift
//  Insio Health
//
//  Root tab navigation with refined design
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .home
    @State private var showDebugAlert = false  // DEBUG: Alert to prove view appeared

    enum Tab: Int, CaseIterable {
        case home
        case workouts
        case trends
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .workouts: return "Workouts"
            case .trends: return "Trends"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house"
            case .workouts: return "figure.run"
            case .trends: return "chart.line.uptrend.xyaxis"
            case .profile: return "person"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .workouts: return "figure.run"
            case .trends: return "chart.line.uptrend.xyaxis"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        // DEBUG: Log every body evaluation
        let _ = print("📱 MainTabView: body EVALUATING - START")

        ZStack(alignment: .bottom) {
            // Content
            let _ = print("📱 MainTabView: Creating TabView...")
            TabView(selection: $selectedTab) {
                let _ = print("📱 MainTabView: Creating HomeDashboardView...")
                HomeDashboardView()
                    .tag(Tab.home)

                let _ = print("📱 MainTabView: Creating WorkoutsListView...")
                WorkoutsListView()
                    .tag(Tab.workouts)

                let _ = print("📱 MainTabView: Creating TrendsView...")
                TrendsView()
                    .tag(Tab.trends)

                let _ = print("📱 MainTabView: Creating ProfileView...")
                ProfileView()
                    .tag(Tab.profile)

                let _ = print("📱 MainTabView: All tab views created")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        // Post-workout check-in modal (full screen)
        .fullScreenCover(isPresented: $appState.showPostWorkoutCheckIn) {
            if let workout = appState.checkInWorkout {
                PostWorkoutCheckInView(workout: workout)
            }
        }
        // Next-day check-in modal (full screen)
        .fullScreenCover(isPresented: $appState.showNextDayCheckIn) {
            NextDayCheckInView()
        }
        .onAppear {
            print("📱 ══════════════════════════════════════════════════")
            print("📱 MainTabView: APPEARED")
            print("📱 MainTabView: selectedTab = \(selectedTab.rawValue)")
            print("📱 MainTabView: showPostWorkoutCheckIn = \(appState.showPostWorkoutCheckIn)")
            print("📱 MainTabView: showNextDayCheckIn = \(appState.showNextDayCheckIn)")
            print("📱 ══════════════════════════════════════════════════")
            // Check for pending check-ins when app first appears
            appState.checkForPendingCheckIns()

            // DEBUG: Show alert to PROVE this view appeared
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showDebugAlert = true
            }
        }
        // DEBUG ALERT - If you see this, MainTabView IS visible
        .alert("SUCCESS!", isPresented: $showDebugAlert) {
            Button("OK - I see the main app!") {
                showDebugAlert = false
            }
        } message: {
            Text("MainTabView appeared! If you see this alert, the routing worked and you should see the home screen behind this alert.")
        }
        .onChange(of: appState.showPostWorkoutCheckIn) { _, show in
            print("📱 MainTabView: showPostWorkoutCheckIn changed to \(show)")
        }
        .onChange(of: appState.showNextDayCheckIn) { _, show in
            print("📱 MainTabView: showNextDayCheckIn changed to \(show)")
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Check for pending check-ins when app becomes active (from background)
            if newPhase == .active && oldPhase != .active {
                print("📱 MainTabView: App became active - checking for pending check-ins")
                appState.checkForPendingCheckIns()
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.rawValue) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(AppAnimation.springQuick) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
        .background(
            Rectangle()
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarItem: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppColors.navy : AppColors.textTertiary)
                    .frame(height: 26)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? AppColors.navy : AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabBarButtonStyle())
    }
}

struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(AppAnimation.springSnappy, value: configuration.isPressed)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
        .environmentObject(SupabaseSyncService.shared)
}
