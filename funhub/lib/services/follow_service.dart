import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  static final _firestore = FirebaseFirestore.instance;

  /// FOLLOW
  static Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;

    final currentUserRef =
    _firestore.collection('users').doc(currentUserId);
    final targetUserRef =
    _firestore.collection('users').doc(targetUserId);

    final followerRef = targetUserRef
        .collection('followers')
        .doc(currentUserId);

    final followingRef = currentUserRef
        .collection('following')
        .doc(targetUserId);

    await _firestore.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);

      if (followerSnap.exists) {
        return; // đã follow rồi
      }

      tx.set(followerRef, {
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(followingRef, {
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.update(targetUserRef, {
        'followerCount': FieldValue.increment(1),
      });

      tx.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });
    });
  }

  /// UNFOLLOW
  static Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final currentUserRef =
    _firestore.collection('users').doc(currentUserId);
    final targetUserRef =
    _firestore.collection('users').doc(targetUserId);

    final followerRef = targetUserRef
        .collection('followers')
        .doc(currentUserId);

    final followingRef = currentUserRef
        .collection('following')
        .doc(targetUserId);

    await _firestore.runTransaction((tx) async {
      final followerSnap = await tx.get(followerRef);

      if (!followerSnap.exists) {
        return;
      }

      tx.delete(followerRef);
      tx.delete(followingRef);

      tx.update(targetUserRef, {
        'followerCount': FieldValue.increment(-1),
      });

      tx.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });
    });
  }

  /// CHECK FOLLOWING
  static Future<bool> isFollowing({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .get();

    return doc.exists;
  }
}
