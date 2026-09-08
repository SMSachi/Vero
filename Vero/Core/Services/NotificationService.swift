//
//  NotificationService.swift
//  WellPattern Health
//
//  Schedules and manages local user notifications.
//  Permission is requested contextually — never at app launch.
//

import Foundation
import UserNotifications

// MARK: - Reminder Type

enum ReminderType: String, CaseIterable {
    case workout = "workout_reminder"
    case hydration = "hydration_reminder"
    case sleep = "sleep_reminder"
    case nutrition = "nutrition_reminder"

    var defaultHour: Int {
        switch self {
        case .workout: return 17     // 5 PM
        case .hydration: return 12   // noon
        case .sleep: return 21       // 9 PM
        case .nutrition: return 13   // 1 PM (after lunch)
        }
    }

    var defaultMinute: Int { 0 }

    var title: String {
        switch self {
        case .workout: return "Time to train"
        case .hydration: return "Stay hydrated"
        case .sleep: return "Wind down for sleep"
        case .nutrition: return "Log your nutrition"
        }
    }

    var body: String {
        switch self {
        case .workout: return "Log a workout to keep your streak going."
        case .hydration: return "Have you hit your water goal today?"
        case .sleep: return "Aim for 7–9 hours. Consistency improves recovery."
        case .nutrition: return "Log your calories and macros for today."
        }
    }
}

// MARK: - Notification Service

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshStatus() }
    }

    // MARK: - Status

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Permission

    /// Request permission contextually — call when user first enables a reminder.
    @discardableResult
    func requestPermissionIfNeeded() async -> Bool {
        guard authorizationStatus == .notDetermined else {
            await refreshStatus()
            return isAuthorized
        }
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
            return granted
        } catch {
            print("🔔 NotificationService: Permission request failed — \(error)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Enable or disable a daily reminder at the type's default time.
    func setReminder(_ type: ReminderType, enabled: Bool) async {
        if enabled {
            let granted = await requestPermissionIfNeeded()
            guard granted else { return }
            scheduleDaily(type)
        } else {
            cancel(type)
        }
    }

    private func scheduleDaily(_ type: ReminderType) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default

        var components = DateComponents()
        components.hour = type.defaultHour
        components.minute = type.defaultMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: type.rawValue, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("🔔 NotificationService: Failed to schedule \(type.rawValue) — \(error)")
            } else {
                print("🔔 NotificationService: Scheduled \(type.rawValue) at \(type.defaultHour):00")
            }
        }
    }

    private func cancel(_ type: ReminderType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [type.rawValue])
        print("🔔 NotificationService: Cancelled \(type.rawValue)")
    }

    /// Cancel all app notifications (e.g., on sign-out).
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
