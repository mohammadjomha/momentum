import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorEvent {
  final double x;
  final double y;
  final double z;
  const SensorEvent(this.x, this.y, this.z);
}

class CornerEvent {
  final double peakG;
  const CornerEvent(this.peakG);
}

class BrakeEvent {
  final double peakG;
  const BrakeEvent(this.peakG);
}

class AccelEvent {
  final double peakG;
  const AccelEvent(this.peakG);
}

class SensorSummary {
  final int hardBrakeCount;
  final double peakBrakeG;
  final double avgBrakeG;
  final int hardAccelCount;
  final double peakAccelG;
  final double avgAccelG;
  final int totalCornerCount;
  final int rightCornerCount;
  final int leftCornerCount;
  final double sharpestCornerG;
  final double avgCorneringG;

  const SensorSummary({
    this.hardBrakeCount = 0,
    this.peakBrakeG = 0,
    this.avgBrakeG = 0,
    this.hardAccelCount = 0,
    this.peakAccelG = 0,
    this.avgAccelG = 0,
    this.totalCornerCount = 0,
    this.rightCornerCount = 0,
    this.leftCornerCount = 0,
    this.sharpestCornerG = 0,
    this.avgCorneringG = 0,
  });
}

class SensorDebugState {
  final double rawX;
  final double rawY;
  final double rawZ;
  final double magnitude; // total G magnitude
  final String brakeState;
  final String accelState;
  final String cornerState;
  final int hardBrakeCount;
  final int hardAccelCount;
  final int totalCornerCount;

  const SensorDebugState({
    this.rawX = 0,
    this.rawY = 0,
    this.rawZ = 0,
    this.magnitude = 0,
    this.brakeState = 'idle',
    this.accelState = 'idle',
    this.cornerState = 'idle',
    this.hardBrakeCount = 0,
    this.hardAccelCount = 0,
    this.totalCornerCount = 0,
  });
}

class SensorService {
  static const double _gConstant = 9.81;

  // Thresholds
  static const double _hardEventThresholdG = 0.25;
  static const double _cornerThresholdG = 0.15;

  // Minimum sustained durations
  static const Duration _hardEventMinDuration = Duration(milliseconds: 150);
  static const Duration _cornerMinDuration = Duration(milliseconds: 300);

  StreamSubscription<UserAccelerometerEvent>? _sub;

  // Throttle state
  DateTime? _lastSampleTime;

  // GPS speed for brake/accel distinction
  double _lastSpeedKmh = 0;
  double _prevSpeedKmh = 0;

  // Hard event state machine (brake or accel)
  bool _inHardEvent = false;
  DateTime? _hardEventStart;
  double _hardEventPeak = 0.0;

  // Corner state machine
  bool _inCorner = false;
  DateTime? _cornerStart;
  double _cornerPeak = 0.0;

  // Accumulated events
  final List<CornerEvent> _cornerEvents = [];
  final List<BrakeEvent> _brakeEvents = [];
  final List<AccelEvent> _accelEvents = [];

  // Debug state — updated on every sample tick
  SensorDebugState _debugState = const SensorDebugState();
  SensorDebugState get debugState => _debugState;

  /// Updates GPS speed — call from tracking_provider on every position update.
  void updateSpeed(double speedKmh) {
    _prevSpeedKmh = _lastSpeedKmh;
    _lastSpeedKmh = speedKmh;
  }

  /// Begins magnitude-based sensor tracking immediately (no calibration delay).
  Future<void> startTracking() async {
    final status = await Permission.sensors.request();
    if (!status.isGranted) {
      developer.log('Motion permission not granted: $status', name: 'SensorService');
      return;
    }
    _sub = userAccelerometerEventStream().listen(_onSample);
  }

  void _onSample(UserAccelerometerEvent event) {
    final now = DateTime.now();

    // Throttle to ~20 Hz
    if (_lastSampleTime != null &&
        now.difference(_lastSampleTime!) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastSampleTime = now;

    final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / _gConstant;

    _processHardEvent(mag, now);
    _processCorner(mag, now);

    _debugState = SensorDebugState(
      rawX: event.x,
      rawY: event.y,
      rawZ: event.z,
      magnitude: mag,
      brakeState: _inHardEvent && (_prevSpeedKmh > _lastSpeedKmh) ? 'active' : 'idle',
      accelState: _inHardEvent && (_lastSpeedKmh > _prevSpeedKmh) ? 'active' : 'idle',
      cornerState: _inCorner ? 'active' : 'idle',
      hardBrakeCount: _brakeEvents.length,
      hardAccelCount: _accelEvents.length,
      totalCornerCount: _cornerEvents.length,
    );
  }

  void _processHardEvent(double mag, DateTime now) {
    if (mag > _hardEventThresholdG) {
      if (!_inHardEvent) {
        _inHardEvent = true;
        _hardEventStart = now;
        _hardEventPeak = mag;
      } else {
        if (mag > _hardEventPeak) _hardEventPeak = mag;
      }
    } else {
      if (_inHardEvent) {
        final duration = now.difference(_hardEventStart!);
        if (duration >= _hardEventMinDuration) {
          _attributeHardEvent(_hardEventPeak);
        }
        _inHardEvent = false;
        _hardEventPeak = 0.0;
      }
    }
  }

  void _attributeHardEvent(double peakG) {
    final speedDelta = _lastSpeedKmh - _prevSpeedKmh;
    if (speedDelta < 0) {
      // Decelerating → brake
      _brakeEvents.add(BrakeEvent(peakG));
    } else if (speedDelta > 0) {
      // Accelerating → accel
      _accelEvents.add(AccelEvent(peakG));
    }
    // If speed unchanged, discard
  }

  void _processCorner(double mag, DateTime now) {
    if (mag > _cornerThresholdG) {
      if (!_inCorner) {
        _inCorner = true;
        _cornerStart = now;
        _cornerPeak = mag;
      } else {
        if (mag > _cornerPeak) _cornerPeak = mag;
      }
    } else {
      if (_inCorner) {
        final duration = now.difference(_cornerStart!);
        if (duration >= _cornerMinDuration) {
          _cornerEvents.add(CornerEvent(_cornerPeak));
        }
        _inCorner = false;
        _cornerPeak = 0.0;
      }
    }
  }

  Future<SensorSummary> stopTracking() async {
    await _sub?.cancel();
    _sub = null;

    // Flush any in-progress events still active when tracking stopped
    final now = DateTime.now();
    if (_inHardEvent && _hardEventStart != null) {
      if (now.difference(_hardEventStart!) >= _hardEventMinDuration) {
        _attributeHardEvent(_hardEventPeak);
      }
      _inHardEvent = false;
    }
    if (_inCorner && _cornerStart != null) {
      if (now.difference(_cornerStart!) >= _cornerMinDuration) {
        _cornerEvents.add(CornerEvent(_cornerPeak));
      }
      _inCorner = false;
    }

    return _buildSummary();
  }

  SensorSummary _buildSummary() {
    final brakeCount = _brakeEvents.length;
    final peakBrake =
        brakeCount > 0 ? _brakeEvents.map((e) => e.peakG).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgBrake =
        brakeCount > 0 ? _brakeEvents.map((e) => e.peakG).reduce((a, b) => a + b) / brakeCount : 0.0;

    final accelCount = _accelEvents.length;
    final peakAccel =
        accelCount > 0 ? _accelEvents.map((e) => e.peakG).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgAccel =
        accelCount > 0 ? _accelEvents.map((e) => e.peakG).reduce((a, b) => a + b) / accelCount : 0.0;

    final cornerCount = _cornerEvents.length;
    // Direction is not detectable from magnitude — split evenly
    final rightCount = cornerCount ~/ 2;
    final leftCount = cornerCount - rightCount;
    final sharpestCorner =
        cornerCount > 0 ? _cornerEvents.map((e) => e.peakG).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgCorner =
        cornerCount > 0 ? _cornerEvents.map((e) => e.peakG).reduce((a, b) => a + b) / cornerCount : 0.0;

    return SensorSummary(
      hardBrakeCount: brakeCount,
      peakBrakeG: peakBrake,
      avgBrakeG: avgBrake,
      hardAccelCount: accelCount,
      peakAccelG: peakAccel,
      avgAccelG: avgAccel,
      totalCornerCount: cornerCount,
      rightCornerCount: rightCount,
      leftCornerCount: leftCount,
      sharpestCornerG: sharpestCorner,
      avgCorneringG: avgCorner,
    );
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    _lastSampleTime = null;
    _lastSpeedKmh = 0;
    _prevSpeedKmh = 0;
    _inHardEvent = false;
    _hardEventStart = null;
    _hardEventPeak = 0.0;
    _inCorner = false;
    _cornerStart = null;
    _cornerPeak = 0.0;
    _cornerEvents.clear();
    _brakeEvents.clear();
    _accelEvents.clear();
  }
}