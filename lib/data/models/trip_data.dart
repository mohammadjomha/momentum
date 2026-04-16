class TripData {
  final String? id;
  final double currentSpeed;
  final double averageSpeed;
  final double maxSpeed;
  final double distance;
  final Duration duration;
  final DateTime startTime;

  // Braking
  final int hardBrakeCount;
  final double peakBrakeG;
  final double avgBrakeG;

  // Acceleration
  final int hardAccelCount;
  final double peakAccelG;
  final double avgAccelG;

  // Cornering
  final int totalCornerCount;
  final int rightCornerCount;
  final int leftCornerCount;
  final double sharpestCornerG;
  final double avgCorneringG;

  TripData({
    this.id,
    required this.currentSpeed,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.distance,
    required this.duration,
    required this.startTime,
    this.hardBrakeCount = 0,
    this.peakBrakeG = 0.0,
    this.avgBrakeG = 0.0,
    this.hardAccelCount = 0,
    this.peakAccelG = 0.0,
    this.avgAccelG = 0.0,
    this.totalCornerCount = 0,
    this.rightCornerCount = 0,
    this.leftCornerCount = 0,
    this.sharpestCornerG = 0.0,
    this.avgCorneringG = 0.0,
  });

  TripData copyWith({
    String? id,
    double? currentSpeed,
    double? averageSpeed,
    double? maxSpeed,
    double? distance,
    Duration? duration,
    DateTime? startTime,
    int? hardBrakeCount,
    double? peakBrakeG,
    double? avgBrakeG,
    int? hardAccelCount,
    double? peakAccelG,
    double? avgAccelG,
    int? totalCornerCount,
    int? rightCornerCount,
    int? leftCornerCount,
    double? sharpestCornerG,
    double? avgCorneringG,
  }) {
    return TripData(
      id: id ?? this.id,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      hardBrakeCount: hardBrakeCount ?? this.hardBrakeCount,
      peakBrakeG: peakBrakeG ?? this.peakBrakeG,
      avgBrakeG: avgBrakeG ?? this.avgBrakeG,
      hardAccelCount: hardAccelCount ?? this.hardAccelCount,
      peakAccelG: peakAccelG ?? this.peakAccelG,
      avgAccelG: avgAccelG ?? this.avgAccelG,
      totalCornerCount: totalCornerCount ?? this.totalCornerCount,
      rightCornerCount: rightCornerCount ?? this.rightCornerCount,
      leftCornerCount: leftCornerCount ?? this.leftCornerCount,
      sharpestCornerG: sharpestCornerG ?? this.sharpestCornerG,
      avgCorneringG: avgCorneringG ?? this.avgCorneringG,
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
      'hardBrakeCount': hardBrakeCount,
      'peakBrakeG': peakBrakeG,
      'avgBrakeG': avgBrakeG,
      'hardAccelCount': hardAccelCount,
      'peakAccelG': peakAccelG,
      'avgAccelG': avgAccelG,
      'totalCornerCount': totalCornerCount,
      'rightCornerCount': rightCornerCount,
      'leftCornerCount': leftCornerCount,
      'sharpestCornerG': sharpestCornerG,
      'avgCorneringG': avgCorneringG,
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
      hardBrakeCount: (json['hardBrakeCount'] as num?)?.toInt() ?? 0,
      peakBrakeG: (json['peakBrakeG'] as num?)?.toDouble() ?? 0.0,
      avgBrakeG: (json['avgBrakeG'] as num?)?.toDouble() ?? 0.0,
      hardAccelCount: (json['hardAccelCount'] as num?)?.toInt() ?? 0,
      peakAccelG: (json['peakAccelG'] as num?)?.toDouble() ?? 0.0,
      avgAccelG: (json['avgAccelG'] as num?)?.toDouble() ?? 0.0,
      totalCornerCount: (json['totalCornerCount'] as num?)?.toInt() ?? 0,
      rightCornerCount: (json['rightCornerCount'] as num?)?.toInt() ?? 0,
      leftCornerCount: (json['leftCornerCount'] as num?)?.toInt() ?? 0,
      sharpestCornerG: (json['sharpestCornerG'] as num?)?.toDouble() ?? 0.0,
      avgCorneringG: (json['avgCorneringG'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
