# RELEASE BLOCKERS — Insio Health
Last updated: 2026-08-30 (Pass 2)

Status labels: VERIFIED | CODE AUDITED | RUNTIME TEST REQUIRED | BLOCKED | FAILED

---

## BLOCKER 1 — App icon PNG files missing (BUILD BLOCKER)

**Status: BLOCKED**
**Severity:** CRITICAL — App Store Connect will reject the binary.

- `Vero/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024 light) — MISSING
- `Vero/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png` (1024×1024 dark) — MISSING
- `Vero/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png` (1024×1024 tinted) — MISSING

`Contents.json` references all three. No final Insio artwork was found in the repository.
Do not invent placeholder art. The icon must be final before archiving.

**Fix:** Drop production-ready 1024×1024 PNGs into `Vero/Assets.xcassets/AppIcon.appiconset/`.

---

## BLOCKER 2 — xcodebuild CLI cannot build this project

**Status: BLOCKED**
**Severity:** CRITICAL — prevents automated/CI builds.

**Exact error:**
```
xcodebuild: error: Unable to read project 'Insio.xcodeproj'.
Reason: The project 'Insio' is damaged and cannot be opened due to a parse error.
CFPropertyListCreateFromXMLData(): Old-style plist parser: missing semicolon in dictionary on line 274.
```

**Root cause confirmed:** `project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16
"Referenced Folders" feature). The xcodebuild command-line plist parser does not support this format.
This is not a corrupt file — it builds successfully in Xcode GUI (DerivedData confirmed present).

**Fix:** Must build from Xcode GUI only (Product → Archive). CLI/CI support requires either:
- Downgrading to a traditional group structure in Xcode (destructive)
- Upgrading CI to use a version of xcodebuild that understands Xcode 16 format

**Next human action:** Open `Insio.xcodeproj` in Xcode 16, select "Any iOS Device (arm64)" or your
connected device, Product → Archive. Verify it compiles with zero errors before uploading.

---

## BLOCKER 3 — App Store Connect: In-App Purchase products not created

**Status: BLOCKED — APP STORE CONNECT CONFIGURATION REQUIRED**
**Severity:** CRITICAL — paywall shows no purchasable products; StoreKit returns empty.

Products required (monthly only at launch):

| Display Name | Product ID           | Price  |
|--------------|----------------------|--------|
| Insio Plus   | `insio_plus_monthly` | $4.99  |
| Insio Pro    | `insio_pro_monthly`  | $12.99 |

Yearly IDs (`insio_plus_yearly`, `insio_pro_yearly`) exist in `InsioConfig.swift` but are excluded
from `allProductIDs` and the paywall subscribe() now only calls monthly products. These are safe to
leave in code but must NOT be created in App Store Connect for this launch.

---

## BLOCKER 4 — App Store Connect: App listing incomplete

**Status: BLOCKED**
**Severity:** HIGH — cannot submit build without completing the listing.

Required: app name, subtitle, description, keywords, screenshots (6.9" + 6.5" or required sizes),
age rating, privacy policy URL, support URL.

---

## BLOCKER 5 — OpenRouter production API key missing

**Status: BLOCKED**
**Severity:** HIGH — AI features silently disabled if key is empty.

`Vero/Secrets.xcconfig` — `OPENROUTER_API_KEY =` (empty)

Set the production key before archiving. File is already in `.gitignore`.

---

## BLOCKER 6 — App Store URL placeholder

**Status: CODE AUDITED**
**Severity:** MEDIUM — does not block TestFlight; blocks any "rate us" link.

`InsioConfig.swift`: `static let appStoreURL = "https://apps.apple.com/app/insio-health/id0000000000"`

Not used in any production UI — safe for TestFlight. Replace `id0000000000` with the real Apple ID
after App Store Connect creates the app record.

---

## BLOCKER 7 — Terms of Service URL is identical to Privacy Policy URL

**Status: CODE AUDITED**
**Severity:** MEDIUM.

`InsioConfig.swift` — `termsOfServiceURL` points to the same Notion page as `privacyPolicyURL`.
Create a separate Terms/EULA document or explicitly remove the `termsOfServiceURL` constant and
reference only the privacy policy everywhere.

---

## RESOLVED BLOCKERS (fixed in codebase)

- ✅ Sleep fallback `?? 7.0` fabricating health data → fixed to `?? 0.0`
- ✅ Workout heart rate returns `HeartRateStats(0,0,0)` when no HK data → fixed to return `nil`; `averageHeartRate`/`maxHeartRate` now correctly stored as `nil` in Workout model
- ✅ `PostWorkoutCheckInView` showed "0 cal" for workouts with no HealthKit calorie data → fixed with `> 0` guard
- ✅ `hrv ?? 0 > 50` treated nil HRV as 0 bpm → fixed to explicit nil check
- ✅ Paywall yearly billing toggle removed; `subscribe()` now directly calls monthly products
- ✅ 300+ unguarded production print statements across 7 files → all wrapped in `#if DEBUG`
- ✅ HealthKit writes: none exist (read-only confirmed)
- ✅ MockData: preview-only confirmed (not leaking to production)
- ✅ `fetchTodayNutrition()` partial-zero issue: function is defined but never called — dead code, not a production bug
