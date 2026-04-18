# Momentum — CLAUDE.md

## What this app is
Momentum is a Flutter-based automotive enthusiast app — "Strava for cars."
It tracks real-time driving statistics, stores trip history with route visualization,
includes a marketplace connecting parts vendors with buyers, and has a leaderboard/social layer.
This is a capstone project for Lebanese American University (CSC department).

## Current state
The following already exists and works — do not rewrite unless explicitly asked:
- `lib/data/services/location_service.dart` — GPS tracking via geolocator, Haversine distance — platform-specific settings: AndroidSettings (200ms interval) and AppleSettings (bestForNavigation, automotiveNavigation)
- `lib/data/services/trip_service.dart` — avg speed, max speed, distance, duration calculation — EMA removed, 2 km/h zero-clamp, lastReadingInvalid getter — no sensor dependency
- `lib/data/services/sensor_service.dart` — magnitude-based G-force detection at 20 Hz, brake/accel state machines (0.18G threshold, 300ms duration guard), speed-gated via updateSpeed(). Cornering removed entirely. SensorService is owned by TrackingNotifier only — TripService has no sensor dependency.
- `lib/data/models/trip_data.dart` — trip data model
- `lib/features/tracking/screens/tracking_screen.dart` — main tracking screen, display lerp 0.4, zero-snap, fixed-height timer pill — contains temporary sensor debug panel (remove during final polish pass)
- `lib/features/tracking/widgets/speedometer_widget.dart` — speedometer gauge
- `lib/features/tracking/widgets/stat_card.dart` — stat display cards
- `lib/features/tracking/widgets/gps_status_indicator.dart` — yellow pill indicator shown when GPS speed reading is invalid
- `lib/features/tracking/providers/tracking_provider.dart` — Riverpod provider for tracking state, exposes gpsWeak from lastReadingInvalid, owns the sole SensorService instance
- `lib/core/theme/app_theme.dart` — app theme
- `lib/features/trip_history/screens/trip_detail_screen.dart` — trip detail with Google Maps route visualization
- `lib/features/profile/screens/profile_screen.dart` — user profile, car details, stats, sign out
- `lib/features/profile/services/nhtsa_service.dart` — NHTSA API for make/model dropdowns
- `lib/features/profile/providers/profile_provider.dart` — Riverpod provider for profile state

## Architecture — feature-based structure
New features go under `lib/features/`:

```
lib/
├── core/
│   ├── theme/app_theme.dart
│   └── constants/
├── data/
│   ├── models/
│   └── services/
├── features/
│   ├── tracking/        # Live drive screen (extend prototype)
│   ├── trip_history/    # Past trips, route map, stats
│   ├── marketplace/     # Parts listings, post item, search
│   ├── leaderboard/     # Rankings, social feed
│   ├── profile/         # User profile, structured car details
│   └── auth/            # Login, register screens
└── shared/
    └── widgets/         # Reusable components
```

## Tech stack
- Flutter 3.10.7+
- State management: Riverpod
- Local storage: Hive
- Backend: Firebase (Firestore + Auth)
- Map: google_maps_flutter (trip detail screen) — dark style via JSON, teal polyline, canvas-drawn circle markers
- GPS: geolocator (already in use)
- Motion sensors: sensors_plus
- Routing: go_router

### Map implementation notes
- `google_maps_flutter` is the active map package — `flutter_map` and `latlong2` remain in pubspec.yaml but are not used for rendering
- Dark map style is applied via a JSON style string constant in `trip_detail_screen.dart`
- Route polyline: `Color(0xFF00D4A0)` (teal), width 4
- Start marker: `speedGreen` fill + white border (canvas-drawn circle, no default pin)
- End marker: white fill + `accent` teal border (canvas-drawn circle, no default pin)
- Markers use `anchor: Offset(0.5, 0.5)` — circle centres on the coordinate

### GPS pipeline notes
- Android: AndroidSettings(accuracy: high, distanceFilter: 0, intervalDuration: 200ms)
- iOS: AppleSettings(accuracy: bestForNavigation, activityType: automotiveNavigation, distanceFilter: 0, pauseLocationUpdatesAutomatically: false)
- No app-level smoothing — raw GPS speed used directly (hardware-filtered by platform)
- Zero-clamp: speeds below 2 km/h are treated as 0 to eliminate stationary noise
- Invalid readings (position.speed < 0) are skipped entirely — trip stats not updated, last valid speed held
- Display lerp: factor 0.4 at 60fps in _AnimatedSpeedometer — converges to target in ~150ms

### Sensor implementation notes
- Sensor: `userAccelerometerEventStream` via `sensors_plus`, throttled to 20 Hz
- Approach: magnitude-only (`sqrt(x²+y²+z²) / 9.81`) — orientation-independent, no axis mapping or calibration needed
- Brake threshold: 0.18G sustained >= 300ms, only attributed when GPS speed is decreasing
- Accel threshold: 0.18G sustained >= 300ms, only attributed when GPS speed is increasing
- Cornering: removed — magnitude cannot reliably distinguish corners from road bumps without axis mapping
- `SensorService` owned exclusively by `TrackingNotifier` — do not add it back to `TripService`
- `TripService` has no sensor dependency — `stopTrip()` is `void`, sensor summary comes from `_sensorService.stopTracking()` in the provider
- iOS motion permission: `Permission.sensors` via `permission_handler` required before stream starts
- Debug panel in `tracking_screen.dart` is temporary — remove before final polish pass

### Google Maps API key injection
- **Android (local):** Add `GOOGLE_MAPS_API_KEY=<key>` to `android/local.properties` (gitignored). `build.gradle.kts` loads `local.properties` via `java.util.Properties` and injects via `manifestPlaceholders`.
- **iOS (local):** Not applicable — dev machine is Windows, no Xcode available.
- **CI (both platforms):** GitHub Actions secret `GOOGLE_MAPS_API_KEY`. Android: appended to `android/local.properties` before build. iOS: patched directly into `ios/Runner/Info.plist` via `PlistBuddy` before build — no Xcode user-defined settings needed.
- Do not suggest Xcode-based key setup steps. All iOS key injection is CI-only via PlistBuddy.

## Firebase setup

### Authentication
- Provider: Firebase Email/Password only
- Registration fields: email, password, username only — no car field on registration
- Username stored in Firestore under users/{uid} — not in Firebase Auth
- Car details are filled in later on the profile screen
- Login: email + password only
- Username is the display identity across leaderboard, marketplace listings, and profile

### Firestore collections
```
users/{uid}
  - username, email, totalDistance, totalTrips, createdAt
  - car: { make, model, year, trim (optional), notes (optional) }

trips/{tripId}
  - uid, username, date, maxSpeed, avgSpeed, distance, duration
  - route: [ {lat, lng, speed}, ... ]  ← for the map trace
  - hardBrakeCount, peakBrakeG, avgBrakeG
  - hardAccelCount, peakAccelG, avgAccelG

listings/{listingId}
  - uid, username, title, description, price, category, imageUrl, createdAt

leaderboard/{uid}
  - username, car (map with make/model/year), topSpeed, totalDistance, smoothnessScore
```

### User profile — car details (COMPLETE)
- Profile screen: `lib/features/profile/screens/profile_screen.dart`
- Car fields: Make (NHTSA API dropdown), Model (cascades from Make via NHTSA), Year (1970–2025 hardcoded dropdown), Trim (optional text), Mods/Notes (optional multiline)
- NHTSA service: `lib/features/profile/services/nhtsa_service.dart` — fetches makes and models from the NHTSA public API
- Reads/writes to Firestore `users/{uid}` and `users/{uid}.car`
- Stat tiles on profile: total trips + total distance (read-only, from Firestore)
- Sign out button on profile screen
- Car details displayed on leaderboard entries and marketplace listings

### Firebase rules
- Firestore and Storage are in test mode during development
- Tighten rules before any public demo if needed
- firebase_options.dart is auto-generated by FlutterFire CLI — do not manually edit it

## iOS support
- `ios/Podfile` — iOS 13.0 deployment target, `permission_handler` macros enabled
- `ios/Runner/Info.plist` — location + motion permission keys, `UIBackgroundModes: location`, `GMSApiKey` placeholder (patched at CI build time)
- `ios/Runner/AppDelegate.swift` — calls `GMSServices.provideAPIKey(...)` reading from `Info.plist`
- `GoogleService-Info.plist` — injected at CI build time via GitHub Actions secret (not committed)
- GitHub Actions workflow `iOS-ipa-build` — manual trigger, produces unsigned IPA artifact

## Design system — strict, do not deviate

### Color palette
```dart
static const background    = Color(0xFF0D0D0D);
static const surface       = Color(0xFF1A1A1A);
static const surfaceHigh   = Color(0xFF222222);
static const accent        = Color(0xFF00D4A0);  // teal — primary accent
static const silver        = Color(0xFFC0C0C0);  // secondary accent
static const textPrimary   = Color(0xFFFFFFFF);
static const textSecondary = Color(0xFF8A8A8A);
static const speedGreen    = Color(0xFF06D6A0);
static const speedYellow   = Color(0xFFFFD23F);
static const speedRed      = Color(0xFFE63946);
static const routeLine     = Color(0xFF00D4A0);  // teal route trace on map
```

### UI direction
- Dark mode only, no light mode
- Premium AMG-inspired aesthetic — precise, technical, clean
- Glassmorphism-style stat cards with subtle borders (Color(0xFF00D4A0).withOpacity(0.15))
- Arc-based speedometer using CustomPainter — NOT a simple progress indicator
- Smooth number animations using AnimatedSwitcher or Tween
- Map route trace: teal (#00D4A0) polyline on dark Google Maps style (not OpenStreetMap)
- Typography: clean, minimal — no decorative fonts

## Features status

### Complete
- Auth screens — register (email, password, username) + login
- UI modernization — arc speedometer, glass stat cards on tracking screen
- Trip history + storage — Hive + Firestore, trip list screen, trip detail screen
- Route visualization — Google Maps dark style, teal polyline, canvas circle markers
- Profile screen — NHTSA make/model dropdowns, year/trim/notes, stat tiles, sign out
- Speed tracking improvements — platform-specific GPS settings, zero-clamp, invalid reading guard, display lerp 0.4
- G-force sensor tracking — braking G and acceleration G (peak, avg, count) tracked via sensors_plus magnitude approach, saved to Hive and Firestore per trip, displayed in trip detail screen

### Remaining (in priority order)
1. **Marketplace** — browse listings, post item form (with Firebase Storage image upload), search/filter
2. **Leaderboard** — ranked by smoothness score based on braking and acceleration data (primary), top speed, total distance
3. **Final polish pass** — animations, transitions, edge cases, remove temporary sensor debug panel

## Rules
- This is a capstone demo — prioritize working features and visual polish over edge case handling
- Always use the color palette above — no hardcoded colors outside app_theme.dart
- When adding packages, add them to pubspec.yaml and note they need `flutter pub get`
- Prefer StatelessWidget + Riverpod providers over StatefulWidget
- Do not modify location_service.dart or trip_service.dart unless the task specifically requires it
- Map: use `google_maps_flutter` — do not use `flutter_map` for new map work
- Keep all screens under `lib/features/<feature>/screens/` and widgets under `lib/features/<feature>/widgets/`
- Remove the temporary sensor debug panel from `tracking_screen.dart` during the final polish pass