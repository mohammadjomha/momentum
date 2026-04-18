import 'package:cloud_firestore/cloud_firestore.dart';

class RoutePoint {
  final double lat;
  final double lng;
  final double speed;

  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.speed,
  });

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'speed': speed};

  factory RoutePoint.fromMap(Map<String, dynamic> m) => RoutePoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        speed: (m['speed'] as num).toDouble(),
      );
}

class TripModel {
  final String id;
  final String uid;
  final String username;
  final DateTime date;
  final double maxSpeed;
  final double avgSpeed;
  final double distance;
  final Duration duration;
  final List<RoutePoint> route;

  // Sensor fields — default to 0 for trips recorded before sensor support
  final int hardBrakeCount;
  final double peakBrakeG;
  final double avgBrakeG;
  final int hardAccelCount;
  final double peakAccelG;
  final double avgAccelG;

  // Weather
  final int weatherCode;
  final String weatherLabel;
  final double weatherTempC;
  final double weatherMultiplier;

  // Smoothness
  final double smoothnessScore;

  const TripModel({
    required this.id,
    required this.uid,
    required this.username,
    required this.date,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.distance,
    required this.duration,
    required this.route,
    this.hardBrakeCount = 0,
    this.peakBrakeG = 0.0,
    this.avgBrakeG = 0.0,
    this.hardAccelCount = 0,
    this.peakAccelG = 0.0,
    this.avgAccelG = 0.0,
    this.weatherCode = 0,
    this.weatherLabel = '',
    this.weatherTempC = 0.0,
    this.weatherMultiplier = 1.0,
    this.smoothnessScore = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'date': Timestamp.fromDate(date),
        'maxSpeed': maxSpeed,
        'avgSpeed': avgSpeed,
        'distance': distance,
        'durationSeconds': duration.inSeconds,
        'route': route.map((p) => p.toMap()).toList(),
        'hardBrakeCount': hardBrakeCount,
        'peakBrakeG': peakBrakeG,
        'avgBrakeG': avgBrakeG,
        'hardAccelCount': hardAccelCount,
        'peakAccelG': peakAccelG,
        'avgAccelG': avgAccelG,
        'weatherCode': weatherCode,
        'weatherLabel': weatherLabel,
        'weatherTempC': weatherTempC,
        'weatherMultiplier': weatherMultiplier,
        'smoothnessScore': smoothnessScore,
      };

  factory TripModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    final routeList = (m['route'] as List<dynamic>? ?? [])
        .map((e) => RoutePoint.fromMap(e as Map<String, dynamic>))
        .toList();
    return TripModel(
      id: doc.id,
      uid: m['uid'] as String? ?? '',
      username: m['username'] as String? ?? '',
      date: (m['date'] as Timestamp).toDate(),
      maxSpeed: (m['maxSpeed'] as num).toDouble(),
      avgSpeed: (m['avgSpeed'] as num).toDouble(),
      distance: (m['distance'] as num).toDouble(),
      duration: Duration(seconds: (m['durationSeconds'] as num).toInt()),
      route: routeList,
      hardBrakeCount: (m['hardBrakeCount'] as num?)?.toInt() ?? 0,
      peakBrakeG: (m['peakBrakeG'] as num?)?.toDouble() ?? 0.0,
      avgBrakeG: (m['avgBrakeG'] as num?)?.toDouble() ?? 0.0,
      hardAccelCount: (m['hardAccelCount'] as num?)?.toInt() ?? 0,
      peakAccelG: (m['peakAccelG'] as num?)?.toDouble() ?? 0.0,
      avgAccelG: (m['avgAccelG'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (m['weatherCode'] as num?)?.toInt() ?? 0,
      weatherLabel: m['weatherLabel'] as String? ?? '',
      weatherTempC: (m['weatherTempC'] as num?)?.toDouble() ?? 0.0,
      weatherMultiplier: (m['weatherMultiplier'] as num?)?.toDouble() ?? 1.0,
      smoothnessScore: (m['smoothnessScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}