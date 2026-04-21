# Momentum — CLAUDE.md

## What this app is
Momentum is a Flutter-based automotive enthusiast app — "Strava for cars."
It tracks real-time driving statistics, stores trip history with route visualization,
and has a leaderboard/social layer.
This is a capstone project for Lebanese American University (CSC department).

## Current state
The following already exists and works — do not rewrite unless explicitly asked:
- `lib/data/services/location_service.dart` — GPS tracking via geolocator, Haversine distance — platform-specific settings: AndroidSettings (200ms interval) and AppleSettings(bestForNavigation, automotiveNavigation)
- `lib/data/services/trip_service.dart` — avg speed, max speed, distance, duration calculation — EMA removed, 2 km/h zero-clamp, lastReadingInvalid getter — no sensor dependency
- `lib/data/services/sensor_service.dart` — magnitude-based G-force detection at 20 Hz, brake/accel state machines (0.18G threshold, 300ms duration guard), speed-gated via updateSpeed(). Cornering removed entirely. SensorService is owned by TrackingNotifier only — TripService has no sensor dependency.
- `lib/data/services/weather_service.dart` — fetches weather from Open-Meteo API using lat/lng, maps WMO codes to labels and smoothness multipliers, returns null on error
- `lib/data/models/trip_data.dart` — trip data model, cornering fields removed, weather fields and smoothnessScore added
- `lib/features/tracking/screens/tracking_screen.dart` — main tracking screen, display lerp 0.4, zero-snap, fixed-height timer pill — debug panel removed
- `lib/features/tracking/widgets/speedometer_widget.dart` — speedometer gauge
- `lib/features/tracking/widgets/stat_card.dart` — stat display cards
- `lib/features/tracking/widgets/gps_status_indicator.dart` — yellow pill indicator shown when GPS speed reading is invalid
- `lib/features/tracking/providers/tracking_provider.dart` — Riverpod provider for tracking state, exposes gpsWeak from lastReadingInvalid, owns the sole SensorService instance, runs weather fetch and smoothness score computation at trip end
- `lib/core/theme/app_theme.dart` — app theme
- `lib/features/trip_history/screens/trip_detail_screen.dart` — trip detail with Google Maps route visualization, smoothness/weather/braking/accel cards — cornering card removed; braking card label reads "Total Brakes" (field: `hardBrakeCount`); accel card label reads "Quick Accels" (field: `hardAccelCount`); card order: map → stats → smoothness → weather → braking → accel
- `lib/features/leaderboard/screens/leaderboard_screen.dart` — leaderboard screen, queries trips directly, groups by uid client-side, time filter toggle (Today / This Week / This Month / All Time), ranked by smoothnessScore → distance → avgSpeed, current user highlighted with teal border
- `lib/features/leaderboard/providers/leaderboard_provider.dart` — StateNotifierProvider holding selected time filter and fetched entries
- `lib/features/profile/screens/profile_screen.dart` — user profile, car details, stats, maintenance section, sign out
- `lib/features/profile/services/nhtsa_service.dart` — NHTSA API for make/model dropdowns
- `lib/features/profile/providers/profile_provider.dart` — Riverpod provider for profile state
- `lib/features/profile/models/maintenance_entry.dart` — MaintenanceEntry model with toMap()/fromDoc()
- `lib/features/profile/providers/maintenance_provider.dart` — StateNotifierProvider streaming maintenance entries; addEntry/updateEntry/deleteEntry
- `lib/features/profile/widgets/maintenance_bottom_sheet.dart` — add/edit bottom sheet with type presets, date pickers, notes
- `lib/features/trip_history/widgets/share_card_painter.dart` — CustomPainter for route normalization and drawing (do not modify drawing logic without discussion)
- `lib/features/trip_history/widgets/share_trip_card.dart` — 1080×1920 share card widget; weather and smoothness follow the same hide conditions as trip detail (hide if empty/zero)
- `lib/features/clubs/services/club_service.dart` — all club, post, comment, like, pin logic
- `lib/features/clubs/providers/club_provider.dart` — userClubsProvider, allClubsProvider, clubDetailProvider, clubPostsProvider, clubCommentsProvider
- `lib/features/clubs/widgets/post_card.dart` — feed post card, CommentsSheet, EditPostSheet
- `lib/features/clubs/widgets/create_post_sheet.dart` — new post bottom sheet (image + caption)
- `lib/features/clubs/screens/clubs_hub_screen.dart` — MY CLUBS + DISCOVER tabs, embedded mode
- `lib/features/clubs/screens/club_detail_screen.dart` — feed + leaderboard tabs, pin, join/leave/delete
- `lib/features/ai_coach/services/coaching_service.dart` — calls Claude API at trip end with trip stats, returns a coaching note string; falls back to a static no-sensor message when sensor data is unavailable; result stored as `coachingNote` (String) on trip document; lazy generation: only called once and cached, not regenerated on re-open
- `lib/features/friends/services/friend_service.dart` — sends/accepts/declines friend requests, removes friends, streams incoming pending requests; uses `friend_requests` Firestore collection and `friends` array field on `users/{uid}`
- `lib/features/friends/models/friend_entry.dart` — FriendEntry model (uid, username, carModel)
- `lib/features/friends/models/friend_request.dart` — FriendRequest model (requestId, fromUid, fromUsername, toUid, status, createdAt)
- `lib/features/friends/providers/friend_provider.dart` — Riverpod providers for friend list, pending received requests, and send/accept/decline/remove actions
- `lib/features/leaderboard/widgets/user_mini_card.dart` — bottom sheet showing a user's profile mini-card (username, car, stats); triggered by tapping a leaderboard entry
- `lib/features/friends/screens/friend_comparison_screen.dart` — side-by-side stat comparison between current user and a friend; route `/friends/compare/:friendUid`

## Architecture — feature-based structure
New features go under `lib/features/`:

```
lib/
├── config/
│   └── secrets.dart          # gitignored — anthropicApiKey constant
├── core/
│   ├── theme/app_theme.dart
│   └── constants/
├── data/
│   ├── models/
│   └── services/
├── features/
│   ├── tracking/        # Live drive screen
│   ├── trip_history/    # Past trips, route map, stats
│   ├── leaderboard/     # Rankings with time filters
│   ├── profile/         # User profile, car details, maintenance log
│   ├── friends/         # Friend system, comparison screen
│   ├── ai_coach/        # AI driving coach service
│   └── auth/            # Login, register screens
└── shared/
    └── widgets/         # Reusable components
```

## Tech stack
- Flutter 3.10.7+
- State management: Riverpod
- Local storage: Hive
- Backend: Firebase (Firestore + Auth + Storage)
- Map: google_maps_flutter (trip detail screen) — dark style via JSON, teal polyline, canvas-drawn circle markers
- GPS: geolocator (already in use)
- Motion sensors: sensors_plus
- Routing: go_router
- Weather: Open-Meteo API (free, no key required) — fetched at trip end using midpoint GPS coordinate
- Share: share_plus ^10.1.4 — shares the trip card PNG via native share sheet
- Temp files: path_provider ^2.1.4 — used to write the share card PNG to a temp directory before sharing
- AI coach: Anthropic Claude API via `anthropic` Dart SDK — key stored in `lib/config/secrets.dart` (gitignored)
- Notifications: shared_preferences — used to track which friend-request IDs have already triggered an Android notification, preventing duplicates on app relaunch
- Image picker: image_picker ^1.1.2 — used in CreatePostSheet for camera and gallery image selection

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
- Cornering: removed entirely — magnitude cannot reliably distinguish corners from road bumps without axis mapping
- `SensorService` owned exclusively by `TrackingNotifier` — do not add it back to `TripService`
- `TripService` has no sensor dependency — `stopTrip()` is `void`, sensor summary comes from `_sensorService.stopTracking()` in the provider
- iOS motion permission: `Permission.sensors` via `permission_handler` required before stream starts

### Weather implementation notes
- Provider: Open-Meteo API — `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,weather_code`
- No API key required
- Fetched once at trip end using the midpoint coordinate of the route array
- WMO weather code mapped to a human-readable label (e.g. "Clear", "Partly Cloudy", "Heavy Rain") and a smoothness multiplier
- Weather multiplier scale (applied to smoothness score):
  - Clear / Mostly Clear (codes 0–2): 1.00
  - Partly Cloudy / Overcast (codes 3, 45, 48): 1.05
  - Light Rain / Drizzle (codes 51–57, 61): 1.10
  - Moderate Rain (codes 63, 80–81): 1.15
  - Heavy Rain / Thunderstorm (codes 65, 82, 95–99): 1.25
  - Snow / Sleet (codes 71–77): 1.20
- A perfect drive in clear weather still scores 100 — multiplier only makes it easier to reach 100 in bad conditions
- Stored fields on trip document: `weatherCode` (int), `weatherLabel` (String), `weatherTempC` (double), `weatherMultiplier` (double)
- Displayed in trip detail as a weather card; hidden for old trips where weatherLabel is empty
- Weather card currently shows `Icons.wb_sunny_outlined` as a placeholder icon for all weather types — custom painter illustrations planned for polish pass

### Smoothness score notes
- Computed once at trip end, stored as `smoothnessScore` (double, 0–100) on the trip document
- Formula (in `_computeSmoothnessScore` inside `tracking_provider.dart`):
  - peakBrakeG and peakAccelG are clamped to 1.0G max before scoring to filter out sensor noise
  - Start at 100
  - If peakBrakeG > 0.5G (clamped): deduct `(peakBrakeG - 0.5) * 30`
  - If avgBrakeG > 0.25G: deduct `(avgBrakeG - 0.25) * 25`
  - If peakAccelG > 0.6G (clamped): deduct `(peakAccelG - 0.6) * 20`
  - Clamp to 0–100, then multiply by weatherMultiplier and clamp again
- `finalScore = (score.clamp(0, 100) * weatherMultiplier).clamp(0, 100)`
- No count-based penalties — only G-force intensity matters, so longer trips are not unfairly penalized
- Stored on trip document and used directly by leaderboard queries — not recomputed at read time
- Displayed in trip detail as `_SmoothnessCard` (≥90 → "Excellent", ≥75 → "Good", ≥60 → "Average", <60 → "Needs Work"); hidden when smoothnessScore == 0.0

### Leaderboard notes
- Queries `trips` collection directly — no separate leaderboard collection
- Filters by `date` range based on selected time filter, then groups by uid client-side keeping each user's best trip
- Trips shorter than 0.5 km are excluded from leaderboard ranking to filter out accidental/test trips
- Ranked by: **average smoothnessScore across all qualifying trips** (not best single trip score) → distance → avgSpeed as tiebreakers
- `allTimeByUid` map maintained separately for All Time filter — leaderboard uses parallel queries and merges results client-side
- Car model fetched from `users` collection in batches
- Time filter defaults to This Week
- Current user's entry highlighted with `AppTheme.accent.withOpacity(0.3)` border
- Tapping a leaderboard entry opens `user_mini_card.dart` bottom sheet with that user's profile mini-card
- Requires a composite Firestore index on (date, smoothnessScore, distance, avgSpeed) — Firebase will print a clickable creation link in the debug console on first query run if not yet created

### AI driving coach notes
- Service: `lib/features/ai_coach/services/coaching_service.dart`
- Called once at trip end from `tracking_provider.dart` immediately after smoothness score computation
- Sends: distance, duration, maxSpeed, avgSpeed, smoothnessScore, peakBrakeG, avgBrakeG, peakAccelG, weatherLabel
- Result stored as `coachingNote` (String) on the trip Firestore document
- Lazy: if `coachingNote` is already non-empty on a trip document, it is displayed as-is — the API is not called again
- Fallback: if sensor data is unavailable (peakBrakeG == 0 and peakAccelG == 0), a static informational message is returned instead of calling the API
- Displayed in trip detail screen as a coaching card below the accel card; hidden when `coachingNote` is empty
- API key lives in `lib/config/secrets.dart` — this file is gitignored; do not commit it

### Friend system notes
- `friend_service.dart` — `sendRequest(toUid)`, `acceptRequest(requestId)`, `declineRequest(requestId)`, `removeFriend(friendUid)`, `streamPendingReceived()`, `streamFriends()`
- Friend requests stored in `friend_requests/{requestId}` with fields: fromUid, fromUsername, toUid, status, createdAt
- Accepted friends stored as a `friends: [uid, ...]` array on each user's `users/{uid}` document (both sides updated atomically)
- Android notification fires for each new incoming friend request; SharedPreferences key `notified_request_ids` (Set\<String\>) prevents duplicate notifications across app restarts
- `user_mini_card.dart` bottom sheet: shows username, car make/model/year, total trips, total distance, and a Send Friend Request button (button hidden if already friends or request already sent)
- Friend comparison screen at `/friends/compare/:friendUid`: fetches both users' trip stats from Firestore and renders a side-by-side card layout using the design system colors

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
- Username is the display identity across leaderboard and profile

### Firestore collections
```
users/{uid}
  - username, email, totalDistance, totalTrips, createdAt
  - car: { make, model, year, trim (optional), notes (optional) }
  - friends: [ uid, ... ]  ← array of accepted friend UIDs

users/{uid}/maintenance/{entryId}
  - type (String — e.g. "Oil Change", "General Checkup", "Yearly Inspection")
  - lastDoneDate (Timestamp)
  - nextDueDate (Timestamp, optional)
  - notes (String, optional)
  - createdAt (Timestamp)

trips/{tripId}
  - uid, username, date, maxSpeed, avgSpeed, distance, duration
  - route: [ {lat, lng, speed}, ... ]  ← for the map trace
  - hardBrakeCount, peakBrakeG, avgBrakeG
  - hardAccelCount, peakAccelG, avgAccelG
  - weatherCode (int), weatherLabel (String), weatherTempC (double), weatherMultiplier (double)
  - smoothnessScore (double, 0–100)
  - coachingNote (String) — AI driving coach feedback, generated lazily at trip end

friend_requests/{requestId}
  - fromUid, fromUsername, toUid, status ("pending" | "accepted" | "declined"), createdAt

clubs/{clubId}
  - name, description, createdBy (uid), adminUids (List<String>), memberUids (List<String>), pinnedPostId (String?), createdAt

clubs/{clubId}/posts/{postId}
  - authorUid, authorUsername, caption (String?), imageUrl (String?), likedBy (List<String>), likeCount (int), commentCount (int), createdAt, editedAt (DateTime?)

clubs/{clubId}/posts/{postId}/comments/{commentId}
  - authorUid, authorUsername, text, createdAt, editedAt (DateTime?)

users/{uid}
  - added clubIds: List<String>
```

Note: There is no separate `leaderboard` collection. The leaderboard queries the `trips` collection directly. Marketplace feature was scrapped — no `listings` collection.

### User profile — car details (COMPLETE)
- Profile screen: `lib/features/profile/screens/profile_screen.dart`
- Car fields: Make (NHTSA API dropdown), Model (cascades from Make via NHTSA), Year (1970–2025 hardcoded dropdown), Trim (optional text), Mods/Notes (optional multiline)
- NHTSA service: `lib/features/profile/services/nhtsa_service.dart` — fetches makes and models from the NHTSA public API
- Reads/writes to Firestore `users/{uid}` and `users/{uid}.car`
- Stat tiles on profile: total trips + total distance (read-only, from Firestore)
- Friends section on profile screen: shows accepted friends list and pending received friend requests; accept/decline actions inline
- Sign out button on profile screen

### Firebase rules
- Firestore and Storage are in test mode during development
- Tighten rules before any public demo if needed
- firebase_options.dart is auto-generated by FlutterFire CLI — do not manually edit it

## iOS support
- `ios/Podfile` — iOS 13.0 deployment target, `permission_handler` macros enabled
- `ios/Runner/Info.plist` — location + motion permission keys, `UIBackgroundModes: location`, `GMSApiKey` placeholder (patched at CI build time), `NSPhotoLibraryAddUsageDescription` for save-to-gallery on share
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
- Cleanup — cornering removed from all models, services, and UI; debug panel removed from tracking screen
- Weather on trips — Open-Meteo fetch at trip end, stored on trip document, displayed as card in trip detail
- Smoothness score — computed at trip end, stored on trip document, displayed as card in trip detail
- Leaderboard — time filter toggle, queries trips directly, grouped by uid, ranked by avg smoothness score across all qualifying trips (≥0.5 km); parallel queries for All Time; tapping entry opens user mini-card bottom sheet
- Maintenance log — section on profile screen, Firestore subcollection, add/edit/delete with undo snackbar, overdue/due-soon color coding
- Share Trip — RepaintBoundary + RenderRepaintBoundary.toImage() pipeline captures a 1080×1920 PNG off-screen. Card layout: route polyline (teal, no map base layer) in left column (65% width), four stats stacked vertically in right column (35% width), weather + smoothness side by side below, branding strip (@username + Momentum) at bottom. Shared via share_plus. Button in trip detail screen after accel card. NSPhotoLibraryAddUsageDescription added to ios/Runner/Info.plist for iOS save-to-gallery support.
- AI driving coach — `coaching_service.dart` calls Claude API at trip end with trip stats; result stored as `coachingNote` on trip document; lazy generation (generated once, not on re-open); falls back to a static message when sensor data is unavailable; displayed as a card in trip detail below the accel card
- Friend system — send/accept/decline/remove friends via `friend_service.dart`; `friend_requests` Firestore collection; `friends` array on `users/{uid}`; FriendEntry and FriendRequest models; `friend_provider.dart` Riverpod providers; friends list and pending received requests shown on profile screen; Android notifications for incoming friend requests using SharedPreferences to track notified request IDs
- User mini card — `user_mini_card.dart` bottom sheet showing username, car, stats; triggered from leaderboard entry tap; includes Send Friend Request button
- Friend comparison screen — `friend_comparison_screen.dart` at route `/friends/compare/:friendUid`; side-by-side stat comparison between current user and a friend; `parseTrips` filters `t.smoothnessScore > 0 && t.distance >= 0.5` so unscored/short trips are excluded from avg and best smoothness calculations
- Friend search — `lib/features/friends/screens/friend_search_screen.dart` — accessible from profile via `person_add_outlined` icon next to FRIENDS header; prefix/partial username search via Firestore range query (`isGreaterThanOrEqualTo` / `isLessThan`), 400ms debounce, limit 20; excludes current user from results; tapping a result opens `user_mini_card.dart` bottom sheet; registered at `/friends/search` in go_router
- Social clubs — full feature. Create/join/leave/delete clubs (max 50 members). Clubs tab is the middle navbar item (replaced marketplace). Club discovery via search (prefix match) and browse-all (sorted by member count). Per-club feed with posts (text + optional image via image_picker, Firebase Storage at club_posts/{clubId}/{timestamp}.jpg). Posts support: like/unlike (toggleLike batch write), comments (subcollection clubs/{clubId}/posts/{postId}/comments with commentCount maintained via batch), edit caption (author only), delete (author or admin). Admin/owner can pin one post per club (pinnedPostId on club doc, shown above feed with teal pin indicator). CreatePostSheet (`lib/features/clubs/widgets/create_post_sheet.dart`) handles image picker (camera + gallery) and caption. PostCard (`lib/features/clubs/widgets/post_card.dart`) renders feed items with like/comment actions, three-dot menu, relative timestamps, "(edited)" label. CommentsSheet and EditPostSheet are inline widgets inside post_card.dart. Per-club leaderboard tab reuses global leaderboard pattern, batched whereIn queries (chunks of 30), filtered to club members, same time filter toggles. ClubsHubScreen supports embedded mode (no back button when used as navbar tab).

### Known issues
- **Leaderboard composite Firestore index** — if not yet created, open the leaderboard screen and check the debug console for a Firebase URL, click it, hit Create Index, wait ~60 seconds.
- **Weather icon placeholder** — weather card shows `Icons.wb_sunny_outlined` for all weather types; custom painter illustrations planned for polish pass.
- **Push notifications (iOS)** — Android works correctly: system notification fires on app launch for each overdue maintenance entry. iOS notifications are implemented (flutter_local_notifications, permission granted) but delivery is unreliable — notifications only appear when the app is backgrounded shortly after launch due to iOS foreground suppression. No code fix found without Xcode/APNs debugging access. Feature is functional on Android for demo purposes.

### Remaining (in build order)
1. **Leaderboard distance aggregation fix** — ensure total distance shown per user on leaderboard aggregates correctly across all qualifying trips
2. **Simulator trip guard for coaching** — skip AI coaching call when `distance < 0.5 || duration < 1` alongside the existing sensor check
3. **Adjust/refine AI coaching prompt** — tune wording and context sent to Claude API
4. **Polish pass** — custom weather painter illustrations (sun, cloud, rain, thunderstorm, snow) replacing placeholder icon, animations, transitions, edge cases

## Rules
- This is a capstone demo — prioritize working features and visual polish over edge case handling
- Always use the color palette above — no hardcoded colors outside app_theme.dart
- When adding packages, add them to pubspec.yaml and note they need `flutter pub get`
- Prefer StatelessWidget + Riverpod providers over StatefulWidget
- Do not modify location_service.dart or trip_service.dart unless the task specifically requires it
- Map: use `google_maps_flutter` — do not use `flutter_map` for new map work
- Keep all screens under `lib/features/<feature>/screens/` and widgets under `lib/features/<feature>/widgets/`
- Weather fetch and smoothness score computation both happen inside `tracking_provider.dart` at trip end — do not add weather or scoring logic to `trip_service.dart`
- SensorService lives in TrackingNotifier only — do not add back to TripService
- Do not modify `share_card_painter.dart` drawing logic without discussion
- Weather and smoothness on the share card follow the same hide conditions as trip detail: hide weather if `weatherLabel.isEmpty`, hide smoothness if `smoothnessScore == 0.0`
- `flutter analyze` must be clean after every prompt.
- `lib/config/secrets.dart` is gitignored — never commit it; it contains `anthropicApiKey`
- Do not modify `club_service.dart`, `post_card.dart`, or `create_post_sheet.dart` unless explicitly discussed.