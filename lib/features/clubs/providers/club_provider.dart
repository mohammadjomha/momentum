import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../models/club.dart';
import '../models/club_comment.dart';
import '../models/club_post.dart';
import '../services/club_service.dart';

// My clubs
final userClubsProvider = StreamProvider<List<Club>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return clubService.streamUserClubs(uid);
});

// All clubs for discover tab
final allClubsProvider = StreamProvider<List<Club>>((ref) {
  return clubService.streamAllClubs();
});

// Single club detail
final clubDetailProvider =
    StreamProvider.family<Club?, String>((ref, clubId) {
  return clubService.streamClub(clubId);
});

// Posts for a club
final clubPostsProvider =
    StreamProvider.family<List<ClubPost>, String>((ref, clubId) {
  return clubService.streamPosts(clubId);
});

// Comments for a post — param is (clubId, postId) record
final clubCommentsProvider =
    StreamProvider.family<List<ClubComment>, (String, String)>(
        (ref, params) {
  final (clubId, postId) = params;
  return clubService.streamComments(clubId, postId);
});
