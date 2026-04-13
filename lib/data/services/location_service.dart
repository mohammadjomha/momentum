import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamController<Position>? _positionStreamController;
  StreamSubscription<Position>? _positionSubscription;

  Stream<Position> get positionStream {
    _positionStreamController ??= StreamController<Position>.broadcast();
    return _positionStreamController!.stream;
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> checkPermissions() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  Future<void> startTracking() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      final granted = await requestPermissions();
      if (!granted) {
        throw Exception('Location permission denied');
      }
    }

    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 200),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _positionStreamController?.add(position);
    });
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionStreamController?.close();
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
}
