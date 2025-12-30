import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final String? parentCommentId;
  final Timestamp createdAt;
  final int likeCount; // ✅ THÊM

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.parentCommentId,
    required this.createdAt,
    required this.likeCount, // ✅ THÊM
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'parentCommentId': parentCommentId,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0, // ✅ MẶC ĐỊNH
    };
  }

  factory CommentModel.fromDoc(
      DocumentSnapshot doc,
      String postId,
      ) {
    final data = doc.data() as Map<String, dynamic>;

    return CommentModel(
      id: doc.id,
      postId: postId,
      userId: data['userId'],
      userName: data['userName'],
      userAvatar: data['userAvatar'],
      content: data['content'],
      parentCommentId: data['parentCommentId'],
      createdAt: data['createdAt'],
      likeCount: (data['likeCount'] ?? 0) as int, // ✅ FIX
    );
  }

}
