```markdown
# Momentum

> Track every drive. Analyze every moment. Own your performance — real-time drive tracking, trip analytics, and a social layer for automotive enthusiasts.

![Flutter](https://img.shields.io/badge/Flutter-3.10.7+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)
![Riverpod](https://img.shields.io/badge/Riverpod-state%20management-00B4D8)

---

## About

Momentum is a Flutter mobile app that tracks real-time driving statistics using GPS and accelerometer sensors, stores full trip history with route visualization on Google Maps, and layers a social leaderboard and club system on top. Built for enthusiasts, new drivers, and performance coaches who want objective data on how they drive — not just where they went. Built as a capstone project for the **Lebanese American University — CSC Department**.

---

## Features

### 🚗 Live Tracking
- Arc-based speedometer with 60fps animated display (lerp factor 0.4, ~150ms convergence)
- Real-time stats: current speed, max speed, distance, elapsed time
- GPS validity indicator — yellow pill shown when speed reading is unreliable
- G-force detection at 20 Hz via `sensors_plus` — magnitude-based, orientation-independent
- Hard braking and quick acceleration events tracked with 0.18G threshold, 300ms sustain guard, speed-gated attribution
- Trips under 100m silently discarded at save time
- Android back-press guard with "Stop tracking?" confirmation dialog

### 📊 Trip History & Analysis
- Full trip list backed by Hive (local) + Firestore (cloud)
- Trip detail screen: Google Maps dark style, teal polyline route, canvas-drawn start/end markers
- Per-trip stat cards: max speed, avg speed, distance, duration, peak/avg braking G, peak/avg accel G
- **Smoothness score** (0–100): computed once at trip end from G-force intensity and weather conditions; displayed with grade labels (Excellent / Good / Average / Needs Work)
- **Weather card**: fetched from Open-Meteo at trip end using midpoint GPS coordinate; WMO code mapped to label and icon; weather multiplier makes it easier to score well in adverse conditions
- Delete trip: removes Firestore document, decrements user stats, invalidates leaderboard cache
- Share trip via two paths: (1) **Share Card** — 1080×1920 PNG with teal route polyline, stats, weather, branding; (2) **Camera Overlay** — composites trip stats over a live camera photo at 3× pixel ratio, save to gallery or share

### 🏆 Leaderboard & Social
- Global leaderboard ranked by **average smoothness score** across all qualifying trips (≥0.5 km) → distance → avg speed as tiebreakers
- Time filter toggles: Today / This Week / This Month / All Time
- Stale-while-revalidate caching — filter switches are instant, fresh data loads behind the scenes
- Tap any entry to open a user mini-card (username, car, stats, Send Friend Request button)
- **Social clubs**: create, join, discover (search + browse-all sorted by member count), up to 50 members per club
  - Per-club post feed: text + optional image, likes, comments, edit, delete
  - Pin one post per club (owner/admin only)
  - Per-club leaderboard tab with full parity to the global leaderboard
  - Role hierarchy: Owner → Admin → Member; owner can promote/demote/remove, admins can remove regular members

### 👥 Friends
- Send / accept / decline / remove friends
- Search users by username (prefix match, case-insensitive, 400ms debounce)
- Friend requests trigger Android notifications; SharedPreferences deduplication prevents repeat alerts
- **Friend comparison screen**: side-by-side stat cards (total trips, total distance, avg smoothness, best smoothness)

### 👤 Profile & Maintenance
- Car details via NHTSA API dropdowns (Make → Model cascade), year, trim, notes
- Username uniqueness enforced with a Firestore transaction (`usernames/{lower}` index); case-insensitive
- **Maintenance log**: add/edit/delete service entries (Oil Change, Yearly Inspection, etc.) with due dates; overdue/due-soon color coding; undo-delete snackbar
- Total trips and total distance stat tiles (live from Firestore)

### 🤖 AI Driving Coach
- Powered by Claude (Anthropic API) — called once at trip end with speed, distance, G-force, and weather data
- Coaching note stored on the trip document and displayed lazily; never regenerated on re-open
- Short-trip guard (<0.5 km) and no-sensor guard return static messages without API calls

---

## Tech Stack

| Category | Technology |
|---|---|
| Language | Dart 3.x |
| Framework | Flutter 3.10.7+ |
| State Management | Riverpod (StateNotifierProvider, StreamProvider) |
| Backend | Firebase — Firestore, Auth, Storage |
| Maps | google_maps_flutter (dark style, teal polyline, canvas markers) |
| Sensors & GPS | sensors_plus (20 Hz accelerometer), geolocator (200ms interval) |
| AI | Anthropic Claude API via `anthropic` Dart SDK |
| Local Storage | Hive |
| Routing | go_router |
| Weather | Open-Meteo API (no key required) |
| Sharing | share_plus, gal (gallery save), image_picker |
| Auth | Firebase Email/Password + email verification |

---

## Architecture

Feature-based folder structure — each feature owns its screens, widgets, providers, and services.

```
lib/
├── config/
│   └── secrets.dart          # gitignored — anthropicApiKey constant
├── core/
│   ├── theme/app_theme.dart
│   ├── providers/auth_provider.dart
│   ├── utils/weather_utils.dart
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
│   ├── clubs/           # Social clubs, feeds, per-club leaderboard
│   ├── ai_coach/        # AI driving coach service
│   └── auth/            # Login, register screens
└── shared/
    └── widgets/         # Reusable components
```

All per-user Riverpod providers watch `authStateProvider` from `core/providers/auth_provider.dart` — `FirebaseAuth.instance.currentUser?.uid` is never read synchronously inside a provider build.

---

## Getting Started

### Prerequisites

- Flutter 3.10.7 or later
- A Firebase project with **Email/Password Auth**, **Firestore**, and **Storage** enabled
- A Google Maps API key (Maps SDK for Android / iOS enabled)
- An Anthropic API key

### Clone & Install

```bash
git clone https://github.com/<your-username>/momentum.git
cd momentum
flutter pub get
```

### Configure Secrets

**1. Anthropic API key**

Create `lib/config/secrets.dart` (this file is gitignored — do not commit it):

```dart
const String anthropicApiKey = 'sk-ant-...';
```

**2. Google Maps API key (Android)**

Add to `android/local.properties` (gitignored):

```properties
GOOGLE_MAPS_API_KEY=AIza...
```

The `build.gradle.kts` reads this file and injects the key via `manifestPlaceholders`.

**3. Firebase**

Run FlutterFire CLI to generate `firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.

### Run

```bash
flutter run
```

---

## Firebase Setup

### Auth
Email/Password only. Email verification is required before users can access the app. Username uniqueness is enforced via a Firestore transaction on registration and profile save — the `usernames/{usernameLower}` collection acts as the uniqueness index.

### Firestore Collections

```
users/{uid}
  username, usernameLower, email, totalDistance, totalTrips, createdAt
  car: { make, model, year, trim?, notes? }
  friends: [uid, ...]

users/{uid}/maintenance/{entryId}
  type, lastDoneDate, nextDueDate?, notes?, createdAt

usernames/{usernameLower}
  uid

trips/{tripId}
  uid, username, date, maxSpeed, avgSpeed, distance, duration
  route: [{lat, lng, speed}, ...]
  hardBrakeCount, peakBrakeG, avgBrakeG
  hardAccelCount, peakAccelG, avgAccelG
  weatherCode, weatherLabel, weatherTempC, weatherMultiplier
  smoothnessScore, coachingNote

friend_requests/{requestId}
  fromUid, fromUsername, toUid, status, createdAt

clubs/{clubId}
  name, description, ownerUid, ownerUsername, adminUids, memberUids, pinnedPostId?, createdAt

clubs/{clubId}/posts/{postId}
  authorUid, authorUsername, caption?, imageUrl?, likedBy, likeCount, commentCount, createdAt, editedAt?

clubs/{clubId}/posts/{postId}/comments/{commentId}
  authorUid, authorUsername, text, createdAt, editedAt?
```

The leaderboard queries the `trips` collection directly — there is no separate leaderboard collection.

### Storage Rules
Firestore and Storage are currently in **test mode**. Tighten rules before any public-facing demo.

---

## Known Limitations

**iOS push notifications** — Android notifications work correctly (friend requests trigger system notifications; maintenance overdue alerts fire on launch). iOS delivery is unreliable due to foreground suppression — notifications only appear when the app is backgrounded shortly after launch. Resolving this requires APNs entitlement configuration via Xcode, which is unavailable on the Windows dev machine. Functional for demo on Android.

**Page title vertical alignment** — The title position is slightly inconsistent across the four main tab screens (Track vs History most noticeable). All screens use identical `SafeArea(top: true)` + 16px top padding. The root cause appears to be Android status bar rendering or font metrics rather than a padding issue — a direct fix attempt did not resolve it. Flagged for follow-up.

---

## License

This project is a student capstone submission. All rights reserved.

---

_Built as a capstone project for the Lebanese American University — CSC Department._
```
