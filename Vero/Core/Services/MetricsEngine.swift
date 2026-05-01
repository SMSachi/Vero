//
//  MetricsEngine.swift
//  Vero
//
//  SINGLE SOURCE OF TRUTH for all health metric computations.
//
//  RULE: If the same metric appears on Dashboard AND Trends, it MUST be computed
//  by calling a function in this file. No metric math lives elsewhere.
//
//  CANONICAL DEFINITIONS
//  ─────────────────────
//  "This calendar week"   = Mon 00:00 of the current ISO week → now  (Dashboard)
//  "Rolling N days"       = startOfDay(today − N days) → now          (Trends)
//  "Today"                = startOfDay(now) → endOfDay(now)
//
//  Aggregation rules:
//  • Workouts this week   = count of sessions whose startDate is ≥ calendarWeekStart
//  • Hydration today      = waterIntakeMl of TODAY's DailyContext ÷ 1000  (0 if missing)
//  • Hydration average    = mean of days-with-entries only (liters)
//  • Sleep today          = sleepHours of TODAY's DailyContext (nil if missing)
//  • Weight current       = today's weightKg if present, else last recorded
//  • Weight entries       = sorted by DATE ascending, never by value
//  • Weeks in period      = Double(days) / 7.0  (floating point — no integer truncation)
//

import Foundation
import SwiftUI

@MainActor
final class MetricsEngine {

    // MARK: - Singleton

    static let shared = MetricsEngine()
    private init() {}

    // MARK: - Dependencies

    private let persistence = PersistenceService.shared
    private var units: UnitPreferences { .shared }
    private let cal = Calendar.current

    // MARK: - Canonical Date Windows

    /// Start of the current ISO calendar week (locale-aware; Monday 00:00 in most regions).
    /// This is the canonical "this week" boundary used by the Dashboard and WeeklyTracker.
    var calendarWeekStart: Date {
        cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!
    }

    /// Returns midnight at the start of the day that was `days` days ago.
    /// All rolling Trends windows MUST use this as their lower bound.
    func rollingWindowStart(days: Int) -> Date {
        let offset = cal.date(byAdding: .day, value: -days, to: .now)!
        return cal.startOfDay(for: offset)
    }

    // MARK: - Workouts

    /// All workout sessions that started in the current calendar week.
    func workoutsThisCalendarWeek() -> [Workout] {
        persistence.fetchWorkouts(from: calendarWeekStart, to: .now)
    }

    /// Count of workouts in the current calendar week.
    func workoutCountThisCalendarWeek() -> Int {
        persistence.countWorkoutsThisWeek()
    }

    /// Set of weekday indices (0 = Mon … 6 = Sun) that contain ≥1 workout this calendar week.
    /// Drives the WeeklyTracker dots — each dot is lit when its index is in this set.
    func workoutDaysThisCalendarWeek() -> Set<Int> {
        Set(workoutsThisCalendarWeek().map { weekdayIndex(for: $0.startDate) })
    }

    /// All workouts in the rolling N-day window [startOfDay(today − days) … now].
    func workouts(rollingDays days: Int) -> [Workout] {
        persistence.fetchWorkouts(from: rollingWindowStart(days: days), to: .now)
    }

    // MARK: - Daily Contexts

    /// Today's DailyContext (nil if none has been created today).
    func todayContext() -> DailyContext? {
        persistence.fetchTodayDailyContext()
    }

    /// Returns contexts whose **calendar day** falls within [rollingWindowStart … today].
    /// Uses startOfDay comparison so a context logged at 2 pm is included for its full day.
    func contexts(rollingDays days: Int) -> [DailyContext] {
        let windowStart = rollingWindowStart(days: days)
        let all = persistence.fetchRecentDailyContexts(limit: days + 14)
        return all.filter { cal.startOfDay(for: $0.date) >= windowStart }
    }

    // MARK: - Hydration

    /// Today's total water intake in liters. Returns 0.0 when nothing has been logged today.
    func hydrationToday() -> Double {
        Double(todayContext()?.waterIntakeMl ?? 0) / 1000.0
    }

    /// Rolling N-day average daily intake in liters.
    /// Only days that have a logged entry contribute to the average (days with 0 are excluded).
    /// Returns nil when no data exists in the window.
    func hydrationAverage(rollingDays days: Int) -> Double? {
        let entries = contexts(rollingDays: days)
            .compactMap { $0.waterIntakeMl }
            .filter { $0 > 0 }
        guard !entries.isEmpty else { return nil }
        return Double(entries.reduce(0, +)) / Double(entries.count) / 1000.0
    }

    // MARK: - Sleep

    /// Today's sleep hours, or nil if not yet logged today.
    func sleepToday() -> Double? {
        let h = todayContext()?.sleepHours ?? 0
        return h > 0 ? h : nil
    }

    /// Rolling N-day average sleep hours (only days with entries contribute).
    /// Returns nil when no data exists.
    func sleepAverage(rollingDays days: Int) -> Double? {
        let entries = contexts(rollingDays: days)
            .map { $0.sleepHours }
            .filter { $0 > 0 }
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0, +) / Double(entries.count)
    }

    // MARK: - Weight

    /// Most recent weight in kg.
    /// Prefers today's context. Falls back to the last recorded entry across all days.
    func weightCurrentKg() -> Double? {
        if let kg = todayContext()?.weightKg, kg > 0 { return kg }
        return persistence.fetchLastRecordedWeight()
    }

    /// Weight entries in the rolling N-day window, **sorted by date ascending**.
    /// NEVER sorted by value — `last` is always the most recent measurement.
    func weightEntries(rollingDays days: Int) -> [(date: Date, kg: Double)] {
        contexts(rollingDays: days)
            .compactMap { ctx -> (Date, Double)? in
                guard let kg = ctx.weightKg, kg > 0 else { return nil }
                return (ctx.date, kg)
            }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: - Derived Metrics

    /// Current workout streak (consecutive calendar days with ≥1 workout).
    func currentStreak() -> Int {
        persistence.calculateCurrentStreak()
    }

    /// Net weight change over the past 7 days (current − 7-days-ago), in kg.
    /// Returns nil when insufficient data exists.
    func weeklyWeightDeltaKg() -> Double? {
        persistence.calculateWeeklyWeightDelta()
    }

    // MARK: - Utility

    /// Floating-point weeks in a period. Use this everywhere — never integer division.
    /// Example: 30 days → 4.286 weeks, not 4.
    func weeksInPeriod(_ days: Int) -> Double {
        max(1.0, Double(days) / 7.0)
    }

    /// Converts Calendar.weekday (1 = Sun, 2 = Mon … 7 = Sat) to 0 = Mon … 6 = Sun.
    func weekdayIndex(for date: Date) -> Int {
        (cal.component(.weekday, from: date) + 5) % 7
    }

    // MARK: - Debug Audit

    /// Prints a structured audit log of every key metric and its source.
    /// Call from any ViewModel to compare dashboard vs trends values side-by-side.
    /// Compiled out entirely in Release builds.
    func auditLog(screen: String, rollingDays days: Int = 7) {
        #if DEBUG
        let today = Date()
        let todayCtx = todayContext()
        let weekWorkouts = workoutsThisCalendarWeek()
        let rollingWorkouts = workouts(rollingDays: days)
        let rollingCtxs = contexts(rollingDays: days)

        print("""

        🔍 ═══════════════════════════════════════════════════════
        🔍 METRICS AUDIT  ·  \(screen)
        🔍 Timestamp:  \(today)
        🔍 ─────────────────────────────────────────────────────────
        🔍 WORKOUTS
        🔍   Calendar week  [\(calendarWeekStart) → now]
        🔍     Count:   \(weekWorkouts.count)
        🔍     Days:    \(workoutDaysThisCalendarWeek())
        🔍     Streak:  \(currentStreak())d
        🔍   Rolling \(days)d  [\(rollingWindowStart(days: days)) → now]
        🔍     Count:   \(rollingWorkouts.count)
        🔍     /week:   \(String(format: "%.2f", Double(rollingWorkouts.count) / weeksInPeriod(days)))
        🔍 ─────────────────────────────────────────────────────────
        🔍 HYDRATION
        🔍   Source:  today DailyContext → waterIntakeMl
        🔍   Raw ml:  \(todayCtx?.waterIntakeMl ?? 0)
        🔍   Liters:  \(String(format: "%.2f", hydrationToday()))L
        🔍   \(days)d avg:  \(hydrationAverage(rollingDays: days).map { String(format: "%.2fL", $0) } ?? "nil")
        🔍   Contexts in window:  \(rollingCtxs.filter { ($0.waterIntakeMl ?? 0) > 0 }.count) days with entries
        🔍 ─────────────────────────────────────────────────────────
        🔍 SLEEP
        🔍   Source:  today DailyContext → sleepHours
        🔍   Today:   \(todayCtx.map { $0.sleepHours > 0 ? String(format: "%.1fh", $0.sleepHours) : "0 (not logged)" } ?? "nil")
        🔍   \(days)d avg:  \(sleepAverage(rollingDays: days).map { String(format: "%.1fh", $0) } ?? "nil")
        🔍   Contexts in window:  \(rollingCtxs.filter { $0.sleepHours > 0 }.count) days with entries
        🔍 ─────────────────────────────────────────────────────────
        🔍 WEIGHT  (stored in kg, displayed in \(units.weightUnit))
        🔍   Source:  today DailyContext → weightKg, fallback fetchLastRecordedWeight()
        🔍   Today context kg:  \(todayCtx?.weightKg.map { $0 > 0 ? String(format: "%.2f", $0) : "0 (not logged)" } ?? "nil")
        🔍   Current kg:        \(weightCurrentKg().map { String(format: "%.2f", $0) } ?? "nil")
        🔍   7d delta kg:       \(weeklyWeightDeltaKg().map { String(format: "%+.2f", $0) } ?? "nil")
        🔍   Entries in \(days)d window:  \(weightEntries(rollingDays: days).count)
        🔍 ─────────────────────────────────────────────────────────
        🔍 WINDOW COVERAGE
        🔍   Rolling \(days)d contexts total:  \(rollingCtxs.count)
        🔍   Fetch limit used:  \(days + 14)
        🔍 ═══════════════════════════════════════════════════════
        """)
        #endif
    }
}
