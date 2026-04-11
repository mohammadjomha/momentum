import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_data.dart';

class TripStorageService {
  static const String _tripsKey = 'saved_trips';

  Future<void> saveTrip(TripData trip) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = await getTrips();

    final tripWithId = trip.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    trips.insert(0, tripWithId);

    final tripsJson = trips.map((t) => t.toJson()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  Future<List<TripData>> getTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsString = prefs.getString(_tripsKey);

    if (tripsString == null || tripsString.isEmpty) {
      return [];
    }

    final List<dynamic> tripsJson = jsonDecode(tripsString);
    return tripsJson
        .map((json) => TripData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteTrip(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = await getTrips();

    trips.removeWhere((trip) => trip.id == id);

    final tripsJson = trips.map((t) => t.toJson()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  Future<void> clearAllTrips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripsKey);
  }
}
