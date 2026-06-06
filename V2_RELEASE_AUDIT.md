# KafeCam — v2 Release Audit Log

**Date:** 2026-05-29
**Build target:** iOS 26.0 · App Store v2 submission
**Backend:** Supabase prod `uzdvklhsxsujuwjfncdw`
**Method:** Full-codebase review across 6 subsystems (auth, capture/ML/offline,
data layer, profile/avatar/community, home/map/weather, content/IA/voice). Each
area was read line-by-line; findings below cite real `file:line` locations.

> Companion: backend/integration fixes already shipped are in
> [`supabase/REMEDIATION_REPORT.md`](supabase/REMEDIATION_REPORT.md). This document
> covers **app-wide correctness bugs** found afterward. Items already fixed there
> are not repeated.

---

## 0. Release-readiness verdict

**Not ready to submit as-is.** There are **7 P0 issues** that are reachable in the
shipping (v1) surface and will cause crashes, data loss, or a broken first-run
experience for real users. None are hard to fix. Everything behind
`FeatureFlags.communityEnabled` / `assignmentsEnabled` (both `false`) is correctly
gated and not reachable — those issues are tagged **[v2-gated]** and can wait.

| Severity | Count | Must fix before submit? |
|---|---|---|
| 🔴 P0 | 7 | **Yes** |
| 🟠 P1 | 12 | Strongly recommended |
| 🟡 P2 | ~20 | Optional / polish |

---

> **UPDATE 2026-05-29:** all 7 P0s below are **FIXED in code** (build verified,
> `xcodebuild` SUCCEEDED). P0-6 additionally requires applying
> `supabase/migrations/20260529150000_captures_idempotency.sql` to prod (the new
> upsert needs the unique index, or captures will error). P1/P2 remain open.

## 1. 🔴 P0 — Release blockers (fix before submission) — ✅ FIXED

### P0-1 · Returning users are logged out on every cold launch
**`SessionViewModel.swift:13,17` · `HomeScreen/KafeCamApp.swift` · `Login/Register/ContentView.swift:15`**
`SessionViewModel.isLoggedIn` is hard-initialized to `false` and only ever set
true inside the in-session login flow. `init` never consults `auth.isLoggedIn()`
(which reads the persisted `kafe.isLoggedIn` flag and the Supabase SDK's persisted
session). `ContentView` gates on `session.isLoggedIn || session.isGuest`, so **every
already-signed-in user is shown `LoginView` again on every app start.** Guaranteed
hit for existing users.
**Fix:** seed `isLoggedIn = auth.isLoggedIn()` in `SessionViewModel.init`, and
asynchronously validate/refresh the Supabase session on launch (clear the flag if
the session is gone).

### P0-2 · Crash loading existing photos (force-unwrapped + unencoded Storage URLs)
**`Repositories/StorageRepository.swift:26,47,57(ok),65,95,117`**
Every Storage endpoint is built with `URL(string: …)!` and interpolates a **raw,
un-percent-encoded** object key. `signedDownloadURL`/`delete` are fed
`capture.photoKey` **from the database** (`HistoryStore.fetchImage`). Legacy
captures were keyed by **profile name** (e.g. `"Manuel Perez/169..._ab12.jpg"` —
note the space), so `URL(string:)` returns `nil` → **hard `!` crash** when a user
opens History/Gallery containing any pre-fix capture. (`publicURL` at :57 encodes;
the signing/delete/upload paths do not — inconsistent.)
**Fix:** percent-encode `objectKey`/`bucket` on all endpoints and replace `!` with
`guard let … else { throw }`. *(Found independently by the capture and data-layer
audits.)*

### P0-3 · Weather screen crashes on ragged Open-Meteo arrays
**`Anticipa/AnticipaWeatherService.swift:72-80`**
The loop is bounded by `daily.time.count` but then force-indexes five **parallel**
arrays (`temperature_2m_min[i]`, `…max[i]`, `relative_humidity_2m_mean[i]`,
`wind_speed_10m_max[i]`, `precipitation_sum[i]`). Open-Meteo can return shorter/
absent arrays (esp. humidity) → `Index out of range` trap. Anticipa auto-loads
from Home, so this is reachable on normal use.
**Fix:** `count = min` of all array lengths before the loop (or `indices.contains`),
and decode optional fields as optional/`Double`.

### P0-4 · Camera capture session is never stopped (resource/memory leak)
**`Detecta/CameraPreview.swift:16-80`**
`CameraViewController` calls `captureSession.startRunning()` but has no
`viewWillDisappear`/`deinit` calling `stopRunning()`. The `AVCaptureSession`, camera
input, and preview layer stay hot after the camera sheet is dismissed; repeated
open/close accumulates running sessions and keeps the camera/GPU pipeline alive.
**Fix:** stop the session in `viewWillDisappear` (off the main thread) and `deinit`.

### P0-5 · Photo capture can silently fail with no feedback (dead-end)
**`Detecta/CameraPreview.swift:99-106`**
In the `AVCapturePhotoCaptureDelegate`, if `fileDataRepresentation()` is nil,
`UIImage(data:)` fails, or `error != nil`, the `if let` falls through and
`onPhotoCaptured` is never called — and `error` is ignored entirely. Since that
callback is what drives analysis/dismissal, the user taps the shutter and **nothing
happens, with no retry/message** (reproducible under memory pressure / HEIC edge
cases).
**Fix:** handle the `error`/nil paths and surface a "no se pudo tomar la foto"
message (e.g. an `onError` closure).

### P0-6 · Offline sync creates duplicate captures (no idempotency)
**`Services/CapturesService.swift:42` · `Services/OfflineSyncService.swift:43-69`**
`saveCapture` mints a **fresh** `clientUUID: UUID()` on every call and never uses
the stable `clientUUID` already stored on the queued `PendingCapture`. `captures.
client_uuid` is `NOT NULL` but **has no UNIQUE constraint**, so there is no
server-side dedup. Any time the immediate upload partially completes but
`markSynced` doesn't run (app killed, or the offline retry runs), the capture is
re-uploaded → **duplicate storage object + duplicate DB row** (duplicate diagnoses
and map pins). Compounded by a TOCTOU in `syncPending` (the `isSyncing` guard is set
*after* an `await`, so two callers can run the loop concurrently — `OfflineSyncService.swift:44-51`).
**Fix:** thread the stable `clientUUID` through `saveCapture`/`saveCaptureToDefaultPlot`;
add a `UNIQUE (uploaded_by_user_id, client_uuid)` index + `on conflict do nothing`
(DB migration); set `isSyncing = true` synchronously before the first `await`.

### P0-7 · Anticipa shows weather for the wrong region on first launch
**`Anticipa/AnticipaViewModel.swift:34-37,44-50` · `Anticipa/AnticipaLocation.swift:41-47`**
`onAppear()` fires `location.requestOnce()` then immediately `await load()`. The GPS
fix takes seconds, so `location.coord` is `nil` at read time on first launch →
weather is fetched for the **hardcoded Monterrey fallback** (`25.68, -100.32`) and
labeled "Monterrey, NL" even for a user in Chiapas, with **no re-fetch** when the
real fix arrives. Home alerts derive from this, so the whole advisory feature shows
wrong-region data. (Also a cross-thread `coord` read/write data race.)
**Fix:** have `AnticipaLocation` notify the VM when the first fix lands and re-run
`load()`; make `coord` access main-thread/`@MainActor`.

---

## 2. 🟠 P1 — Major bugs (strongly recommended)

| # | Location | Issue | Fix |
|---|---|---|---|
| P1-1 | `LoginViewModel.swift:57-59` | Every login error → "Teléfono o contraseña incorrectos." A network/server failure is reported as a wrong password (dead-end, no retry). | Branch on error type; show connectivity vs credential messages. |
| P1-2 | `SessionViewModel.swift:23-31` · `ContentView.swift:23-25` | `logout()` posts `kafe.session.logout`, whose observer calls `logout()` again → double sign-out loop; observer is only attached in the `hasSeenOnboarding==true` branch, so some logouts are dropped. 3 competing sources of login truth. | Make `SessionViewModel` the single source; flip state directly without the notification loop. |
| P1-3 | `Detecta/DetectaView.swift:236-258` | CoreML model + `VNCoreMLModel` are loaded **on the main thread on every capture** (hundreds of ms UI freeze, re-reads model from disk each time). | Cache `VNCoreMLModel` once; load off-main. |
| P1-4 | `Detecta/DetectaView.swift:104-130` | On `currentUserId()` failure the accept path `return`s before `store.queue(...)`, so the in-memory history entry is never persisted → diagnosis lost on next launch. | Queue to disk regardless of auth; gate only the upload on auth. |
| P1-5 | `Detecta/DetectaView.swift:268-285` | `no_planta` returns before resetting `lastStatus`/`lastConfidencePct`/`lastDiseaseName` (`@State`); a later accepted capture can be saved with the previous run's status/confidence. | Reset these on each new classify / "Volver a capturar". |
| P1-6 | `Map/MapTabView.swift:187-195` | Manual pin placement uses flat linear interpolation of the region — ignores Mercator latitude distortion & rotation, so pins land off the tap point. | Use `MapReader`/`MapProxy.convert(_:from:)` (iOS 17+). |
| P1-7 | `Map/MapTabView.swift:23` | `Map(position: .constant(.region(vm.region)))` — constant binding fights user pan/zoom; map snaps back and pin math reads a stale region. | Use a real `MapCameraPosition` binding + `onMapCameraChange`. |
| P1-8 | `Map/MapViewModel.swift:35,126-147,202` | Class isn't `@MainActor`; some `@Published` writes are main-dispatched and others aren't; `savePins()` runs in `didSet` on every mutation. | `@MainActor` the class; debounce `savePins`. |
| P1-9 | `IA/Voice/VoiceService.swift:75-77,113-122,196-197` | `AVAudioSession` is activated (`.record`/`.duckOthers`) but **never deactivated** on stop → other apps' audio stays ducked/interrupted. App-Review-visible. | `setActive(false, .notifyOthersOnDeactivation)` on stop / TTS finish. |
| P1-10 | `IA/Voice/VoiceService.swift:62-67` · `IA/Brain/AsistenteView.swift:113-124` | Speech/mic permission result never checked before `start()`; on denial the mic button silently does nothing. | Gate `handleMic` on authorization; prompt to Settings. |
| P1-11 | `Detecta/HistoryStore.swift:96,166` | History merge de-dups by timestamp proximity (`<1s` / `<2s`); two genuine captures in the same second collapse → **visible data loss** in History. | De-dup on capture `id`/`client_uuid`, not wall-clock. |
| P1-12 | `IA/Brain/AsistenteView.swift:208-215` | `ProcessingIndicator` starts `Task { while true … }` with no cancellation (`try?` swallows cancellation) → leaked task waking the main actor forever. | Use a SwiftUI repeating animation, or cancel in `.onDisappear`. |

---

## 3. 🟡 P2 — Minor / polish (optional)

**Auth/Session**
- `LocalAuthService.swift:78,83,88` — `try!` on `NSRegularExpression` (latent crash; also recompiled per keystroke). Compile once as `static let`.
- `LocalAuthService.swift:83` — password regex forbids symbols & has no max length; strong passwords with `!@#` are rejected.
- `RegisterViewModel.swift:51-53` — full name composed from un-trimmed parts → stored name can keep extra whitespace.
- `ForgotPasswordView.swift:187-195` — "identity verification" only matches the first name token (security theater; can also reject valid users). Step 2 requires current password anyway.
- `RegisterViewModel.swift:80` / `DeleteAccountView.swift:152` — dead `signupSuccess` flag (written/removed, never read).
- `SupaClient.swift:88` (`signUpThenSignIn`) — on "Email not confirmed" it shows an **end-user message telling them to open the Supabase Dashboard** — make generic copy and verify the project's email-confirm setting.

**Capture/Data**
- `DetectaView.swift:136` → `captures.device_model` is fed the **prediction text**, not the device model (garbage analytics).
- `PushNotificationService.swift:50-58` — APNs token saved via `.update` (no row → silently lost). Use `upsert`.
- `CapturesRepository.swift:42` — `taken_at` serialized without fractional seconds; sub-second ordering undefined.
- `LocalCapturesStore.swift:24-25` — filename is `"\(seconds).jpg"` with no UUID → same-second overwrite (legacy path).
- `PlotDTO.swift:34-40` — `JSONDecoder.supabaseDefault` is dead code the SDK ignores; misleading foot-gun (delete it).
- `ProfilesRepository.swift:121-130` — `get(byId:)` uses `.single()` → throws on 0 rows/RLS-hidden; use a `maybeSingle` pattern for the by-id lookup.

**Map/Weather**
- `AnticipaWeatherService.swift:73,86-90` — `parseISO` (expects full timestamp) is used on date-only daily `time` → falls back to `Date()`, so all 3 day cells show today's weekday. Use a `yyyy-MM-dd` formatter.
- `AnticipaWeatherService.swift:48,57` — `URLComponents(string:)!` / `comps.url!` force-unwraps on the networking path.
- `MapViewModel.swift:126-132` — deprecated + modern auth-change delegates both implemented (dead code on iOS 14+).
- `MapViewModel.swift:118-121` · `MapTabView.swift:82` — denied/restricted location swallowed with no "Open Settings" affordance.
- `MapTabView.swift:212-216` — status picker shows raw enum values un-localized.
- `HomeView.swift:394-409` — `MapSectionView` is dead/unused (and duplicates base coordinates that slightly differ). Delete.

**Content/IA**
- `MLXTranslator.swift:65-71` — indigenous translation model `kafecam-translator-q4` not in the bundle → Tzotzil silently falls back to Spanish. Ship the model or feature-flag indigenous languages (avoid advertising a non-working capability to App Review).
- `MLXTranslator.swift:124-132` — `ensureReady()` busy-waits with no timeout.
- `ConsultaDetailView.swift:49-51` — "Guardar nota" button body is empty (typed notes lost); `InfoView.swift:15` is placeholder text. Verify reachability; wire to `HistoryStore.updateNotes` or remove.
- `DiseaseDetailView.swift:56` — prevention safety-warning gated on a hardcoded Spanish string; gate on the index instead (localization landmine on a safety message).
- `WelcomeOnboardingView.swift:163-166` — extracts strings via `Mirror` reflection of `LocalizedStringKey` internals (fragile; bypasses real localization).
- `Components/AudioReadButton.swift:29-54` — `KafeSpeaker` TTS doesn't set `.playback` session → may be inaudible after dictation left `.record` active.
- `Bitacora/BitacoraEntry.swift:82-93` — images stored inline in UserDefaults (plist bloat; not a blocker).

---

## 4. [v2-gated] — Behind feature flags, fix when re-enabling

These are **not reachable** with `communityEnabled=false` / `assignmentsEnabled=false`,
so they don't block v2 submission — but must be fixed before turning those features on:
- **`EditProfileView.swift` (whole file)** — dead duplicate edit screen that re-introduces already-fixed bugs (editable phone `:54`, raw synthetic email `:99`, a "change photo" button posting a notification no one observes `:37`). **Recommend deleting now** so it can't be wired up by mistake.
- `CommunityOnboardingView.swift:215-231` — writes an **uppercase**, versioned avatar key → violates the avatars write-RLS (`name = auth.uid()::text || '.jpg'`, lowercase). Standardize to `<lowercase-uid>.jpg`.
- `UserDetailView.swift:32-37` · `FarmerDetailView.swift:21` — render `profile.email` raw (would show synthetic `@kafe.local`). Wrap with `sanitizedPersonalEmail`.
- `AssignmentRequestsRepository.swift:82-85` — sends `accept` as a JSON **string** to a (future) boolean RPC param.
- Brute-force avatar key probing in `CommunityListView`/`CreateListView`/`EditListView`/`UserDetailView` (up to ~20 signed-URL round-trips). Collapse to the single standard key.

---

## 5. Verified clean (checked, no action)
- **Secrets:** no hardcoded keys/DSN in source; `SupabaseConfig` injects from a gitignored xcconfig. `Info.plist` has all required usage strings (camera, location, mic, speech).
- **DTO decode safety:** SDK 2.33.1 default decoder handles all `timestamptz`/`date` wire formats; `ProfileDTO`'s custom parser is complete and `try?`-guarded. No decode-crashers remain (the `PlotDTO.ownerUserId` nullable fix is present).
- **Persistence:** Bitácora, favorites, lesson-progress (comma-delimited IDs) round-trip correctly.
- **Apple Intelligence / FoundationModels:** availability checked at runtime; iOS 26 deployment target makes the import valid.
- **Gating:** community/assignment surfaces have no ungated entry points in the shipping build.

---

## 6. Recommended fix order before submission
1. **P0-1** (session restore) — highest user impact.
2. **P0-2** (Storage URL crash) — crashes on existing prod photos.
3. **P0-3** (weather array crash) and **P0-7** (wrong region) — Anticipa/Home.
4. **P0-4 / P0-5** (camera lifecycle + silent capture failure).
5. **P0-6** (capture idempotency) — needs a small DB migration (`UNIQUE` on `client_uuid`) + client threading.
6. P1 batch (login errors, CoreML off-main, audio session, history dedup, map binding).
7. P2 / [v2-gated] as time permits; delete `EditProfileView.swift` now.

*Audit performed read-only; no source files were modified during this review.*
