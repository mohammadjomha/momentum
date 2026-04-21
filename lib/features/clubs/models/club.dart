import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String description;
  final String ownerUid;
  final String ownerUsername;
  final List<String> memberUids;
  final List<String> adminUids;
  final String? pinnedPostId;
  final DateTime createdAt;

  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerUid,
    required this.ownerUsername,
    required this.memberUids,
    this.adminUids = const [],
    this.pinnedPostId,
    required this.createdAt,
  });

  int get memberCount => memberUids.length;

  factory Club.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'];
    return Club(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      ownerUsername: (data['ownerUsername'] as String?) ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      adminUids: List<String>.from(data['adminUids'] ?? []),
      pinnedPostId: data['pinnedPostId'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'ownerUid': ownerUid,
        'ownerUsername': ownerUsername,
        'memberUids': memberUids,
        'adminUids': adminUids,
        'pinnedPostId': pinnedPostId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
