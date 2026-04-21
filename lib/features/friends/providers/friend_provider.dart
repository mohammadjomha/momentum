import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/friend_service.dart';

final friendsProvider = StreamProvider<List<FriendEntry>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return friendService.getFriends(uid);
});

final pendingReceivedProvider = StreamProvider<List<FriendRequest>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return friendService.getPendingReceived(uid);
});