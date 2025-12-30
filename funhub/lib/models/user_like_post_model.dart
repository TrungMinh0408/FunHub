import 'package:cloud_firestore/cloud_firestore.dart';

class LikePostModel {
  final String postId;
  final String userId;
  final Timestamp createdAt;

  LikePostModel({
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }


  factory LikePostModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      String postId,
      ) {
    final data = doc.data()!;
    return LikePostModel(
      postId: postId,
      userId: doc.id, // docId = userId
      createdAt: data['createdAt'],
    );
  }
}
