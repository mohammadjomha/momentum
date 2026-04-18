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

enum TrackingStatus { idle, tracking }

class TrackingState {
  final TrackingStatus status;
  final TripData tripData;
  final String? error;
  final bool gpsWeak;
  final SensorDebugState? sensorDebug;

  const TrackingState({
    required this.status,
    required this.tripData,
    this.error,
    this.gpsWeak = false,
    this.sensorDebug,
  });

  bool get isTracking => status == TrackingStatus.tracking;

  TrackingState copyWith({
    TrackingStatus? status,
    TripData? tripData,
    String? error,
    bool clearError = false,
    bool? gpsWeak,
    SensorDebugState? sensorDebug,
  }) {
    return TrackingState(
      status: status ?? this.status,
      tripData: tripData ?? this.tripData,
      error: clearError ? null : (error ?? this.error),
      gpsWeak: gpsWeak ?? this.gpsWeak,
      sensorDebug: sensorDebug ?? this.sensorDebug,
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

      await _locationService.startTracking();
      await _sensorService.startTracking();

      _tripService.startTrip();

      _positionSub = _locationService.positionStream.listen(
        (position) {
          final speedKmh = (position.speed * 3.6).clamp(0.0, 400.0);
          _sensorService.updateSpeed(speedKmh);
          _tripService.updatePosition(position);
          _routePoints.add(RoutePoint(
            lat: position.latitude,
            lng: position.longitude,
            speed: speedKmh,
          ));
        },
        onError: (e) => state = state.copyWith(error: 'GPS error: $e'),
      );

      _tripDataSub = _tripService.tripDataStream.listen(
        (tripData) => state = state.copyWith(
          tripData: tripData,
          gpsWeak: _tripService.lastReadingInvalid,
          sensorDebug: _sensorService.debugState,
        ),
      );

      state = state.copyWith(status: TrackingStatus.tracking);
    } catch (e) {
      state = state.copyWith(
        status: TrackingStatus.idle,
        error: _friendlyError(e.toString()),
      );
    }
  }

  Future<void> stopTracking() async {
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