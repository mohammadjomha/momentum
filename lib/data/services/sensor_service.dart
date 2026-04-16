import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorEvent {
  final double x; // lateral (cornering)
  final double y; // longitudinal (braking/accel)
  final double z;
  const SensorEvent(this.x, this.y, this.z);
}

class CornerEvent {
  final double peakG;
  final bool isRight; // positive X = right, negative X = left
  const CornerEvent(this.peakG, this.isRight);
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

class SensorService {
  static const double _gConstant = 9.81;

  // Thresholds
  static const double _cornerThresholdG = 0.15;
  static const double _brakeThresholdG = 0.3;
  static const double _accelThresholdG = 0.3;

  // Minimum sustained durations
  static const Duration _cornerMinDuration = Duration(milliseconds: 300);
  static const Duration _brakeMinDuration = Duration(milliseconds: 150);
  static const Duration _accelMinDuration = Duration(milliseconds: 150);

  StreamSubscription<UserAccelerometerEvent>? _sub;

  // Throttle state
  DateTime? _lastSampleTime;

  // Per-axis state machine fields
  // Corner
  bool _inCorner = false;
  DateTime? _cornerStart;
  double _cornerPeak = 0.0;
  bool _cornerIsRight = false;

  // Brake
  bool _inBrake = false;
  DateTime? _brakeStart;
  double _brakePeak = 0.0;

  // Accel
  bool _inAccel = false;
  DateTime? _accelStart;
  double _accelPeak = 0.0;

  // Accumulated events
  final List<CornerEvent> _cornerEvents = [];
  final List<BrakeEvent> _brakeEvents = [];
  final List<AccelEvent> _accelEvents = [];

  void startTracking() {
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

    final xG = event.x / _gConstant;
    final yG = event.y / _gConstant;

    _processCorner(xG, now);
    _processBrake(yG, now);
    _processAccel(yG, now);
  }

  void _processCorner(double xG, DateTime now) {
    final absX = xG.abs();
    if (absX > _cornerThresholdG) {
      if (!_inCorner) {
        _inCorner = true;
        _cornerStart = now;
        _cornerPeak = absX;
        _cornerIsRight = xG > 0;
      } else {
        if (absX > _cornerPeak) _cornerPeak = absX;
      }
    } else {
      if (_inCorner) {
        final duration = now.difference(_cornerStart!);
        if (duration >= _cornerMinDuration) {
          _cornerEvents.add(CornerEvent(_cornerPeak, _cornerIsRight));
        }
        _inCorner = false;
        _cornerPeak = 0.0;
      }
    }
  }

  void _processBrake(double yG, DateTime now) {
    // Braking: y < -threshold (deceleration)
    if (yG < -_brakeThresholdG) {
      final absY = yG.abs();
      if (!_inBrake) {
        _inBrake = true;
        _brakeStart = now;
        _brakePeak = absY;
      } else {
        if (absY > _brakePeak) _brakePeak = absY;
      }
    } else {
      if (_inBrake) {
        final duration = now.difference(_brakeStart!);
        if (duration >= _brakeMinDuration) {
          _brakeEvents.add(BrakeEvent(_brakePeak));
        }
        _inBrake = false;
        _brakePeak = 0.0;
      }
    }
  }

  void _processAccel(double yG, DateTime now) {
    // Acceleration: y > +threshold
    if (yG > _accelThresholdG) {
      if (!_inAccel) {
        _inAccel = true;
        _accelStart = now;
        _accelPeak = yG;
      } else {
        if (yG > _accelPeak) _accelPeak = yG;
      }
    } else {
      if (_inAccel) {
        final duration = now.difference(_accelStart!);
        if (duration >= _accelMinDuration) {
          _accelEvents.add(AccelEvent(_accelPeak));
        }
        _inAccel = false;
        _accelPeak = 0.0;
      }
    }
  }

  Future<SensorSummary> stopTracking() async {
    await _sub?.cancel();
    _sub = null;

    // Flush any in-progress events that were still active when tracking stopped
    final now = DateTime.now();
    if (_inCorner && _cornerStart != null) {
      if (now.difference(_cornerStart!) >= _cornerMinDuration) {
        _cornerEvents.add(CornerEvent(_cornerPeak, _cornerIsRight));
      }
    }
    if (_inBrake && _brakeStart != null) {
      if (now.difference(_brakeStart!) >= _brakeMinDuration) {
        _brakeEvents.add(BrakeEvent(_brakePeak));
      }
    }
    if (_inAccel && _accelStart != null) {
      if (now.difference(_accelStart!) >= _accelMinDuration) {
        _accelEvents.add(AccelEvent(_accelPeak));
      }
    }

    return _buildSummary();
  }

  SensorSummary _buildSummary() {
    // Braking
    final brakeCount = _brakeEvents.length;
    final peakBrake =
        brakeCount > 0 ? _brakeEvents.map((e) => e.peakG).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgBrake =
        brakeCount > 0 ? _brakeEvents.map((e) => e.peakG).reduce((a, b) => a + b) / brakeCount : 0.0;

    // Acceleration
    final accelCount = _accelEvents.length;
    final peakAccel =
        accelCount > 0 ? _accelEvents.map((e) => e.peakG).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgAccel =
        accelCount > 0 ? _accelEvents.map((e) => e.peakG).reduce((a, b) => a + b) / accelCount : 0.0;

    // Cornering
    final cornerCount = _cornerEvents.length;
    final rightCount = _cornerEvents.where((e) => e.isRight).length;
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
    _inCorner = false;
    _cornerStart = null;
    _cornerPeak = 0.0;
    _cornerIsRight = false;
    _inBrake = false;
    _brakeStart = null;
    _brakePeak = 0.0;
    _inAccel = false;
    _accelStart = null;
    _accelPeak = 0.0;
    _cornerEvents.clear();
    _brakeEvents.clear();
    _accelEvents.clear();
  }
}
