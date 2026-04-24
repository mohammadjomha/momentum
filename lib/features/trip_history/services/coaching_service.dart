import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../config/secrets.dart';
import '../models/trip_model.dart';

const _shortTripMessage =
    'Trip too short for coaching. Drive at least 0.5 km to receive AI feedback.';

const _noSensorMessage =
    'Sensor data unavailable for this trip. Record a new trip to receive AI coaching.';

class CoachingService {
  static Future<String> generateAndStoreCoachingNote(TripModel trip) async {
    if (trip.distance < 0.5) return _shortTripMessage;
    if (trip.peakBrakeG == 0 && trip.peakAccelG == 0) return _noSensorMessage;

    final note = await _callApi(trip);

    await FirebaseFirestore.instance
        .collection('trips')
        .doc(trip.id)
        .update({'coachingNote': note});

    return note;
  }

  static Future<String> _callApi(TripModel trip) async {
    final durationMin = trip.duration.inSeconds / 60.0;
    final weatherLabel = trip.weatherLabel.isEmpty ? 'Unknown' : trip.weatherLabel;
    final prompt = '''You are an expert driving coach analyzing telemetry data from a real drive.

Stats:
- Distance: ${trip.distance.toStringAsFixed(2)} km
- Duration: ${durationMin.toStringAsFixed(1)} min
- Max speed: ${trip.maxSpeed.toStringAsFixed(0)} km/h
- Avg speed: ${trip.avgSpeed.toStringAsFixed(0)} km/h
- Smoothness score: ${trip.smoothnessScore.toStringAsFixed(1)}/100
- Peak braking: ${trip.peakBrakeG.toStringAsFixed(2)}G
- Avg braking: ${trip.avgBrakeG.toStringAsFixed(2)}G
- Peak acceleration: ${trip.peakAccelG.toStringAsFixed(2)}G
- Avg acceleration: ${trip.avgAccelG.toStringAsFixed(2)}G
- Weather: $weatherLabel

Give the driver 2–3 sentences of specific, actionable feedback based only on these numbers. Reference the actual values. Do not make assumptions about road type, speed limits, or route conditions. Do not use headers, labels, or markdown. Start directly with the feedback.''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 300,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Anthropic API error ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>;
    return (content.first as Map<String, dynamic>)['text'] as String;
  }
}