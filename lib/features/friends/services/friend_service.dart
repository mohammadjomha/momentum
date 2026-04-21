import 'package:cloud_firestore/cloud_firestore.dart';

enum RelationshipStatus { none, pendingSent, pendingReceived, friends }

class FriendEntry {
  final String uid;
  final String username;
  final String carMake;
  final String carModel;

  const FriendEntry({
    required this.uid,
    required this.username,
    required this.carMake,
    required this.carModel,
  });
}

class FriendRequest {
  final String requestId;
  final String fromUid;
  final String fromUsername;
  final DateTime createdAt;

  const FriendRequest({
    required this.requestId,
    required this.fromUid,
    required this.fromUsername,
    required this.createdAt,
  });
}

class FriendService {
  final _db = FirebaseFirestore.instance;

  Future<void> sendFriendRequest({
    required String fromUid,
    required String fromUsername,
    required String toUid,
    required String toUsername,
  }) async {
    // Resolve fromUsername from Firestore if the caller passed an empty value
    String resolvedFromUsername = fromUsername.trim();
    if (resolvedFromUsername.isEmpty) {
      final userDoc = await _db.collection('users').doc(fromUid).get();
      resolvedFromUsername =
          (userDoc.data()?['username'] as String?)?.trim() ?? '';
      if (resolvedFromUsername.isEmpty) {
        throw Exception('Could not resolve fromUsername for uid: $fromUid');
      }
    }

    // Check for any non-rejected request between these two users
    final existing = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .get();

    final reverse = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: toUid)
        .where('toUid', isEqualTo: fromUid)
        .get();

    final allDocs = [...existing.docs, ...reverse.docs];
    final hasActive = allDocs.any((d) => d.data()['status'] != 'rejected');
    if (hasActive) return;

    await _db.collection('friend_requests').add({
      'fromUid': fromUid,
      'fromUsername': resolvedFromUsername,
      'toUid': toUid,
      'toUsername': toUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<RelationshipStatus> getRelationshipStatus(
    String currentUid,
    String targetUid,
  ) async {
    // Check if already friends
    final userDoc = await _db.collection('users').doc(currentUid).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
    if (friends.contains(targetUid)) return RelationshipStatus.friends;

    // Check sent requests
    final sent = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: currentUid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sent.docs.isNotEmpty) return RelationshipStatus.pendingSent;

    // Check received requests
    final received = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: targetUid)
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (received.docs.isNotEmpty) return RelationshipStatus.pendingReceived;

    return RelationshipStatus.none;
  }

  Future<String?> getPendingRequestId(
    String fromUid,
    String toUid,
  ) async {
    final snap = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  Future<void> acceptRequest(
    String requestId,
    String fromUid,
    String toUid,
  ) async {
    final batch = _db.batch();
    batch.update(_db.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
    });
    batch.update(_db.collection('users').doc(fromUid), {
      'friends': FieldValue.arrayUnion([toUid]),
    });
    batch.update(_db.collection('users').doc(toUid), {
      'friends': FieldValue.arrayUnion([fromUid]),
    });
    await batch.commit();
  }

  Future<void> rejectRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  Stream<List<FriendEntry>> getFriends(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((snap) async {
      final friends = List<String>.from(snap.data()?['friends'] ?? []);
      if (friends.isEmpty) return <FriendEntry>[];

      final futures = friends.map((fUid) async {
        final doc = await _db.collection('users').doc(fUid).get();
        final data = doc.data() ?? {};
        final car = data['car'] as Map<String, dynamic>? ?? {};
        return FriendEntry(
          uid: fUid,
          username: (data['username'] as String?) ?? fUid,
          carMake: (car['make'] as String?) ?? '',
          carModel: (car['model'] as String?) ?? '',
        );
      });
      return Future.wait(futures);
    });
  }

  Stream<List<FriendRequest>> getPendingReceived(String uid) {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final ts = data['createdAt'];
              final createdAt = ts is Timestamp
                  ? ts.toDate()
                  : DateTime.now();
              return FriendRequest(
                requestId: doc.id,
                fromUid: (data['fromUid'] as String?) ?? '',
                fromUsername: (data['fromUsername'] as String?) ?? '',
                createdAt: createdAt,
              );
            }).toList());
  }
}

final friendService = FriendService();