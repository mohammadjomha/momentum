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
    );
  }
}
