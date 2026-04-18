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

  const SensorSummary({
    this.hardBrakeCount = 0,
    this.peakBrakeG = 0,
    this.avgBrakeG = 0,
    this.hardAccelCount = 0,
    this.peakAccelG = 0,
    this.avgAccelG = 0,
  });
}

class SensorService {
  static const double _gConstant = 9.81;

  // Thresholds
  static const double _hardEventThresholdG = 0.18;

  // Minimum sustained durations
  static const Duration _hardEventMinDuration = Duration(milliseconds: 300);

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

  // Accumulated events
  final List<BrakeEvent> _brakeEvents = [];
  final List<AccelEvent> _accelEvents = [];

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
      _brakeEvents.add(BrakeEvent(peakG));
    } else if (speedDelta > 0) {
      _accelEvents.add(AccelEvent(peakG));
    }
    // If speed unchanged, discard
  }

  Future<SensorSummary> stopTracking() async {
    await _sub?.cancel();
    _sub = null;

    // Flush any in-progress hard event still active when tracking stopped
    final now = DateTime.now();
    if (_inHardEvent && _hardEventStart != null) {
      if (now.difference(_hardEventStart!) >= _hardEventMinDuration) {
        _attributeHardEvent(_hardEventPeak);
      }
      _inHardEvent = false;
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

    return SensorSummary(
      hardBrakeCount: brakeCount,
      peakBrakeG: peakBrake,
      avgBrakeG: avgBrake,
      hardAccelCount: accelCount,
      peakAccelG: peakAccel,
      avgAccelG: avgAccel,
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
    _brakeEvents.clear();
    _accelEvents.clear();
  }
}