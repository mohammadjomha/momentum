import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../models/trip_model.dart';
import '../services/trip_history_service.dart';

final _tripHistoryService = TripHistoryService();

final tripHistoryProvider = StreamProvider<List<TripModel>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return _tripHistoryService.tripsStream(uid);
});
