import 'dart:async';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorEvent {
  final double x; // lateral (cornering)
  final double y; // longitudinal (braking/accel)
  final double z;
  const SensorEvent(this.x, this.y, this.z);
}

class CornerEvent {
  final double peakG;
  final bool isRight; // positive lateral = right
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

  // Calibrated axis mapping (0=x, 1=y, 2=z)
  int _longAxis = 1; // default: y is longitudinal
  int _latAxis = 0;  // default: x is lateral
  int _longSign = 1; // +1 or -1
  int _latSign = 1;  // +1 or -1

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

  /// Calibrates axis mapping over 3 seconds, then begins tracking.
  /// Returns after calibration is complete.
  Future<void> startTracking() async {
    // --- Permission check (iOS requires explicit motion permission) ---
    final status = await Permission.sensors.request();
    if (!status.isGranted) {
      developer.log('Motion permission not granted: $status', name: 'SensorService');
      return;
    }

    // --- Calibration phase: sample for 3 seconds to find gravity axis ---
    final List<List<double>> calibSamples = [];
    final calibCompleter = Completer<void>();
    StreamSubscription<UserAccelerometerEvent>? calibSub;

    calibSub = userAccelerometerEventStream().listen((event) {
      calibSamples.add([event.x, event.y, event.z]);
    });

    await Future.delayed(const Duration(seconds: 3));
    await calibSub.cancel();

    if (calibSamples.isNotEmpty) {
      final n = calibSamples.length.toDouble();
      final meanX = calibSamples.map((s) => s[0]).reduce((a, b) => a + b) / n;
      final meanY = calibSamples.map((s) => s[1]).reduce((a, b) => a + b) / n;
      final meanZ = calibSamples.map((s) => s[2]).reduce((a, b) => a + b) / n;

      final absX = meanX.abs();
      final absY = meanY.abs();
      final absZ = meanZ.abs();

      // Axis with highest absolute mean is gravity axis (ignore for motion).
      // Second highest → longitudinal; lowest → lateral.
      final axes = [
        (axis: 0, abs: absX, mean: meanX),
        (axis: 1, abs: absY, mean: meanY),
        (axis: 2, abs: absZ, mean: meanZ),
      ]..sort((a, b) => b.abs.compareTo(a.abs));

      // axes[0] = gravity axis (highest abs), axes[1] = longitudinal, axes[2] = lateral
      final longEntry = axes[1];
      final latEntry = axes[2];

      _longAxis = longEntry.axis;
      _longSign = longEntry.mean >= 0 ? 1 : -1;
      _latAxis = latEntry.axis;
      _latSign = latEntry.mean >= 0 ? 1 : -1;
    }

    calibCompleter.complete();

    // --- Tracking phase: 20 Hz throttled stream ---
    _sub = userAccelerometerEventStream().listen(_onSample);

    await calibCompleter.future;
  }

  double _axisValue(UserAccelerometerEvent event, int axis) {
    switch (axis) {
      case 0:
        return event.x;
      case 1:
        return event.y;
      case 2:
        return event.z;
      default:
        return event.x;
    }
  }

  void _onSample(UserAccelerometerEvent event) {
    final now = DateTime.now();

    // Throttle to ~20 Hz
    if (_lastSampleTime != null &&
        now.difference(_lastSampleTime!) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastSampleTime = now;

    final longRaw = _axisValue(event, _longAxis) * _longSign;
    final latRaw = _axisValue(event, _latAxis) * _latSign;

    final longG = longRaw / _gConstant;
    final latG = latRaw / _gConstant;

    _processCorner(latG, now);
    _processBrake(longG, now);
    _processAccel(longG, now);
  }

  void _processCorner(double latG, DateTime now) {
    final absLat = latG.abs();
    if (absLat > _cornerThresholdG) {
      if (!_inCorner) {
        _inCorner = true;
        _cornerStart = now;
        _cornerPeak = absLat;
        _cornerIsRight = latG > 0;
      } else {
        if (absLat > _cornerPeak) _cornerPeak = absLat;
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

  void _processBrake(double longG, DateTime now) {
    // Braking: longitudinal < -threshold (deceleration)
    if (longG < -_brakeThresholdG) {
      final absLong = longG.abs();
      if (!_inBrake) {
        _inBrake = true;
        _brakeStart = now;
        _brakePeak = absLong;
      } else {
        if (absLong > _brakePeak) _brakePeak = absLong;
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

  void _processAccel(double longG, DateTime now) {
    // Acceleration: longitudinal > +threshold
    if (longG > _accelThresholdG) {
      if (!_inAccel) {
        _inAccel = true;
        _accelStart = now;
        _accelPeak = longG;
      } else {
        if (longG > _accelPeak) _accelPeak = longG;
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
    _longAxis = 1;
    _latAxis = 0;
    _longSign = 1;
    _latSign = 1;
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