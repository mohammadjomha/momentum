﻿﻿# Momentum â€” CLAUDE.md

## What this app is
Momentum is a Flutter-based automotive enthusiast app â€” "Strava for cars."
It tracks real-time driving statistics, stores trip history with route visualization,
and has a leaderboard/social layer.
This is a capstone project for Lebanese American University (CSC department).

## Current state
The following already exists and works â€” do not rewrite unless explicitly asked:
- `lib/data/services/location_service.dart` â€” GPS tracking via geolocator, Haversine distance â€” platform-specific settings: AndroidSettings (200ms interval) and AppleSettings(bestForNavigation, automotiveNavigation)
- `lib/data/services/trip_service.dart` â€” avg speed, max speed, distance, duration calculation â€” EMA removed, 2 km/h zero-clamp, lastReadingInvalid getter â€” no sensor dependency
- `lib/data/services/sensor_service.dart` â€” magnitude-based G-force detection at 20 Hz, brake/accel state machines (0.18G threshold, 300ms duration guard), speed-gated via updateSpeed(). Cornering removed entirely. SensorService is owned by TrackingNotifier only â€” TripService has no sensor dependency.
- `lib/data/services/weather_service.dart` â€” fetches weather from Open-Meteo API using lat/lng, maps WMO codes to labels and smoothness multipliers, returns null on error
- `lib/data/models/trip_data.dart` â€” trip data model, cornering fields removed, weather fields and smoothnessScore added
- `lib/features/tracking/screens/tracking_screen.dart` â€” main tracking screen, display lerp 0.4, zero-snap, fixed-height timer pill â€” debug panel removed
- `lib/features/tracking/widgets/speedometer_widget.dart` â€” speedometer gauge
- `lib/features/tracking/widgets/stat_card.dart` â€” stat display cards
- `lib/features/tracking/widgets/gps_status_indicator.dart` â€” yellow pill indicator shown when GPS speed reading is invalid
- `lib/features/tracking/providers/tracking_provider.dart` â€” Riverpod provider for tracking state, exposes gpsWeak from lastReadingInvalid, owns the sole SensorService instance, runs weather fetch and smoothness score computation at trip end
- `lib/core/theme/app_theme.dart` â€” app theme; snackBarTheme set globally: backgroundColor surfaceHigh, contentTextStyle white, actionTextColor accent, floating behavior, 8px rounded corners
- `lib/core/providers/auth_provider.dart` â€” single `authStateProvider` (StreamProvider<User?>) streaming `FirebaseAuth.instance.authStateChanges()`; all per-user providers must `ref.watch(authStateProvider)` â€” never read `currentUser?.uid` synchronously
- `lib/features/trip_history/screens/trip_detail_screen.dart` â€” trip detail with Google Maps route visualization, smoothness/weather/braking/accel cards â€” cornering card removed; braking card label reads “Total Brakes” (field: `hardBrakeCount`); accel card label reads “Quick Accels” (field: `hardAccelCount`); card order: map â€” stats â€” smoothness â€” weather â€” braking â€” accel; trash icon in app bar opens confirmation dialog, calls deleteTrip then forceRefresh() on leaderboard, pops back with “Trip deleted” snackbar; “Share Trip” button opens a modal bottom sheet via `_showShareOptions()` with two options: “Share Card” (existing flow) and “Camera Overlay” (pushes CameraOverlayScreen)
- `lib/core/utils/weather_utils.dart` â€” `weatherIcon(int wmoCode) → IconData` maps WMO code ranges to Material icons (wb_sunny, cloud, foggy, umbrella, ac_unit, thunderstorm); `weatherIconCodePoint(int wmoCode) → int` is the canvas-safe codepoint variant used by CameraOverlayPainter
- `lib/features/trip_history/widgets/camera_overlay_painter.dart` â€” CustomPainter that composites a camera photo with route polyline and trip stats overlay; layout matches share_trip_card.dart proportions (78% top / 11% mid / 11% branding, left 65% route / right 35% stats); accepts `weatherCode` (int, default 0) and uses `weatherIconCodePoint` for the canvas-drawn weather icon; do not modify drawing/layout logic without discussion
- `lib/features/trip_history/screens/camera_overlay_screen.dart` â€” ConsumerStatefulWidget; opens camera via image_picker, decodes photo, renders CameraOverlayPainter full-screen inside RepaintBoundary; bottom bar has “Save to Gallery” (gal) and “Share” (share_plus) buttons; captures at pixelRatio 3.0
- `lib/features/leaderboard/screens/leaderboard_screen.dart` â€” leaderboard screen, queries trips directly, groups by uid client-side, time filter toggle (Today / This Week / This Month / All Time), ranked by smoothnessScore â†’ distance â†’ avgSpeed, current user highlighted with teal border; list wrapped in `AnimatedOpacity` (opacity 0.4 when `isRefreshing`, 1.0 otherwise, 150ms) for subtle visual feedback during filter switches; title standardized to design system: `AppTheme.accent`, fontSize 13, FontWeight.w800, letterSpacing 3
- `lib/features/leaderboard/providers/leaderboard_provider.dart` â€” StateNotifierProvider holding selected time filter and fetched entries; `isRefreshing` bool added to `LeaderboardState` (set true at start of `_load`, false at end on both success and error paths); all-time trip query cached in `allTimeByUid` state â€” `needsAllTime` guard fires the full-collection scan exactly once per session (`allTimeByUid.isEmpty && filter != allTime`); `copyWith` null-guard preserves existing `allTimeByUid` on cache-hit paths; `_fetchCarModels` parallelized with `Future.wait` and backed by `_carByUid` session cache on the notifier â€” user docs never re-fetched across filter switches; forceRefresh() clears allTimeByUid cache then calls _load() â€” used after trip deletion to prevent stale leaderboard data
- `lib/features/profile/screens/profile_screen.dart` â€” user profile, car details, stats, maintenance section, sign out; tracks `_lastUid` and calls `_resetHydration()` via `ref.listen(authStateProvider)` when uid changes; `_hydrateIfNeeded()` called synchronously from `ref.read(userProfileProvider).valueOrNull` in `initState` (zero-frame flash of empty fields) and from `ref.listen(userProfileProvider)` in `build()` as fallback for first-ever launch; `profileAsync.when` has `skipLoadingOnReload: true, skipLoadingOnRefresh: true` â€” subsequent tab visits never show the full-screen spinner, stale data shown instantly while Firestore catches up; `nhtsaMakesProvider` and `nhtsaModelsProvider` are both non-autoDispose â€” `load()` guarded by `loadState != NhtsaLoadState.loaded` so NHTSA HTTP fires exactly once per session; model dropdown skips `loadForMake` on re-entry when `forMake == profile.carMake && loadState == loaded`, setting `_selectedModel` synchronously with no spinner; `NhtsaLoadState.idle` no longer treated as loading in `_buildMakeDropdown`; `_signOut()` calls `ref.invalidate()` on all six per-user providers as a safety net
- `lib/features/profile/services/nhtsa_service.dart` â€” NHTSA API for make/model dropdowns
- `lib/features/profile/providers/profile_provider.dart` â€” Riverpod provider for profile state; `userProfileProvider` watches `authStateProvider` via `.valueOrNull?.uid` to prevent AsyncLoading propagation
- `lib/features/profile/models/maintenance_entry.dart` â€” MaintenanceEntry model with toMap()/fromDoc()
- `lib/features/profile/providers/maintenance_provider.dart` â€” StateNotifierProvider streaming maintenance entries; addEntry/updateEntry/deleteEntry; `MaintenanceNotifier` holds `StreamSubscription? _sub`, uses `resubscribe(String? uid)` driven by `ref.listen(authStateProvider)` with `fireImmediately: true`, cancels subscription in `dispose()` â€” no listener leak
- `lib/features/profile/widgets/maintenance_bottom_sheet.dart` â€” add/edit bottom sheet with type presets, date pickers, notes
- `lib/features/trip_history/widgets/share_card_painter.dart` â€” CustomPainter for route normalization and drawing (do not modify drawing logic without discussion)
- `lib/features/trip_history/widgets/share_trip_card.dart` â€” 1080Ã—1920 share card widget; weather and smoothness follow the same hide conditions as trip detail (hide if empty/zero)
- `lib/features/clubs/services/club_service.dart` â€” all club, post, comment, like, pin logic; member management: `updateClub`, `promoteMember`, `demoteAdmin`, `removeMember`
- `lib/features/clubs/providers/club_provider.dart` â€” userClubsProvider, allClubsProvider, clubDetailProvider, clubPostsProvider, clubCommentsProvider; `userClubsProvider` watches `authStateProvider`
- `lib/features/clubs/providers/club_leaderboard_provider.dart` â€” ClubLeaderboardNotifier (StateNotifierProvider.family, autoDispose, keyed by clubId); ClubLeaderboardState; full parity with global leaderboard: stale-while-revalidate, `_carByUid` session cache, `allTimeByUid` cache, client-side member filtering via batched whereIn queries (chunks of 30)
- `lib/features/clubs/widgets/post_card.dart` â€” feed post card, CommentsSheet, EditPostSheet
- `lib/features/clubs/widgets/create_post_sheet.dart` â€” new post bottom sheet (image + caption)
- `lib/features/clubs/screens/clubs_hub_screen.dart` â€” MY CLUBS + DISCOVER tabs, embedded mode; AppBar removed, replaced with SafeArea + Column manual layout matching other screens; title standardized to design system: `AppTheme.accent`, fontSize 13, FontWeight.w800, letterSpacing 3; TabBar and TabBarView remain functional driven by existing `_tabController`
- `lib/features/clubs/screens/club_detail_screen.dart` â€” feed + leaderboard tabs, pin, join/leave/delete; gear icon visible to owner and admin; settings sheet has three tiles: Edit club (owner only), Members (owner or admin), Delete club (owner only); edit club bottom sheet pre-fills name/description, calls `updateClub`; members sheet fetches all member docs in parallel, shows owner/admin badges, owner can promote/demote/remove, admins can remove regular members only; posts and comments from removed members persist in the feed; title color standardized to `AppTheme.accent`
- `lib/features/trip_history/services/coaching_service.dart` â€” calls Claude API at trip end with trip stats, returns a coaching note string; falls back to a static no-sensor message when sensor data is unavailable; result stored as `coachingNote` (String) on trip document; lazy generation: only called once and cached, not regenerated on re-open
- `lib/features/trip_history/providers/trip_history_provider.dart` â€” StreamProvider watching `authStateProvider`; passes uid explicitly to `TripHistoryService.tripsStream(uid)`
- `lib/features/friends/services/friend_service.dart` â€” sends/accepts/declines friend requests, removes friends, streams incoming pending requests; uses `friend_requests` Firestore collection and `friends` array field on `users/{uid}`
- `lib/features/friends/models/friend_entry.dart` â€” FriendEntry model (uid, username, carModel)
- `lib/features/friends/models/friend_request.dart` â€” FriendRequest model (requestId, fromUid, fromUsername, toUid, status, createdAt)
- `lib/features/friends/providers/friend_provider.dart` â€” Riverpod providers for friend list, pending received requests, and send/accept/decline/remove actions; both StreamProviders watch `authStateProvider`
- `lib/features/leaderboard/widgets/user_mini_card.dart` â€” bottom sheet showing a user's profile mini-card (username, car, stats); triggered by tapping a leaderboard entry
- `lib/features/friends/screens/friend_comparison_screen.dart` â€” side-by-side stat comparison between current user and a friend; route `/friends/compare/:friendUid`

## Architecture â€” feature-based structure
New features go under `lib/features/`:

```
lib/
â”œâ”€â”€ config/
â”‚   â””â”€â”€ secrets.dart          # gitignored â€” anthropicApiKey constant
â”œâ”€â”€ core/
â”‚   â”œâ”€â”€ theme/app_theme.dart
â”‚   â”œâ”€â”€ providers/auth_provider.dart
â”‚   â”œâ”€â”€ utils/weather_utils.dart
â”‚   â””â”€â”€ constants/
â”œâ”€â”€ data/
â”‚   â”œâ”€â”€ models/
â”‚   â””â”€â”€ services/
â”œâ”€â”€ features/
â”‚   â”œâ”€â”€ tracking/        # Live drive screen
â”‚   â”œâ”€â”€ trip_history/    # Past trips, route map, stats
â”‚   â”œâ”€â”€ leaderboard/     # Rankings with time filters
â”‚   â”œâ”€â”€ profile/         # User profile, car details, maintenance log
â”‚   â”œâ”€â”€ friends/         # Friend system, comparison screen
â”‚   â”œâ”€â”€ ai_coach/        # AI driving coach service
â”‚   â””â”€â”€ auth/            # Login, register screens
â””â”€â”€ shared/
    â””â”€â”€ widgets/         # Reusable components
```

## Tech stack
- Flutter 3.10.7+
- State management: Riverpod
- Local storage: Hive
- Backend: Firebase (Firestore + Auth + Storage)
- Map: google_maps_flutter (trip detail screen) â€” dark style via JSON, teal polyline, canvas-drawn circle markers
- GPS: geolocator (already in use)
- Motion sensors: sensors_plus
- Routing: go_router
- Weather: Open-Meteo API (free, no key required) â€” fetched at trip end using midpoint GPS coordinate
- Share: share_plus ^10.1.4 â€” shares the trip card PNG via native share sheet
- Temp files: path_provider ^2.1.4 â€” used to write the share card PNG to a temp directory before sharing
- AI coach: Anthropic Claude API via `anthropic` Dart SDK â€” key stored in `lib/config/secrets.dart` (gitignored)
- Notifications: shared_preferences â€” used to track which friend-request IDs have already triggered an Android notification, preventing duplicates on app relaunch
- Image picker: image_picker ^1.1.2 â€” used in CreatePostSheet for camera and gallery image selection, and in CameraOverlayScreen to capture the overlay photo
- Gallery saver: gal ^1.1.0 â€” saves the camera overlay PNG to the device photo library
- Launcher icons: flutter_launcher_icons ^0.14.1 (dev) â€” generates Android adaptive icons and iOS icons from `assets/images/launcher_icon.png`

### Map implementation notes
- `google_maps_flutter` is the active map package â€” `flutter_map` and `latlong2` remain in pubspec.yaml but are not used for rendering
- Dark map style is applied via a JSON style string constant in `trip_detail_screen.dart`
- Route polyline: `Color(0xFF00D4A0)` (teal), width 4
- Start marker: `speedGreen` fill + white border (canvas-drawn circle, no default pin)
- End marker: white fill + `accent` teal border (canvas-drawn circle, no default pin)
- Markers use `anchor: Offset(0.5, 0.5)` â€” circle centres on the coordinate

### GPS pipeline notes
- Android: AndroidSettings(accuracy: high, distanceFilter: 0, intervalDuration: 200ms)
- iOS: AppleSettings(accuracy: bestForNavigation, activityType: automotiveNavigation, distanceFilter: 0, pauseLocationUpdatesAutomatically: false)
- No app-level smoothing â€” raw GPS speed used directly (hardware-filtered by platform)
- Zero-clamp: speeds below 2 km/h are treated as 0 to eliminate stationary noise
- Invalid readings (position.speed < 0) are skipped entirely â€” trip stats not updated, last valid speed held
- Display lerp: factor 0.4 at 60fps in _AnimatedSpeedometer â€” converges to target in ~150ms

### Sensor implementation notes
- Sensor: `userAccelerometerEventStream` via `sensors_plus`, throttled to 20 Hz
- Approach: magnitude-only (`sqrt(xÂ²+yÂ²+zÂ²) / 9.81`) â€” orientation-independent, no axis mapping or calibration needed
- Brake threshold: 0.18G sustained >= 300ms, only attributed when GPS speed is decreasing
- Accel threshold: 0.18G sustained >= 300ms, only attributed when GPS speed is increasing
- Cornering: removed entirely â€” magnitude cannot reliably distinguish corners from road bumps without axis mapping
- `SensorService` owned exclusively by `TrackingNotifier` â€” do not add it back to `TripService`
- `TripService` has no sensor dependency â€” `stopTrip()` is `void`, sensor summary comes from `_sensorService.stopTracking()` in the provider
- iOS motion permission: `Permission.sensors` via `permission_handler` required before stream starts

### Weather implementation notes
- Provider: Open-Meteo API â€” `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,weather_code`
- No API key required
- Fetched once at trip end using the midpoint coordinate of the route array
- WMO weather code mapped to a human-readable label (e.g. "Clear", "Partly Cloudy", "Heavy Rain") and a smoothness multiplier
- Weather multiplier scale (applied to smoothness score):
  - Clear / Mostly Clear (codes 0â€“2): 1.00
  - Partly Cloudy / Overcast (codes 3, 45, 48): 1.05
  - Light Rain / Drizzle (codes 51â€“57, 61): 1.10
  - Moderate Rain (codes 63, 80â€“81): 1.15
  - Heavy Rain / Thunderstorm (codes 65, 82, 95â€“99): 1.25
  - Snow / Sleet (codes 71â€“77): 1.20
- A perfect drive in clear weather still scores 100 â€” multiplier only makes it easier to reach 100 in bad conditions
- Stored fields on trip document: `weatherCode` (int), `weatherLabel` (String), `weatherTempC` (double), `weatherMultiplier` (double)
- Displayed in trip detail as a weather card; hidden for old trips where weatherLabel is empty
- Weather icon is WMO-code-driven via `weatherIcon(wmoCode)` in `lib/core/utils/weather_utils.dart` â€” used as a Flutter `Icon` widget in trip detail and share card, and as a canvas codepoint in the camera overlay painter

### Smoothness score notes
- Computed once at trip end, stored as `smoothnessScore` (double, 0â€“100) on the trip document
- Formula (in `_computeSmoothnessScore` inside `tracking_provider.dart`):
  - peakBrakeG and peakAccelG are clamped to 1.0G max before scoring to filter out sensor noise
  - Start at 100
  - If peakBrakeG > 0.5G (clamped): deduct `(peakBrakeG - 0.5) * 30`
  - If avgBrakeG > 0.25G: deduct `(avgBrakeG - 0.25) * 25`
  - If peakAccelG > 0.6G (clamped): deduct `(peakAccelG - 0.6) * 20`
  - Clamp to 0â€“100, then multiply by weatherMultiplier and clamp again
- `finalScore = (score.clamp(0, 100) * weatherMultiplier).clamp(0, 100)`
- No count-based penalties â€” only G-force intensity matters, so longer trips are not unfairly penalized
- Stored on trip document and used directly by leaderboard queries â€” not recomputed at read time
- Displayed in trip detail as `_SmoothnessCard` (â‰¥90 â†’ "Excellent", â‰¥75 â†’ "Good", â‰¥60 â†’ "Average", <60 â†’ "Needs Work"); hidden when smoothnessScore == 0.0

### Leaderboard notes
- Queries `trips` collection directly â€” no separate leaderboard collection
- Filters by `date` range based on selected time filter, then groups by uid client-side keeping each user's best trip
- Trips shorter than 0.5 km are excluded from leaderboard ranking to filter out accidental/test trips
- Ranked by: **average smoothnessScore across all qualifying trips** (not best single trip score) â†’ distance â†’ avgSpeed as tiebreakers
- `allTimeByUid` map cached in state â€” all-time trip query fires exactly once per session (`needsAllTime` guard: `allTimeByUid.isEmpty && filter != allTime`); `copyWith` null-guard preserves cached value on subsequent filter switches
- Car model fetched from `users` collection via `_fetchCarModels`: batches parallelized with `Future.wait`; results cached in `_carByUid` map on the notifier for the session â€” no re-fetch on filter switches
- Time filter defaults to This Week
- Current user's entry highlighted with `AppTheme.accent.withOpacity(0.3)` border
- Tapping a leaderboard entry opens `user_mini_card.dart` bottom sheet with that user's profile mini-card
- `_queryTrips` uses only `.orderBy('date', descending: false)` â€” the extra orderBy clauses on smoothnessScore, distance, and avgSpeed were removed because Firestore silently excludes documents where an ordered field does not exist, which was causing old trips (without smoothnessScore) to be dropped entirely
- No composite Firestore index required â€” single-field date index is sufficient
- Stale-while-revalidate caching: spinner only shown on first load when `entries` is empty; switching filter tabs shows the previous filter's cached entries instantly while fresh data loads in the background (`isLoading` condition in `_Body` is `state.isLoading && state.entries.isEmpty`)

### AI driving coach notes
- Service: `lib/features/trip_history/services/coaching_service.dart`
- Called once at trip end from `tracking_provider.dart` immediately after smoothness score computation
- Sends: distance, duration, maxSpeed, avgSpeed, smoothnessScore, peakBrakeG, avgBrakeG, peakAccelG, avgAccelG, weatherLabel
- Result stored as `coachingNote` (String) on the trip Firestore document
- Lazy: if `coachingNote` is already non-empty on a trip document, it is displayed as-is â€” the API is not called again
- Short-trip guard: if distance < 0.5 km, returns static "Trip too short for coaching" message without an API call and without writing to Firestore
- No-sensor guard: if peakBrakeG == 0 and peakAccelG == 0, returns a static informational message without an API call and without writing to Firestore
- Bug fix: the no-sensor static message was previously written to Firestore unconditionally; both static paths now return early before the Firestore update
- Displayed in trip detail screen as a coaching card below the accel card; hidden when `coachingNote` is empty
- API key lives in `lib/config/secrets.dart` â€” this file is gitignored; do not commit it

### Friend system notes
- `friend_service.dart` â€” `sendRequest(toUid)`, `acceptRequest(requestId)`, `declineRequest(requestId)`, `removeFriend(friendUid)`, `streamPendingReceived()`, `streamFriends()`
- Friend requests stored in `friend_requests/{requestId}` with fields: fromUid, fromUsername, toUid, status, createdAt
- Accepted friends stored as a `friends: [uid, ...]` array on each user's `users/{uid}` document (both sides updated atomically)
- Android notification fires for each new incoming friend request; SharedPreferences key `notified_request_ids` (Set\<String\>) prevents duplicate notifications across app restarts
- `user_mini_card.dart` bottom sheet: shows username, car make/model/year, total trips, total distance, and a Send Friend Request button (button hidden if already friends or request already sent)
- Friend comparison screen at `/friends/compare/:friendUid`: fetches both users' trip stats from Firestore and renders a side-by-side card layout using the design system colors

### Launcher icons notes
- Source image: `assets/images/launcher_icon.png` â€” square PNG, should have transparent or dark background
- Foreground layer for Android adaptive icons: `assets/images/launcher_icon_foreground.png`
- Adaptive icon background color: `#0D0D0D` (matches `AppTheme.background`)
- `min_sdk_android: 21` â€” adaptive icons generated for API 26+; legacy mipmaps generated for API 21â€“25
- Generated files: `android/app/src/main/res/mipmap-*/launcher_icon.png` + `mipmap-anydpi-v26/launcher_icon.xml`; iOS `Runner/Assets.xcassets/AppIcon.appiconset/`
- To regenerate after changing the source image: `dart run flutter_launcher_icons`
- Android launch theme (`LaunchTheme`) uses a plain `#0D0D0D` `launch_background` drawable (no splash image) â€” flutter_native_splash remnants were fully removed; do not re-add `windowSplashScreenAnimatedIcon` or `@drawable/splash` references

### Google Maps API key injection
- **Android (local):** Add `GOOGLE_MAPS_API_KEY=<key>` to `android/local.properties` (gitignored). `build.gradle.kts` loads `local.properties` via `java.util.Properties` and injects via `manifestPlaceholders`.
- **iOS (local):** Not applicable â€” dev machine is Windows, no Xcode available.
- **CI (both platforms):** GitHub Actions secret `GOOGLE_MAPS_API_KEY`. Android: appended to `android/local.properties` before build. iOS: patched directly into `ios/Runner/Info.plist` via `PlistBuddy` before build â€” no Xcode user-defined settings needed.
- Do not suggest Xcode-based key setup steps. All iOS key injection is CI-only via PlistBuddy.

## Firebase setup

### Authentication
- Provider: Firebase Email/Password only
- Registration fields: email, password, username only â€” no car field on registration
- Username stored in Firestore under users/{uid} â€” not in Firebase Auth
- Car details are filled in later on the profile screen
- Login: email + password only
- Username is the display identity across leaderboard and profile

### Firestore collections
```
users/{uid}
  - username, email, totalDistance, totalTrips, createdAt
  - car: { make, model, year, trim (optional), notes (optional) }
  - friends: [ uid, ... ]  â† array of accepted friend UIDs

users/{uid}/maintenance/{entryId}
  - type (String â€” e.g. "Oil Change", "General Checkup", "Yearly Inspection")
  - lastDoneDate (Timestamp)
  - nextDueDate (Timestamp, optional)
  - notes (String, optional)
  - createdAt (Timestamp)

trips/{tripId}
  - uid, username, date, maxSpeed, avgSpeed, distance, duration
  - route: [ {lat, lng, speed}, ... ]  â† for the map trace
  - hardBrakeCount, peakBrakeG, avgBrakeG
  - hardAccelCount, peakAccelG, avgAccelG
  - weatherCode (int), weatherLabel (String), weatherTempC (double), weatherMultiplier (double)
  - smoothnessScore (double, 0â€“100)
  - coachingNote (String) â€” AI driving coach feedback, generated lazily at trip end

friend_requests/{requestId}
  - fromUid, fromUsername, toUid, status ("pending" | "accepted" | "declined"), createdAt

clubs/{clubId}
  - name, description, ownerUid (uid), ownerUsername (String), adminUids (List<String>), memberUids (List<String>), pinnedPostId (String?), createdAt

clubs/{clubId}/posts/{postId}
  - authorUid, authorUsername, caption (String?), imageUrl (String?), likedBy (List<String>), likeCount (int), commentCount (int), createdAt, editedAt (DateTime?)

clubs/{clubId}/posts/{postId}/comments/{commentId}
  - authorUid, authorUsername, text, createdAt, editedAt (DateTime?)

users/{uid}
  - added clubIds: List<String>
```

Note: There is no separate `leaderboard` collection. The leaderboard queries the `trips` collection directly. Marketplace feature was scrapped â€” no `listings` collection.

### User profile â€” car details (COMPLETE)
- Profile screen: `lib/features/profile/screens/profile_screen.dart`
- Car fields: Make (NHTSA API dropdown), Model (cascades from Make via NHTSA), Year (1970â€“2025 hardcoded dropdown), Trim (optional text), Mods/Notes (optional multiline)
- NHTSA service: `lib/features/profile/services/nhtsa_service.dart` â€” fetches makes and models from the NHTSA public API
- Reads/writes to Firestore `users/{uid}` and `users/{uid}.car`
- Stat tiles on profile: total trips + total distance (read-only, from Firestore)
- Friends section on profile screen: shows accepted friends list and pending received friend requests; accept/decline actions inline
- Sign out button on profile screen

### Firebase rules
- Firestore and Storage are in test mode during development
- Tighten rules before any public demo if needed
- firebase_options.dart is auto-generated by FlutterFire CLI â€” do not manually edit it

## iOS support
- `ios/Podfile` â€” iOS 13.0 deployment target, `permission_handler` macros enabled
- `ios/Runner/Info.plist` â€” location + motion permission keys, `UIBackgroundModes: location`, `GMSApiKey` placeholder (patched at CI build time), `NSPhotoLibraryAddUsageDescription` for save-to-gallery on share, `NSCameraUsageDescription` for camera overlay feature
- `ios/Runner/AppDelegate.swift` â€” calls `GMSServices.provideAPIKey(...)` reading from `Info.plist`
- `GoogleService-Info.plist` â€” injected at CI build time via GitHub Actions secret (not committed)
- GitHub Actions workflow `iOS-ipa-build` â€” manual trigger, produces unsigned IPA artifact

## Design system â€” strict, do not deviate

### Color palette
```dart
static const background    = Color(0xFF0D0D0D);
static const surface       = Color(0xFF1A1A1A);
static const surfaceHigh   = Color(0xFF222222);
static const accent        = Color(0xFF00D4A0);  // teal â€” primary accent
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
- Premium AMG-inspired aesthetic â€” precise, technical, clean
- Glassmorphism-style stat cards with subtle borders (Color(0xFF00D4A0).withOpacity(0.15))
- Arc-based speedometer using CustomPainter â€” NOT a simple progress indicator
- Smooth number animations using AnimatedSwitcher or Tween
- Map route trace: teal (#00D4A0) polyline on dark Google Maps style (not OpenStreetMap)
- Typography: clean, minimal â€” no decorative fonts

## Features status

### Complete
- Auth screens â€” register (email, password, username) + login
- UI modernization â€” arc speedometer, glass stat cards on tracking screen
- Trip history + storage â€” Hive + Firestore, trip list screen, trip detail screen
- Route visualization â€” Google Maps dark style, teal polyline, canvas circle markers
- Profile screen â€” NHTSA make/model dropdowns, year/trim/notes, stat tiles, sign out
- Speed tracking improvements â€” platform-specific GPS settings, zero-clamp, invalid reading guard, display lerp 0.4
- G-force sensor tracking â€” braking G and acceleration G (peak, avg, count) tracked via sensors_plus magnitude approach, saved to Hive and Firestore per trip, displayed in trip detail screen
- Cleanup â€” cornering removed from all models, services, and UI; debug panel removed from tracking screen
- Weather on trips â€” Open-Meteo fetch at trip end, stored on trip document, displayed as card in trip detail
- Smoothness score â€” computed at trip end, stored on trip document, displayed as card in trip detail
- Leaderboard â€” time filter toggle, queries trips directly, grouped by uid, ranked by avg smoothness score across all qualifying trips (â‰¥0.5 km); parallel queries for All Time; tapping entry opens user mini-card bottom sheet
- Maintenance log â€” section on profile screen, Firestore subcollection, add/edit/delete with undo snackbar, overdue/due-soon color coding
- Share Trip â€” “Share Trip” button opens a bottom sheet with two options: (1) Share Card: RepaintBoundary + RenderRepaintBoundary.toImage() pipeline captures a 1080Ã—1920 PNG off-screen; card layout: route polyline (teal, no map base layer) in left column (65% width), four stats stacked vertically in right column (35% width), weather + smoothness side by side below, branding strip (@username + Momentum) at bottom; shared via share_plus. (2) Camera Overlay: opens camera, composites trip stats over the photo, exports at 3x pixel ratio; Save to Gallery via gal, Share via share_plus.
- AI driving coach â€” `coaching_service.dart` calls Claude API at trip end with trip stats; result stored as `coachingNote` on trip document; lazy generation (generated once, not on re-open); falls back to a static message when sensor data is unavailable; displayed as a card in trip detail below the accel card
- Friend system â€” send/accept/decline/remove friends via `friend_service.dart`; `friend_requests` Firestore collection; `friends` array on `users/{uid}`; FriendEntry and FriendRequest models; `friend_provider.dart` Riverpod providers; friends list and pending received requests shown on profile screen; Android notifications for incoming friend requests using SharedPreferences to track notified request IDs
- User mini card â€” `user_mini_card.dart` bottom sheet showing username, car, stats; triggered from leaderboard entry tap; includes Send Friend Request button
- Friend comparison screen â€” `friend_comparison_screen.dart` at route `/friends/compare/:friendUid`; side-by-side stat comparison between current user and a friend; `parseTrips` filters `t.smoothnessScore > 0 && t.distance >= 0.5` so unscored/short trips are excluded from avg and best smoothness calculations
- Friend search â€” `lib/features/friends/screens/friend_search_screen.dart` â€” accessible from profile via `person_add_outlined` icon next to FRIENDS header; prefix/partial username search via Firestore range query (`isGreaterThanOrEqualTo` / `isLessThan`), 400ms debounce, limit 20; excludes current user from results; tapping a result opens `user_mini_card.dart` bottom sheet; registered at `/friends/search` in go_router
- Launcher icons â€” `flutter_launcher_icons` generates Android adaptive icons (`#0D0D0D` background + foreground layer) and iOS icons from `assets/images/launcher_icon.png`; Android launch theme shows plain dark background while Flutter engine initialises (no splash image)
- Delete trip â€” trash icon in trip detail app bar; confirmation dialog; deleteTrip(tripId, distanceKm) in trip_history_service.dart deletes trips/{tripId} and decrements totalTrips/totalDistance on users/{uid}; forceRefresh() on leaderboard clears allTimeByUid cache then reloads; StreamProvider in trip history auto-updates; "Trip deleted" snackbar shown after pop
- Social clubs â€” full feature. Create/join/leave/delete clubs (max 50 members). Clubs tab is the middle navbar item (replaced marketplace). Club discovery via search (prefix match) and browse-all (sorted by member count). Per-club feed with posts (text + optional image via image_picker, Firebase Storage at club_posts/{clubId}/{timestamp}.jpg). Posts support: like/unlike (toggleLike batch write), comments (subcollection clubs/{clubId}/posts/{postId}/comments with commentCount maintained via batch), edit caption (author only), delete (author or admin). Admin/owner can pin one post per club (pinnedPostId on club doc, shown above feed with teal pin indicator). CreatePostSheet (`lib/features/clubs/widgets/create_post_sheet.dart`) handles image picker (camera + gallery) and caption. PostCard (`lib/features/clubs/widgets/post_card.dart`) renders feed items with like/comment actions, three-dot menu, relative timestamps, “(edited)” label. CommentsSheet and EditPostSheet are inline widgets inside post_card.dart. Per-club leaderboard tab uses ClubLeaderboardNotifier (StateNotifierProvider.family, autoDispose), batched whereIn queries (chunks of 30), filtered to club members, same time filter toggles, full stale-while-revalidate and session caching parity with global leaderboard. ClubsHubScreen supports embedded mode (no back button when used as navbar tab). Owner can edit club name/description via bottom sheet. Owner and admins access settings sheet via gear icon in app bar; settings sheet tiles: Edit club (owner only), Members (owner or admin), Delete club (owner only). Members sheet: all members listed with owner/admin badges; owner can promote to admin, demote admin, or remove members; admins can remove regular members only; posts/comments from removed members persist in the feed.

### Known issues
- **Push notifications (iOS)** â€” Android works correctly: system notification fires on app launch for each overdue maintenance entry. iOS notifications are implemented (flutter_local_notifications, permission granted) but delivery is unreliable â€” notifications only appear when the app is backgrounded shortly after launch due to iOS foreground suppression. No code fix found without Xcode/APNs debugging access. Feature is functional on Android for demo purposes.
- **Page title vertical alignment** â€” title position appears slightly inconsistent across screens (Track vs History most noticeable). Root cause investigated: all four screens use identical `SafeArea(top: true)` + 16px top padding. Attempted fix via `SafeArea(top: false)` + `MediaQuery.of(context).padding.top + 16` did not resolve the visual difference, suggesting the cause may be Android status bar rendering or font metrics rather than padding. Reverted. Flag for follow-up if time permits before demo.

### Remaining (in build order)
1. **Animations and transitions** — polish screen and card transitions
2. **Edge cases** — remaining edge case handling across features
## Rules
- This is a capstone demo â€” prioritize working features and visual polish over edge case handling
- Always use the color palette above â€” no hardcoded colors outside app_theme.dart
- When adding packages, add them to pubspec.yaml and note they need `flutter pub get`
- Prefer StatelessWidget + Riverpod providers over StatefulWidget
- Do not modify location_service.dart or trip_service.dart unless the task specifically requires it
- Map: use `google_maps_flutter` â€” do not use `flutter_map` for new map work
- Keep all screens under `lib/features/<feature>/screens/` and widgets under `lib/features/<feature>/widgets/`
- Weather fetch and smoothness score computation both happen inside `tracking_provider.dart` at trip end â€” do not add weather or scoring logic to `trip_service.dart`
- SensorService lives in TrackingNotifier only â€” do not add back to TripService
- Do not modify `share_card_painter.dart` drawing logic without discussion
- Do not modify `camera_overlay_painter.dart` drawing/layout logic without discussion
- Weather and smoothness on the share card follow the same hide conditions as trip detail: hide weather if `weatherLabel.isEmpty`, hide smoothness if `smoothnessScore == 0.0`
- `flutter analyze` must be clean after every prompt.
- `lib/config/secrets.dart` is gitignored â€” never commit it; it contains `anthropicApiKey`
- Do not modify `club_service.dart`, `post_card.dart`, or `create_post_sheet.dart` unless explicitly discussed.
- All per-user Riverpod providers must `ref.watch(authStateProvider)` from `lib/core/providers/auth_provider.dart` â€” never call `FirebaseAuth.instance.currentUser?.uid` synchronously inside a provider build function.
- For any `ConsumerStatefulWidget` screen that can be disposed/recreated (all screens in non-IndexedStack nav): always pair `ref.listen` hydration with a synchronous `ref.read` in `initState` to catch cached provider values. `ref.read` is valid in `ConsumerState.initState()` â€” `ref` is wired before `initState` runs.