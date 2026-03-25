# KafeCam — Full Project Analysis

> Generated: 2026-03-24

---

## 1. Project Overview

**KafeCam** is an iOS/SwiftUI application for coffee farmers and field technicians in Chiapas, Mexico.

- Camera-based crop monitoring + disease detection (CoreML/Vision)
- Weather forecasting and agricultural risk alerts (Open-Meteo)
- Disease encyclopedia (5 diseases + nutritional deficiencies)
- Farm plot management + MapKit visualization
- Role-based users: Farmer, Technician, Admin (Supabase)
- Multilingual: Spanish, English, Tzotzil (beta — indigenous community support)

**Stack:** Swift 5.0 · SwiftUI · Supabase · CoreML · MapKit · Open-Meteo · iOS/iPadOS/macOS/visionOS

---

## 2. Architecture & System Design

```
UI Layer (SwiftUI Views)
    ↕
ViewModel Layer (@StateObject / @EnvironmentObject)
    ↕
Service Layer (CapturesService)
    ↕
Repository Layer (6 Repositories → Supabase PostgREST)
    ↕
Supabase Backend (PostgreSQL + RLS + Storage + Edge Functions)
```

**Pattern:** MVVM + Repository. Reasonably clean layering.

### Strengths
- Repository pattern properly isolates Supabase calls from business logic
- Server-side Row-Level Security — app cannot bypass data isolation
- Protocol-based `AuthService` (Supabase + Local) enables testing
- `#if canImport(Supabase)` guards allow Swift Previews without live backend
- Edge Functions for signed URLs keep storage secrets off-device

### Weaknesses
- `PlotsMapViewModel` lives in `HomeView` as `@StateObject` then injected as `.environmentObject()` — VM lifecycle tied to HomeView
- Cross-module communication via `NotificationCenter` with 8+ string-literal notification names — no Combine, no typed events
- Navigation logic leaks into Views (no app-level router/coordinator)
- `HistoryStore.syncFromSupabase()` fetches all captures + downloads all images with no pagination
- `Player/` secondary Xcode target has no clear relationship to the main app

---

## 3. Codebase Structure

**Folder org is feature-based — correct approach.** Issues:

- `Profile/` — 22 files, oversized; profile editing + avatar + farmer list + assignment requests all bundled
- `Services/` — only 1 file (`CapturesService`); business logic has leaked into ViewModels
- `SampleData.swift` in `HomeScreen/` — test/sample data in production target
- `MapSectionView` struct at `HomeView.swift:369-384` — dead code, never called
- Naming split: `*DTO` (PlotDTO) vs `*Model` (DiseaseModel) for the same layer
- `ktextfild` — a named violation with a comment justifying it ("sloppy name on purpose") — still a smell

---

## 4. Features Audit

| Feature | Status |
|---|---|
| Phone-based auth (register/login/logout) | ✅ Complete |
| Role-based access (farmer/technician/admin) | ✅ Complete |
| Camera capture + local cache | ✅ Complete |
| Capture upload to Supabase Storage | ✅ Complete |
| Disease encyclopedia (JSON-driven) | ✅ Complete |
| History/Gallery + Favorites | ✅ Complete |
| Weather + risk alerts | ✅ Complete |
| Plot CRUD + Map pins | ✅ Complete |
| Technician-farmer assignment flow | ✅ Complete |
| i18n (ES/EN/Tzotzil) | ⚠️ Partial — ~30% of UI strings hardcoded in Spanish |
| ML disease detection (CoreML) | ⚠️ Wired but unconfirmed end-to-end |
| Signed URL upload via Edge Function | ⚠️ README says "not fully wired" |
| Offline mode | ❌ Missing |
| Push notifications | ❌ Missing |
| Admin dashboard | ❌ Missing |
| Forgot password flow | ❌ View exists, backend not wired |

---

## 5. Data Layer & Integrations

### Database Schema (inferred from DTOs + repositories)

```
profiles       (id, phone, name, email, role, org, locale, personal info, visibility flags)
plots          (id, name, lat, lon, altitude_m, region, owner_user_id)
captures       (id, plot_id, uploaded_by_user_id, taken_at, photo_key, checksum_sha256, notes, ...)
technician_farmers  (technician_id, farmer_id)
assignment_requests (id, technician_id, farmer_id, status)
```

### External Integrations

| Service | Purpose | Auth |
|---|---|---|
| Supabase Auth | User authentication | Anon key + JWT |
| Supabase PostgREST | Database CRUD | JWT + RLS |
| Supabase Storage | Image uploads/downloads | Signed URLs |
| Supabase Edge Functions | `upload_url`, `get_url` | JWT |
| Open-Meteo API | Weather forecast | None (free, public) |
| MapKit | Map display | Apple entitlement |
| CoreLocation | GPS tagging | Runtime permission |
| CoreML/Vision | Disease detection | On-device |

### Data Flow Issues
- `HistoryStore` fetches ALL captures with no limit/offset — memory cliff as data grows
- No image caching layer (no Kingfisher, NSCache) — thumbnails re-downloaded every session
- `AvatarStore` holds `UIImage` in memory only — lost on app restart

---

## 6. Code Quality & Best Practices

### Critical Issues

**1. Dev credentials committed to source** — `KafeCam/Configuration/SupabaseConfig.swift:13-14`
```swift
static let devEmail = "test@test.com"
static let devPassword = "test123"
```
`.gitignore` excludes this file but it is already tracked in git history.

**2. Mirror reflection to extract access token** — `KafeCam/Repositories/StorageRepository.swift:22-23`
```swift
let tokenMirror = Mirror(reflecting: session)
let accessToken = (tokenMirror.children.first { $0.label == "accessToken" }?.value as? String) ?? ""
```
Breaks silently on any Supabase SDK internal rename. The SDK exposes `session.accessToken` directly — use it.

**3. No design token system** — `Color(red: 88/255, green: 129/255, blue: 87/255)` defined in **20+ files**. Any brand color change is a multi-file edit.

**4. Mixed localization** — `HomeView.swift:108,230,235` has hardcoded Spanish strings that bypass the i18n infrastructure entirely.

**5. Dead code in production**
- `MapSectionView` struct in `HomeView.swift` (never called)
- `SampleData.swift` in `HomeScreen/` (test data in prod target)
- `Player/` Xcode target (unexplained, no connection to main app)

### Good Practices
- Protocol-driven auth (`AuthService` protocol) — testable
- Input sanitization: path encoding, char removal in storage keys, string trimming
- Password hashing with salt in `LocalAuthService`
- `defer { isLoading = false }` pattern throughout ViewModels
- `#if canImport(Supabase)` for Preview compatibility

---

## 7. Security Analysis

| Issue | Severity | Status |
|---|---|---|
| Dev credentials in source code | HIGH | Present |
| Access token via Mirror reflection | MEDIUM | Present — silent failure risk |
| Anon key embedded in app | LOW | Acceptable (standard mobile pattern) |
| Service role never used on client | — | Correct |
| Server-side RLS enforced | — | Correct |
| SECURITY DEFINER RPCs for privileged ops | — | Correct |
| Phone + password validation | — | Correct |
| No account enumeration on login error | — | Correct |
| User-scoped storage object keys | — | Correct |

**Bottom line:** Server-side posture is solid. Two client-side issues must be fixed before any production deployment.

---

## 8. Performance & Scalability

### Bottlenecks
- `HistoryStore` full-fetch: will OOM at ~500+ captures per user
- No image cache: every session re-downloads all thumbnails from Supabase Storage
- Profile sync fires on every `.task` (every view appear, not just login) — `HomeView.swift:121`
- Signed URLs expire in 1 hour — images break in long sessions
- Open-Meteo free tier has rate limits — not suitable for production at scale

### Scalability Assessment
- Supabase backend scales horizontally — not the bottleneck
- RLS policies will degrade with complex joins as user count grows
- CoreML on-device inference scales perfectly (no server load)
- All current bottlenecks are client-side

---

## 9. DevOps & Deployment

### Current State
- No CI/CD (no GitHub Actions, no Fastlane, no Xcode Cloud config)
- No environment separation — `Debug` and `Release` point to the same Supabase project
- No crash reporting (no Crashlytics, Sentry, or Bugsnag)
- No analytics (no Mixpanel, Amplitude, Firebase Analytics)
- 5 developer `xcuserdata/` directories committed to the repo (should be gitignored)
- No App Store metadata, privacy policy, or data deletion flow

### Missing for Production
- TestFlight distribution pipeline
- Separate Dev / Staging / Prod Supabase environments
- Crash reporting
- App Store privacy nutrition label + data deletion flow (App Store requirement)

---

## 10. UI/UX Assessment

### Strengths
- Agricultural green/brown palette — coherent visual identity
- Glass morphism tab bar — modern iOS feel
- LazyVGrid action cards — responsive layout
- Weather + risk display is clear and actionable
- Tzotzil language support is a meaningful cultural choice for the target audience

### Weaknesses
- **1 (one) `.accessibilityLabel()` in the entire app** — VoiceOver is unusable; App Store rejection risk
- ~30% of visible strings hardcoded in Spanish, won't translate regardless of language setting
- No image loading placeholders — blank whitespace while downloading
- No empty state UI for History screen
- No haptic feedback on capture/save actions (standard iOS expectation)
- Validation errors can fall below the viewport on small screens

---

## 11. Risks & Technical Debt

### Critical Risks

| Risk | Severity |
|---|---|
| Dev credentials in source code | Critical |
| Mirror reflection for access token — silent breakage on SDK update | High |
| No crash reporting — production failures invisible to team | High |
| Alert stubs (`CameraUsageService`, `SoilSensorService`) may return hardcoded data | Medium |
| No pagination in HistoryStore — performance cliff at scale | Medium |
| No offline mode for a rural use case (connectivity gaps expected) | Medium |

### Technical Debt
- Color duplication × 20 files — no design system
- Profile module oversized (22 files) — warrants splitting
- `Player/` target unexplained
- `SampleData.swift` in prod target
- Dead `MapSectionView` struct
- `ktextfild` naming violation

---

## 12. Actionable Improvements

### Quick Wins (1–3 days)
1. Remove dev credentials from `KafeCam/Configuration/SupabaseConfig.swift`
2. Add `*.xcuserdata/` to `.gitignore` and clean committed user data
3. Replace `Mirror` reflection with `session.accessToken` in `KafeCam/Repositories/StorageRepository.swift`
4. Create `KafeColors.swift` — centralize the 20+ duplicate color definitions
5. Delete dead `MapSectionView` struct; move `SampleData.swift` to test target
6. Add `.accessibilityLabel()` to: camera capture button, favorite button, map pins

### Medium-Term (1–4 weeks)
1. `KafeTheme.swift` — typography + spacing + color tokens
2. Paginate `HistoryStore` (limit/offset on captures fetch, lazy image loading)
3. Add `NSCache` or integrate Kingfisher for capture thumbnail caching
4. Extract all hardcoded Spanish strings to `Localizable.strings` — complete ES/EN parity
5. Integrate Sentry or Firebase Crashlytics
6. Create typed `KafeNotification` enum to replace raw `NotificationCenter` string literals
7. Verify or remove `CameraUsageService`/`SoilSensorService` — wire real sensor data or eliminate fake alerts
8. Wire `ForgotPasswordView` to Supabase password reset

### Long-Term Strategic (1–3 months)
1. **Separate Supabase environments** — Dev / Staging / Prod with per-scheme `SupabaseConfig`
2. **CI/CD pipeline** — GitHub Actions → Xcode Cloud → TestFlight
3. **Offline mode** — Core Data or SQLite sync queue for captures (critical for rural connectivity)
4. **Complete ML disease detection** — wire CoreML inference end-to-end, display results in capture review
5. **Push notifications** — alert farmers when technician responds to assignment request
6. **Admin dashboard** — web interface (e.g., Next.js + Supabase) for user management and aggregate analytics
7. **Split `Profile/` module** — separate into `UserAccount`, `FarmerProfile`, `TechnicianManagement`
8. **App Store compliance** — privacy nutrition label, data deletion flow, in-app privacy policy link

---

## 13. Overall Ratings

| Dimension | Score | Rationale |
|---|---|---|
| **Architecture** | **7/10** | MVVM + Repository is solid. Good use of protocols. Weakened by NotificationCenter coupling, no coordinator, VM lifecycle coupling. |
| **Code Quality** | **5/10** | Core logic is correct. High maintenance surface: no design system, color duplication × 20, dev credentials in source, reflection hack, dead code. |
| **Scalability** | **5/10** | Backend scales. App doesn't — no pagination, no image cache, no offline queue. Will degrade beyond ~200 captures/user. |
| **Product Readiness** | **4/10** | Impressive feature set for the team size. Blocked by: 1 accessibility label in entire app (rejection risk), no CI/CD, no crash reporting, incomplete ML pipeline. |

---

## Final Verdict

**This is a well-conceived MVP with good bones.** The domain model is thoughtful, the Supabase integration is correctly architected (RLS, edge functions, role separation), and the multilingual/multicultural design for an indigenous farming community is genuinely commendable.

**It is not production-ready.** Blocking issues: accessibility (App Store rejection risk), dev credentials in source, no crash observability, unconfirmed ML pipeline, no environment separation.

> **Current state: advanced MVP — not yet beta-ready.**
> 3–4 weeks of focused cleanup → TestFlight quality.
> 2–3 months of investment → App Store ready.
