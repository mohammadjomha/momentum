import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/trip_data.dart';

class TripService {
  TripData _currentTrip = TripData.initial();
  Position? _lastPosition;
  Timer? _durationTimer;
  final List<double> _speedSamples = [];

  final StreamController<TripData> _tripDataController =
      StreamController<TripData>.broadcast();

  Stream<TripData> get tripDataStream => _tripDataController.stream;
  TripData get currentTrip => _currentTrip;

  void startTrip() {
    _currentTrip = TripData.initial();
    _lastPosition = null;
    _speedSamples.clear();

    // Update duration every second
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_currentTrip.startTime);
      _updateTrip(duration: elapsed);
    });
  }

  void updatePosition(Position position) {
    // Convert speed from m/s to km/h
    final speedKmh = (position.speed * 3.6).clamp(0.0, 400.0);

    _speedSamples.add(speedKmh);

    // Calculate distance if we have a previous position
    double addedDistance = 0;
    if (_lastPosition != null) {
      addedDistance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      ) / 1000; // Convert to km
    }

    // Calculate average speed
    final avgSpeed = _speedSamples.isEmpty
        ? 0.0
        : _speedSamples.reduce((a, b) => a + b) / _speedSamples.length;

    _updateTrip(
      currentSpeed: speedKmh,
      averageSpeed: avgSpeed,
      maxSpeed: speedKmh > _currentTrip.maxSpeed
          ? speedKmh
          : _currentTrip.maxSpeed,
      distance: _currentTrip.distance + addedDistance,
    );

    _lastPosition = position;
  }

  void _updateTrip({
    double? currentSpeed,
    double? averageSpeed,
    double? maxSpeed,
    double? distance,
    Duration? duration,
  }) {
    _currentTrip = _currentTrip.copyWith(
      currentSpeed: currentSpeed,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      distance: distance,
      duration: duration,
    );
    _tripDataController.add(_currentTrip);
  }

  void stopTrip() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void dispose() {
    _durationTimer?.cancel();
    _tripDataController.close();
  }
}
