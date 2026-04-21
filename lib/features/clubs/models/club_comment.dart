import 'package:cloud_firestore/cloud_firestore.dart';

class ClubComment {
  final String commentId;
  final String postId;
  final String authorUid;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;

  const ClubComment({
    required this.commentId,
    required this.postId,
    required this.authorUid,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
    this.editedAt,
  });

  factory ClubComment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['createdAt'];
    final editedTs = data['editedAt'];
    return ClubComment(
      commentId: doc.id,
      postId: (data['postId'] as String?) ?? '',
      authorUid: (data['authorUid'] as String?) ?? '',
      authorUsername: (data['authorUsername'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      editedAt: editedTs is Timestamp ? editedTs.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'authorUid': authorUid,
        'authorUsername': authorUsername,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': editedAt,
      };
}
