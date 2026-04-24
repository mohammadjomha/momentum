import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip_model.dart';

class TripHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveTrip(TripModel trip) async {
    await _db.collection('trips').doc(trip.id).set(trip.toMap());

    // Update user aggregate stats
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({
        'totalTrips': FieldValue.increment(1),
        'totalDistance': FieldValue.increment(trip.distance),
      });
    }
  }

  Future<void> deleteTrip(String tripId, double distanceKm) async {
    await _db.collection('trips').doc(tripId).delete();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({
        'totalTrips': FieldValue.increment(-1),
        'totalDistance': FieldValue.increment(-distanceKm),
      });
    }
  }

  Stream<List<TripModel>> tripsStream(String uid) {
    return _db
        .collection('trips')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final trips = snap.docs.map(TripModel.fromDoc).toList();
          trips.sort((a, b) => b.date.compareTo(a.date));
          return trips;
        });
  }
}
