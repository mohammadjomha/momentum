import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_model.dart';
import '../services/trip_history_service.dart';

final _tripHistoryService = TripHistoryService();

final tripHistoryProvider = StreamProvider<List<TripModel>>((ref) {
  return _tripHistoryService.tripsStream();
});
