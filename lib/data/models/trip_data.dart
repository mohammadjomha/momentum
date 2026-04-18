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

  // Weather
  final int weatherCode;
  final String weatherLabel;
  final double weatherTempC;
  final double weatherMultiplier;

  // Smoothness
  final double smoothnessScore;

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
    this.weatherCode = 0,
    this.weatherLabel = '',
    this.weatherTempC = 0.0,
    this.weatherMultiplier = 1.0,
    this.smoothnessScore = 0.0,
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
    int? weatherCode,
    String? weatherLabel,
    double? weatherTempC,
    double? weatherMultiplier,
    double? smoothnessScore,
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
      weatherCode: weatherCode ?? this.weatherCode,
      weatherLabel: weatherLabel ?? this.weatherLabel,
      weatherTempC: weatherTempC ?? this.weatherTempC,
      weatherMultiplier: weatherMultiplier ?? this.weatherMultiplier,
      smoothnessScore: smoothnessScore ?? this.smoothnessScore,
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
      'weatherCode': weatherCode,
      'weatherLabel': weatherLabel,
      'weatherTempC': weatherTempC,
      'weatherMultiplier': weatherMultiplier,
      'smoothnessScore': smoothnessScore,
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
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      weatherLabel: json['weatherLabel'] as String? ?? '',
      weatherTempC: (json['weatherTempC'] as num?)?.toDouble() ?? 0.0,
      weatherMultiplier: (json['weatherMultiplier'] as num?)?.toDouble() ?? 1.0,
      smoothnessScore: (json['smoothnessScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}