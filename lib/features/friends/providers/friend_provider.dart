import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../services/friend_service.dart';

final friendsProvider = StreamProvider<List<FriendEntry>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return friendService.getFriends(uid);
});

final pendingReceivedProvider = StreamProvider<List<FriendRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return friendService.getPendingReceived(uid);
});