# Mobile Emergency Module — Handover

**Scope:** Flutter Android module (`lib/main.dart`, Android manifest, dependencies, tests).
**Date:** 2026-11-17
**Integration:** Merged into the shared `main` branch; original commit history and authorship preserved.

This module covers:

- GPS & Location Services
- Location Permissions
- Reverse Geocoding
- OpenStreetMap Integration
- SOS Emergency Flow
- Live Location Tracking
- Emergency Session Management
- Emergency History & Persistence

---

## 1. Honest audit status

| Area | Status | Evidence / notes |
|---|---|---|
| Original UI (GetStarted, Home, SOS, cards, colors, navigation) | **Preserved** | No layout/colors/fonts/logos/buttons were redesigned. Only data sources, labels and lifecycle were changed. Home location card gained a small 9.5px source/accuracy line. |
| GPS permission states (denied / deniedForever / unableToDetermine / service off) | **Fixed + unit-tested** | `LiveLocationService.promptEnableGps`, `permissionMessage`, `getCurrentPositionWithSource`; App Settings path for permanent denial. `geolocator 13.0.4` has no `restricted` enum value in this SDK. |
| Real coordinates, no fake fallback | **Fixed** | `getCurrentPosition()` now returns `null` when no real/cached fix exists. Home, MapScreen and FindNearest hide the map instead of showing hardcoded Cairo. Remaining `30.0444, 31.2357` is only a labeled manual preset. |
| Source labels (`LIVE GPS`, `LAST KNOWN`, `CACHED`, `SIMULATED`, `MANUAL SELECTION`, `FALLBACK (not real)`) | **Fixed + unit-tested** | `LocationResult.sourceLabel`, `LiveLocationService.lastSourceLabel`, `metadataLine`; shown in Home, SOS, Map and FindNearest. |
| Accuracy / time / source display | **Fixed** | `metadataLine` = `SOURCE · ±Xm · HH:MM`; SOS shows `SOURCE · address · lat, lng`. |
| Live updates / no duplicate listeners | **Fixed** | `startTracking()` returns a client id; every screen stores and stops only its own id. One shared `StreamSubscription`. Emergency keeps its own token across navigation and stops on cancel. |
| Reverse geocoding | **Implemented, provider unverified at runtime** | `geocoding` plugin → platform geocoder; `formatAddressLabel` priority neighborhood → street → city → governorate → country; `AddressInfo.verified=false` yields "Address unavailable (lat, lng)". `getAreaName()` is now explicitly only coarse demo metadata, never a verified address. |
| Map engine / tiles / recenter / errors | **Implemented, runtime verification in progress** | `flutter_map` + OSM tiles, no Google Maps widget and no Maps API key. Source-aware initial center, recenter FAB, tile error flag, attribution, offline snackbar. |
| SOS launch honesty | **Fixed** | Dialer/SMS/WhatsApp helpers return actual launch results. No call is placed, no SMS is auto-sent, no backend dispatch is claimed. Local session is saved before/after launches with a timeline. |
| SOS duplicate prevention | **Fixed** | Status guard + `_triggerInProgress`; active session restored when re-entering the screen. |
| Tracking stop after resolution | **Fixed** | `_emergencyTrackToken` stopped on cancel; screen tokens stopped in `dispose`; no global `stopTracking()` from screens. |
| History persistence / reload / clear / corruption | **Implemented; JSON tests pass** | `SharedPreferences` string list; try/catch per entry on load; `fromJson` backward-compatible with legacy entries. Runtime restart check pending. |
| Firebase init / channels / FCM | **Code audit only** | `Firebase.initializeApp()`, local channel, foreground/background/cold-start handlers and token getter exist. Delivery/background delivery **not verified** — no server project/backend in this repo. |
| Notifications | **Local implementation** | Channel `nabd_emergency_channel`, foreground FCM → local notification. Test notification text is now a demo, not dispatch confirmation. |
| Offline behavior | **Implemented (code path), runtime check pending** | GPS works without internet; SOS/history local; map tile errors flagged and message shown. |
| Secrets | **Manifest fixed; history needs team action** | Hardcoded Google Maps key removed from `AndroidManifest.xml`. An old key value still exists in earlier commits (`49d466d`) and in `google-services.json` (Firebase client key). Rotate/restrict the Maps key with the team; do not rewrite shared history without agreement. |
| Automated tests | **Passing** | `flutter test` → 11/11 passed. `flutter analyze` → no issues. |
| Android device run | **Passed (emulator)** | Fresh APK installed and launched on `Medium_Phone_API_37.0`. Startup, Home, GPS A–E, reverse geocoding, SOS dialer, history reload, tracking stop all verified via logcat. Old Pixel 6 AVD remained broken (`Failed to protect CE key for user 0`). See §5. |

---

## 2. What was changed (file-by-file)

- `lib/main.dart`
  - Added `AddressInfo`, `formatAddressLabel`, `lookupAddress`, `describeAddress`.
  - `LiveLocationService`: client-ID tracking map, permission messaging, source/accuracy/time metadata, timeouts, no fake fallback.
  - `HomeContent`: source-aware location chip, real map center, address resolution, own tracking client.
  - `MapScreen`: source-aware location chip, no hardcoded center, tile-error state, recenter, OSM attribution.
  - `EmergencySOSScreen`: source-aware location, honest launch results, local session + timeline, tracked client tokens, active-session restore, safe quick actions.
  - `LiveTrackingMapScreen`, `FindNearestScreen`: own tracking client / no hardcoded map center.
  - `EmergencySession`: source, accuracy, address, timeline, backward-compatible JSON.
- `android/app/src/main/AndroidManifest.xml`: removed hardcoded Maps API key and unused `CALL_PHONE`; clarified INTERNET comment.
- `pubspec.yaml` / `pubspec.lock`: added `geocoding` (already declared, now resolved).
- `analysis_options.yaml`: excludes archived extracted folders and legacy root `main.dart`; cosmetic legacy lints downgraded so `analyze` is clean.
- `.gitignore`: ignores audit scratch artifacts (`*.dex`, `dump.txt`, screenshots, `*.log`, `apk_unpacked/`).
- `test/mobile_emergency_module_test.dart`: 11 tests for address formatting, coarse area labels, source labels, permission messages and session JSON.

---

## 3. Dependencies & assets

- Flutter SDK: `C:\flutter\bin\flutter.bat` (Flutter not on PATH in this environment).
- Android SDK / adb: `C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe`.
- Key packages: `geolocator ^13.0.1`, `geocoding ^3.0.0`, `flutter_map ^8.3.2`, `latlong2 ^0.10.1`, `shared_preferences ^2.3.2`, `firebase_core ^3.6.0`, `firebase_messaging ^15.1.3`, `flutter_local_notifications ^17.2.2`, `connectivity_plus ^6.0.3`, `url_launcher ^6.3.0`.
- Existing assets unchanged: `assets/images/onboarding_bg.png`, `nabd_logo.png`, etc. No new asset added.
- `android/app/google-services.json` is required for Firebase build and is already present.

---

## 4. Run / verify instructions

```powershell
cd C:\Users\hp\Downloads\AI-Emergency-Response-System-main
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat devices
C:\flutter\bin\flutter.bat run -d <device-id>
```

For a fresh emulator:

```powershell
$emu = 'C:\Users\hp\AppData\Local\Android\Sdk\emulator\emulator.exe'
& $emu -avd Medium_Phone_API_37.0 -netdelay none -netspeed full
# in another shell:
& 'C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell getprop sys.boot_completed
```

Mock-location A–E (emulator only, never real emergency numbers):

```powershell
$adb = 'C:\Users\hp\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb shell pm grant com.example.emergency_help android.permission.ACCESS_FINE_LOCATION
# Helwan
& $adb emu geo fix 31.30 29.85
# Maadi
& $adb emu geo fix 31.28 29.96
# Giza / Dokki
& $adb emu geo fix 31.19 30.02
# 6th of October
& $adb emu geo fix 30.95 29.93
# Alexandria
& $adb emu geo fix 29.95 31.20
```

Expected: Home/SOS/Map labels follow the mock coordinate and `SIMULATED` source; address comes from the platform geocoder when available, otherwise "Address unavailable". Do **not** tap Call/SMS/WhatsApp for real tests; use the quick-action snackbars to confirm only that the app tries to open the composer.

---

## 5. Runtime verification result (Android emulator, 2026-11-17)

**Device:** `Medium_Phone_API_37.0`, Android 17 (API 37), `emulator-5554`.
**Build/install:** `flutter build apk --debug` succeeded; `adb install -r ...\app-debug.apk` succeeded; app launched to `com.example.emergency_help/.MainActivity` with no `FATAL EXCEPTION` / `E/flutter`.

### 5.1 Startup + UI navigation
```
I flutter: Nabd: GetStarted tapped -> HomeScreen
```
Original GetStarted button opened Home. Screenshot diff confirmed the screen changed. Emergency card opened the SOS screen (dark theme preserved).

### 5.2 Real mock-GPS A–E and reverse geocoding
Mock locations were injected with `cmd location providers set-test-provider-location gps --location <lat>,<lng> --accuracy 5` (the old `adb emu geo fix` path did not override the Google location provider on this AVD).

```
A Helwan   Nabd Home: 29.85000,31.30000 source=LAST KNOWN  -> Helwan El Balad, Cairo Governorate, Egypt
B Maadi    Nabd Home: 29.96000,31.28000 source=SIMULATED accuracy=5m -> Maadi as Sarayat Al Gharbeyah, Cairo Governorate, Egypt
C Giza     Nabd Home: 30.02000,31.19000 source=SIMULATED accuracy=5m -> Al Safa We Al Marwa, Nazlet Khalaf, Giza Governorate, Egypt
D 6 Oct    Nabd Home: 29.93000,30.95000 source=SIMULATED accuracy=5m -> First 6th of October, Giza Governorate, Egypt
E Alex     Nabd Home: 31.20000,29.95000 source=SIMULATED accuracy=5m -> Izbat Al Gamee, Alexandria Governorate, Egypt
```
Notes:
- Live stream updates arrived automatically after each mock change (no restart).
- `SIMULATED` is reported for mock fixes; no mock point was ever labeled `LIVE GPS`.
- The first fix after cold start was `LAST KNOWN` with no accuracy — correctly labeled, not invented.
- Reverse geocoding came from the platform geocoder and returned real Egyptian addresses.

### 5.3 SOS (safe test — dialer only)
```
I flutter: Nabd SOS: loc=31.20000,29.95000 source=LAST KNOWN accuracy=nullm
           dialerOpened=true smsOpened=false address="Izbat Al Gamee, Alexandria Governorate, Egypt" (local only)
I flutter: Nabd GPS: start client=2 total=2
I flutter: Nabd history: persisted 2 session(s)
```
- The Android dialer opened with 123; **no call was placed**.
- No SMS app was available: `smsOpened=false`, reported honestly (no false "sent" claim).
- Session was stored locally with source, accuracy, address and timeline.

### 5.4 Tracking lifecycle + cancel
```
I flutter: Nabd GPS: start client=1 total=1   (Home screen)
I flutter: Nabd GPS: start client=2 total=2   (SOS joins same shared stream)
I flutter: Nabd GPS: stop client=2 remaining=1 (Cancel pressed)
I flutter: Nabd history: persisted 2 session(s)
```
No duplicate stream subscription was created; cancelling removed only the emergency client.

### 5.5 Persistence across restart
```
I flutter: Nabd history: loaded 1 session(s) from SharedPreferences
```
After restarting the process, the previously saved local session was reloaded. After the second SOS, 2 sessions were persisted.

### 5.6 Not verified on device
- Real `LIVE GPS` (requires a physical device; emulator mocks are always `SIMULATED`).
- Actual FCM push delivery / background / cold-start tap (no server send test).
- Visual pixel inspection of map tiles (map uses real OSM tile URLs; no fake fallback). No map tile errors were observed in logcat.

---

## 6. Known limitations / honest claims

- Responder names/positions are **demo clustering around the real GPS point**, not live ambulance telemetry.
- No backend endpoint exists. Nothing is dispatched; history is local only.
- Emulator `geo fix` is reported as `SIMULATED`, never as real GPS.
- Reverse geocoding needs the platform geocoder (usually network); without it the app says "Address unavailable" instead of inventing an address.
- Firebase push delivery, background handlers and cold-start tap navigation are **code-complete but not proven** without a configured FCM send test.
- The old Maps API key in git history should be rotated/restricted by the team. The current tree has no hardcoded Maps key.
