# RELEASE CHECKLIST — Insio Health
Last updated: 2026-08-30 (Pass 2)

Status labels used throughout:
- VERIFIED — executed and confirmed correct
- CODE AUDITED — inspected source only; runtime behavior assumed correct
- RUNTIME TEST REQUIRED — cannot be confirmed without a physical device or running app
- BLOCKED — requires external action before this item can be completed
- FAILED — known to be broken

---

## 1. BUILD

- CODE AUDITED / BLOCKED — xcodebuild CLI cannot parse Insio.xcodeproj (Xcode 16 PBXFileSystemSynchronizedRootGroup format). Build MUST be performed from Xcode GUI.
- CODE AUDITED — `swiftc -parse` on all 80+ Swift files: zero syntax errors (both passes)
- CODE AUDITED — DerivedData present, confirming the project built successfully in Xcode GUI at some prior point
- BLOCKED — App icon PNG files missing (3 files); archive will fail without them
- RUNTIME TEST REQUIRED — Product → Archive in Xcode must succeed with zero errors before TestFlight upload

**Next human action:** In Xcode 16: open Insio.xcodeproj → select "Any iOS Device (arm64)" → Product → Archive. Fix any compiler errors that appear.

---

## 2. AUTHENTICATION & USER ISOLATION

- CODE AUDITED — Auth routing: direct `if authService.isAuthenticated` check, no ZStack/id trick
- CODE AUDITED — Account switch detection: compares `currentUserId` vs `lastSignedInUserId`
- CODE AUDITED — `signOut()` clears: SwiftData records, NutritionService, UserGoalService, WorkoutMonitor, sync state, `lastSignedInUserId`
- CODE AUDITED — `signOut()` does NOT call `clearPremiumStatus()` — trial state intentionally preserved across logout/login
- CODE AUDITED — Onboarding guard: `!appState.hasSeenOnboarding` prevents main app access
- RUNTIME TEST REQUIRED — Sign in as User A → log data → sign out → sign in as User B → confirm empty state
- RUNTIME TEST REQUIRED — Force-quit and relaunch → confirm auth state persists correctly

---

## 3. HEALTHKIT

- CODE AUDITED — Authorization: `requestAuthorization(toShare: [], read: readTypes)` — zero write types
- CODE AUDITED — No `healthStore.save()` call exists anywhere (confirmed via full codebase grep)
- CODE AUDITED — Metrics read: heartRate, restingHeartRate, HRV, sleep, activeEnergy, distance, dietaryWater, dietaryCalories, dietaryCarbs, dietaryProtein
- CODE AUDITED — Simulator detection: HealthKit bypassed on simulator
- CODE AUDITED — Entitlements: HealthKit + background delivery declared
- CODE AUDITED — PrivacyInfo.xcprivacy: NSPrivacyTracking = false; Health + Fitness + UserID for AppFunctionality

**Real-device test checklist (RUNTIME TEST REQUIRED for each):**
- [ ] Authorization prompt appears on first launch
- [ ] After "Allow All" → home dashboard shows real data within 30 seconds
- [ ] After "Don't Allow" → dashboard shows "—" / "No data" (not 0) for all metrics
- [ ] Partial permissions (e.g., sleep denied, HR allowed) → denied metrics show "—" not 0
- [ ] No Apple Watch paired → HR/HRV metrics show "—" not fabricated values
- [ ] App relaunch → data persists without re-requesting authorization
- [ ] Dashboard pull-to-refresh → data updates without error

---

## 4. DATA INTEGRITY — NO FABRICATED HEALTH DATA

- VERIFIED (code) — Sleep fallback `?? 7.0` → fixed to `?? 0.0`; display guards `h > 0` correctly show "—"
- VERIFIED (code) — Workout heart rate: `fetchHeartRateStats` now returns `nil` when no samples; `averageHeartRate`/`maxHeartRate` stored as `nil` in Workout model (not as 0)
- VERIFIED (code) — `PostWorkoutCheckInView`: calories guarded `> 0`; shows duration only when calories unknown
- VERIFIED (code) — `hrv ?? 0 > 50` → replaced with explicit nil check
- VERIFIED (code) — `fetchTodayNutrition()` partial-zero issue (protein/carbs ?? 0): function is dead code — never called in production
- CODE AUDITED — `estimateCalories()` in AddWorkoutView exists but is dead code; never called in save path
- CODE AUDITED — MockData values: only referenced in `#Preview` blocks; no production leakage
- RUNTIME TEST REQUIRED — Verify no metric shows a numeric zero when HealthKit has no data for that metric on a real device with permissions denied

---

## 5. SUPABASE SYNC

**Status: IMPLEMENTATION AUDITED — RUNTIME VERIFICATION REQUIRED**

- CODE AUDITED — `daily_contexts` upsert: conflict on "id" column (correct — updates same row per UUID)
- CODE AUDITED — `DailyContextSyncRecord`: snake_case CodingKeys, `encodeIfPresent` for optionals, `YYYY-MM-DD` date, `sodium_mg` omitted
- CODE AUDITED — Sync is non-blocking with 10-second timeout
- CODE AUDITED — 264 print statements wrapped in `#if DEBUG`

**Runtime verification required (cannot be completed without authenticated device):**
- [ ] Log a daily context → confirm Supabase `daily_contexts` row created with correct `user_id`
- [ ] Save again → confirm row is updated (upsert), not duplicated
- [ ] Log out → log in → confirm data loads correctly from Supabase
- [ ] Confirm `sleep_hours` is null in Supabase when user provides no sleep data (not 0)

---

## 6. STOREKIT

**Status: CODE AUDITED — BLOCKED (products not in App Store Connect)**

Production subscription IDs (exhaustive, confirmed by full codebase search):
- `insio_plus_monthly` — Plus tier, $4.99/mo
- `insio_pro_monthly` — Pro tier, $12.99/mo

Yearly IDs in InsioConfig (`insio_plus_yearly`, `insio_pro_yearly`): present in code but excluded
from `allProductIDs`. PaywallView `subscribe()` now directly calls monthly products only.
No yearly product should be created in App Store Connect for this launch.

- CODE AUDITED — StoreKit 2: `Transaction.currentEntitlements` for verification
- CODE AUDITED — `AppStore.sync()` for restore
- CODE AUDITED — UI uses StoreKit `displayPrice` when products are loaded (fallback to "$4.99"/"$12.99" when unavailable)
- BLOCKED — Products must be created in App Store Connect before any purchase testing
- RUNTIME TEST REQUIRED — Sandbox purchase flow end-to-end after products created
- RUNTIME TEST REQUIRED — Restore purchases on second device/reinstall

---

## 7. TRIAL ARCHITECTURE

**Status: CODE AUDITED — KNOWN V1 LIMITATIONS**

Answers to critical questions:

| Question | Answer |
|---|---|
| Where stored? | `UserDefaults.standard`, key `"insio_trial_start_date"` |
| Reset on reinstall? | **YES** — UserDefaults cleared on app deletion. Trial resets unless iCloud backup enabled. |
| Reset on logout/login? | **NO** — `signOut()` does not call `clearPremiumStatus()`. Trial key `trialStartDateKey` is never removed. `startFreeTrial()` guard prevents re-starting. |
| Reset on new account? | **NO** — Trial is device-local, not Supabase-bound. New account on same device inherits existing trial state. |
| Tied to Supabase user? | **NO** — Purely device-local. |
| Implies automatic billing? | **NO** — App-managed soft trial. No payment info collected. No StoreKit introductory offer. |
| On expiration? | `isInTrial = false`, `trialDaysRemaining = nil`. `currentTier` stays `.free`. Feature gating correctly removes Plus access. |
| Falls back to Free? | **YES** — `checkTrialStatus()` called on app appear. Correct. |
| Clock bypass? | **YES** — Setting device clock backward extends trial. Acceptable for V1 soft trial. |

**V1 verdict:** Acceptable for launch. Risks (reinstall bypass, clock bypass) involve no payment and
are standard for app-managed trials. Document clearly in App Store description that the trial is
3 days. Flag for V1.1: bind trial start to Supabase user profile for cross-device enforcement.

---

## 8. AI / OPENROUTER

- CODE AUDITED — API key loaded from `Secrets.xcconfig` via Info.plist — not hardcoded
- CODE AUDITED — `Secrets.xcconfig` in `.gitignore`
- CODE AUDITED — Data sent: aggregated metrics only (no raw HealthKit, no Supabase user ID)
- CODE AUDITED — AI gated by `PremiumManager.canAccessAI()` / `canAccessWorkoutAI()`
- BLOCKED — Production API key must be set in `Secrets.xcconfig` before archive

---

## 9. PRIVACY

- VERIFIED (code) — All production print statements in 7 files wrapped in `#if DEBUG`
- CODE AUDITED — PrivacyInfo.xcprivacy present and configured
- BLOCKED — Terms of Service URL must differ from Privacy Policy URL
- BLOCKED — Privacy policy must be live and reachable at submission time

---

## 10. APP STORE CONNECT

- BLOCKED — App icon PNGs (3 files, 1024×1024)
- BLOCKED — StoreKit products (`insio_plus_monthly`, `insio_pro_monthly`)
- BLOCKED — App listing (name, subtitle, screenshots, description, keywords, age rating)
- BLOCKED — App Store URL placeholder in `InsioConfig.swift` (replace `id0000000000`)
- BLOCKED — Terms of Service separate from Privacy Policy
- BLOCKED — Production OpenRouter API key in `Secrets.xcconfig`
- RUNTIME TEST REQUIRED — Archive upload succeeds and build processes without issues
- RUNTIME TEST REQUIRED — TestFlight internal testers can install and run the app

---

## TESTFLIGHT INTERNAL TEST CHECKLIST

(All items are RUNTIME TEST REQUIRED — complete on physical device)

- [ ] Onboarding completes and transitions to main app
- [ ] HealthKit authorization prompt appears
- [ ] After granting HealthKit: dashboard shows real data (not zeros, not dashes for available data)
- [ ] After denying HealthKit: dashboard shows "—" for all metrics (not 0)
- [ ] Water log → saves → refreshes home → shows correct value
- [ ] Workout added → saves → appears in workout list → calories hidden if 0
- [ ] Paywall shows Plus ($4.99/mo) and Pro ($12.99/mo)
- [ ] Sandbox purchase completes → tier upgrades correctly
- [ ] Trial shows "3 days remaining" on fresh install
- [ ] Trial expiry → reverts to Free (test by setting device clock forward 4 days)
- [ ] Sign out → all data cleared → sign in as different account → empty state
- [ ] Post-workout check-in → submits correctly → no "0 cal" shown for manual workouts
