import 'package:cloud_firestore/cloud_firestore.dart';

class ClubPost {
  final String id;
  final String clubId;
  final String authorUid;
  final String authorUsername;
  final String body;
  final String? imageUrl;
  final List<String> likedBy;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? editedAt;

  const ClubPost({
    required this.id,
    required this.clubId,
    required this.authorUid,
    required this.authorUsername,
    required this.body,
    this.imageUrl,
    this.likedBy = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.editedAt,
  });

  factory ClubPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'];
    final editedTs = data['editedAt'];
    return ClubPost(
      id: doc.id,
      clubId: (data['clubId'] as String?) ?? '',
      authorUid: (data['authorUid'] as String?) ?? '',
      authorUsername: (data['authorUsername'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      editedAt: editedTs is Timestamp ? editedTs.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'clubId': clubId,
        'authorUid': authorUid,
        'authorUsername': authorUsername,
        'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'likedBy': likedBy,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': editedAt,
      };
}
