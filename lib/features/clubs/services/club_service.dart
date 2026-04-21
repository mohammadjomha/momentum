import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/club.dart';
import '../models/club_comment.dart';
import '../models/club_post.dart';

class ClubService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ---------------------------------------------------------------------------
  // Clubs CRUD
  // ---------------------------------------------------------------------------

  Future<String> createClub({
    required String name,
    required String description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    final username = (userDoc.data()?['username'] as String?) ?? '';

    final ref = await _db.collection('clubs').add({
      'name': name.trim(),
      'description': description.trim(),
      'ownerUid': uid,
      'ownerUsername': username,
      'memberUids': [uid],
      'adminUids': <String>[],
      'pinnedPostId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> joinClub(String clubId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('clubs').doc(clubId).update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> leaveClub(String clubId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('clubs').doc(clubId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteClub(String clubId) async {
    await _db.collection('clubs').doc(clubId).delete();
  }

  // ---------------------------------------------------------------------------
  // Streams — clubs
  // ---------------------------------------------------------------------------

  Stream<List<Club>> streamUserClubs(String uid) {
    return _db
        .collection('clubs')
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Club.fromDoc).toList());
  }

  Stream<List<Club>> streamAllClubs() {
    return _db
        .collection('clubs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Club.fromDoc).toList());
  }

  Stream<Club?> streamClub(String clubId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .snapshots()
        .map((doc) => doc.exists ? Club.fromDoc(doc) : null);
  }

  Future<ClubPost?> fetchPost(String postId) async {
    final doc = await _db.collection('club_posts').doc(postId).get();
    if (!doc.exists) return null;
    return ClubPost.fromDoc(doc);
  }

  Future<List<Club>> searchClubs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final snap = await _db
        .collection('clubs')
        .where('name', isGreaterThanOrEqualTo: trimmed)
        .where('name', isLessThan: '$trimmed')
        .limit(20)
        .get();
    return snap.docs.map(Club.fromDoc).toList();
  }

  // ---------------------------------------------------------------------------
  // Streams — posts
  // ---------------------------------------------------------------------------

  Stream<List<ClubPost>> streamPosts(String clubId) {
    return _db
        .collection('club_posts')
        .where('clubId', isEqualTo: clubId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ClubPost.fromDoc).toList());
  }

  // ---------------------------------------------------------------------------
  // Posts — write operations
  // ---------------------------------------------------------------------------

  Future<void> createPost({
    required String clubId,
    String? body,
    File? imageFile,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    final username = (userDoc.data()?['username'] as String?) ?? '';

    String? imageUrl;
    if (imageFile != null) {
      final ref = _storage
          .ref()
          .child('club_posts/$clubId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    await _db.collection('club_posts').add({
      'clubId': clubId,
      'authorUid': uid,
      'authorUsername': username,
      'body': (body ?? '').trim(),
      'imageUrl': imageUrl,
      'likedBy': <String>[],
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
    });
  }

  Future<void> editPost(
    String clubId,
    String postId,
    String newCaption,
    String uid,
  ) async {
    final postRef = _db.collection('club_posts').doc(postId);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw Exception('Post not found');
    final authorUid = (postDoc.data()?['authorUid'] as String?) ?? '';
    if (uid != authorUid) throw Exception('Not authorized');

    await postRef.update({
      'body': newCaption.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(
    String clubId,
    String postId,
    String uid,
    bool isAdmin,
  ) async {
    final postRef = _db.collection('club_posts').doc(postId);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw Exception('Post not found');

    final data = postDoc.data()!;
    final authorUid = (data['authorUid'] as String?) ?? '';
    if (uid != authorUid && !isAdmin) throw Exception('Not authorized');

    final imageUrl = data['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } catch (_) {
        // Storage file missing — proceed with Firestore delete anyway
      }
    }

    await postRef.delete();
  }

  Future<void> toggleLike(String clubId, String postId, String uid) async {
    final postRef = _db.collection('club_posts').doc(postId);
    final postDoc = await postRef.get();
    if (!postDoc.exists) throw Exception('Post not found');

    final likedBy = List<String>.from(postDoc.data()?['likedBy'] ?? []);
    final batch = _db.batch();

    if (likedBy.contains(uid)) {
      batch.update(postRef, {
        'likedBy': FieldValue.arrayRemove([uid]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      batch.update(postRef, {
        'likedBy': FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  Future<void> pinPost(String clubId, String postId, String uid) async {
    final clubRef = _db.collection('clubs').doc(clubId);
    final clubDoc = await clubRef.get();
    if (!clubDoc.exists) throw Exception('Club not found');

    final data = clubDoc.data()!;
    final ownerUid = (data['ownerUid'] as String?) ?? '';
    final adminUids = List<String>.from(data['adminUids'] ?? []);

    if (uid != ownerUid && !adminUids.contains(uid)) {
      throw Exception('Not authorized');
    }

    final currentPinned = data['pinnedPostId'] as String?;
    await clubRef.update({
      'pinnedPostId': currentPinned == postId ? null : postId,
    });
  }

  // ---------------------------------------------------------------------------
  // Comments
  // ---------------------------------------------------------------------------

  DocumentReference _commentRef(
          String clubId, String postId, String commentId) =>
      _db
          .collection('clubs')
          .doc(clubId)
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

  CollectionReference _commentsCollection(String clubId, String postId) =>
      _db
          .collection('clubs')
          .doc(clubId)
          .collection('posts')
          .doc(postId)
          .collection('comments');

  Future<void> addComment(
    String clubId,
    String postId,
    String authorUid,
    String authorUsername,
    String text,
  ) async {
    final commentRef = _commentsCollection(clubId, postId).doc();
    final postRef = _db.collection('club_posts').doc(postId);

    final batch = _db.batch();
    batch.set(commentRef, {
      'postId': postId,
      'authorUid': authorUid,
      'authorUsername': authorUsername,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
    });
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> editComment(
    String clubId,
    String postId,
    String commentId,
    String newText,
    String uid,
  ) async {
    final commentRef = _commentRef(clubId, postId, commentId);
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) throw Exception('Comment not found');

    final authorUid =
        ((commentDoc.data() as Map<String, dynamic>?)?['authorUid']
                as String?) ??
            '';
    if (uid != authorUid) throw Exception('Not authorized');

    await commentRef.update({
      'text': newText.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment(
    String clubId,
    String postId,
    String commentId,
    String uid,
  ) async {
    final commentRef = _commentRef(clubId, postId, commentId);
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) throw Exception('Comment not found');

    final authorUid =
        ((commentDoc.data() as Map<String, dynamic>?)?['authorUid']
                as String?) ??
            '';
    if (uid != authorUid) throw Exception('Not authorized');

    final postRef = _db.collection('club_posts').doc(postId);
    final batch = _db.batch();
    batch.delete(commentRef);
    batch.update(postRef, {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Stream<List<ClubComment>> streamComments(String clubId, String postId) {
    return _commentsCollection(clubId, postId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(ClubComment.fromDoc).toList());
  }
}

final clubService = ClubService();
