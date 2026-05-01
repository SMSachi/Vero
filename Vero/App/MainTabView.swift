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
        ZStack(alignment: .bottom) {
            // Tab content — all four views live simultaneously so state (ViewModels,
            // scroll position) persists across tab switches. No UIPageViewController,
            // no gesture recognizer conflicts.
            ZStack {
                HomeDashboardView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)

                WorkoutsListView()
                    .opacity(selectedTab == .workouts ? 1 : 0)
                    .allowsHitTesting(selectedTab == .workouts)

                TrendsView()
                    .opacity(selectedTab == .trends ? 1 : 0)
                    .allowsHitTesting(selectedTab == .trends)

                ProfileView()
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .background(AppColors.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        // Post-workout check-in: guard against empty cover when checkInWorkout is nil
        .fullScreenCover(
            isPresented: Binding(
                get: { appState.showPostWorkoutCheckIn && appState.checkInWorkout != nil },
                set: { if !$0 { appState.showPostWorkoutCheckIn = false } }
            )
        ) {
            if let workout = appState.checkInWorkout {
                PostWorkoutCheckInView(workout: workout)
            }
        }
        // Next-day check-in modal (full screen)
        .fullScreenCover(isPresented: $appState.showNextDayCheckIn) {
            NextDayCheckInView()
        }
        .onAppear {
            #if DEBUG
            print("📱 MainTabView: onAppear — tab container ready")
            #endif
            appState.checkForPendingCheckIns()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                appState.checkForPendingCheckIns()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            #if DEBUG
            print("📱 MainTabView: tab switched to \(newTab.title)")
            #endif
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
                    #if DEBUG
                    print("📱 TabBar: tapped \(tab.title)")
                    #endif
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
