class TripData {
  final String? id;
  final double currentSpeed;
  final double averageSpeed;
  final double maxSpeed;
  final double distance;
  final Duration duration;
  final DateTime startTime;

  TripData({
    this.id,
    required this.currentSpeed,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.distance,
    required this.duration,
    required this.startTime,
  });

  TripData copyWith({
    String? id,
    double? currentSpeed,
    double? averageSpeed,
    double? maxSpeed,
    double? distance,
    Duration? duration,
    DateTime? startTime,
  }) {
    return TripData(
      id: id ?? this.id,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
    );
  }

  static TripData initial() {
    return TripData(
      currentSpeed: 0,
      averageSpeed: 0,
      maxSpeed: 0,
      distance: 0,
      duration: Duration.zero,
      startTime: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'durationSeconds': duration.inSeconds,
      'startTime': startTime.toIso8601String(),
    };
  }

  factory TripData.fromJson(Map<String, dynamic> json) {
    return TripData(
      id: json['id'] as String,
      currentSpeed: 0,
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      duration: Duration(seconds: json['durationSeconds'] as int),
      startTime: DateTime.parse(json['startTime'] as String),
    );
  }
}
