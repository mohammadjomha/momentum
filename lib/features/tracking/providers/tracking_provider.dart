import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/trip_data.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/sensor_service.dart';
import '../../../data/services/trip_service.dart';
import '../../../data/services/trip_storage_service.dart';
import '../../trip_history/models/trip_model.dart';
import '../../trip_history/services/trip_history_service.dart';

enum TrackingStatus { idle, calibrating, tracking }

class TrackingState {
  final TrackingStatus status;
  final TripData tripData;
  final String? error;
  final bool gpsWeak;
  final int calibrationSecondsRemaining;

  const TrackingState({
    required this.status,
    required this.tripData,
    this.error,
    this.gpsWeak = false,
    this.calibrationSecondsRemaining = 0,
  });

  bool get isTracking => status == TrackingStatus.tracking;

  TrackingState copyWith({
    TrackingStatus? status,
    TripData? tripData,
    String? error,
    bool clearError = false,
    bool? gpsWeak,
    int? calibrationSecondsRemaining,
  }) {
    return TrackingState(
      status: status ?? this.status,
      tripData: tripData ?? this.tripData,
      error: clearError ? null : (error ?? this.error),
      gpsWeak: gpsWeak ?? this.gpsWeak,
      calibrationSecondsRemaining:
          calibrationSecondsRemaining ?? this.calibrationSecondsRemaining,
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final LocationService _locationService;
  final TripService _tripService;
  final TripStorageService _storageService;
  final TripHistoryService _historyService;
  final SensorService _sensorService;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<TripData>? _tripDataSub;
  Timer? _calibrationTimer;

  // Accumulated route points for the current trip
  final List<RoutePoint> _routePoints = [];

  TrackingNotifier()
      : _locationService = LocationService(),
        _tripService = TripService(),
        _storageService = TripStorageService(),
        _historyService = TripHistoryService(),
        _sensorService = SensorService(),
        super(TrackingState(
          status: TrackingStatus.idle,
          tripData: TripData.initial(),
        ));

  Future<void> startTracking() async {
    state = state.copyWith(clearError: true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          error: permission == LocationPermission.deniedForever
              ? 'Location permanently denied. Enable it in Settings.'
              : 'Location permission denied.',
        );
        return;
      }

      _routePoints.clear();

      // Start GPS immediately — position stream begins flowing right away.
      await _locationService.startTracking();

      _positionSub = _locationService.positionStream.listen(
        (position) {
          // Only accumulate route points; trip stats are deferred until
          // calibration completes and startTrip() is called below.
          _routePoints.add(RoutePoint(
            lat: position.latitude,
            lng: position.longitude,
            speed: (position.speed * 3.6).clamp(0.0, 400.0),
          ));
        },
        onError: (e) => state = state.copyWith(error: 'GPS error: $e'),
      );

      // Start calibration countdown UI (3 → 0) while sensor calibration runs.
      state = state.copyWith(
        status: TrackingStatus.calibrating,
        calibrationSecondsRemaining: 3,
      );

      int remaining = 3;
      _calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        remaining--;
        state = state.copyWith(calibrationSecondsRemaining: remaining);
        if (remaining <= 0) {
          timer.cancel();
          _calibrationTimer = null;
        }
      });

      // Run sensor calibration (takes 3 seconds); GPS is already flowing.
      await _sensorService.startTracking();

      // Cancel any still-running countdown timer after calibration resolves.
      _calibrationTimer?.cancel();
      _calibrationTimer = null;

      // Now begin trip stat recording.
      _tripService.startTrip();

      // Re-attach the position listener to also drive trip stats.
      await _positionSub?.cancel();
      _positionSub = _locationService.positionStream.listen(
        (position) {
          _tripService.updatePosition(position);
          _routePoints.add(RoutePoint(
            lat: position.latitude,
            lng: position.longitude,
            speed: (position.speed * 3.6).clamp(0.0, 400.0),
          ));
        },
        onError: (e) => state = state.copyWith(error: 'GPS error: $e'),
      );

      _tripDataSub = _tripService.tripDataStream.listen(
        (tripData) => state = state.copyWith(
          tripData: tripData,
          gpsWeak: _tripService.lastReadingInvalid,
        ),
      );

      state = state.copyWith(
        status: TrackingStatus.tracking,
        calibrationSecondsRemaining: 0,
      );
    } catch (e) {
      _calibrationTimer?.cancel();
      _calibrationTimer = null;
      state = state.copyWith(
        status: TrackingStatus.idle,
        error: _friendlyError(e.toString()),
        calibrationSecondsRemaining: 0,
      );
    }
  }

  Future<void> stopTracking() async {
    _calibrationTimer?.cancel();
    _calibrationTimer = null;

    // Cancel subscriptions first so no more position updates come in
    await _positionSub?.cancel();
    await _tripDataSub?.cancel();
    _positionSub = null;
    _tripDataSub = null;

    await _locationService.stopTracking();
    final SensorSummary summary = await _tripService.stopTrip();

    final tripData = state.tripData.copyWith(
      hardBrakeCount: summary.hardBrakeCount,
      peakBrakeG: summary.peakBrakeG,
      avgBrakeG: summary.avgBrakeG,
      hardAccelCount: summary.hardAccelCount,
      peakAccelG: summary.peakAccelG,
      avgAccelG: summary.avgAccelG,
      totalCornerCount: summary.totalCornerCount,
      rightCornerCount: summary.rightCornerCount,
      leftCornerCount: summary.leftCornerCount,
      sharpestCornerG: summary.sharpestCornerG,
      avgCorneringG: summary.avgCorneringG,
    );
    final routeSnapshot = List<RoutePoint>.from(_routePoints);
    _routePoints.clear();

    // Reset UI immediately — don't await saves
    state = TrackingState(
      status: TrackingStatus.idle,
      tripData: TripData.initial(),
    );

    if (tripData.duration.inSeconds > 5) {
      // Fire-and-forget saves (non-blocking)
      _storageService.saveTrip(tripData);
      _saveToFirestore(tripData, routeSnapshot);
    }
  }

  Future<void> _saveToFirestore(TripData tripData, List<RoutePoint> route) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String username = '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        username = userDoc.data()?['username'] as String? ?? '';
      }

      final tripId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final trip = TripModel(
        id: tripId,
        uid: user.uid,
        username: username,
        date: tripData.startTime,
        maxSpeed: tripData.maxSpeed,
        avgSpeed: tripData.averageSpeed,
        distance: tripData.distance,
        duration: tripData.duration,
        route: route,
      );

      await _historyService.saveTrip(trip);
    } catch (_) {
      // Firestore save failure is non-fatal — local save already done
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('permission')) {
      return 'Location permission denied. Enable it in Settings.';
    }
    return 'Could not start GPS. Try again.';
  }

  @override
  void dispose() {
    _calibrationTimer?.cancel();
    _positionSub?.cancel();
    _tripDataSub?.cancel();
    _locationService.dispose();
    _tripService.dispose();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>(
  (ref) => TrackingNotifier(),
);