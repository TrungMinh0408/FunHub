import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_item.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final List<MediaItem> media;
  final Timestamp createdAt;
  final int likeCount;
  final int commentCount;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.media,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  /// Firestore → Object
  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PostModel(
      id: doc.id,
      userId: data['userId'],
      content: data['content'] ?? '',
      media: (data['media'] as List<dynamic>? ?? [])
          .map((e) => MediaItem.fromMap(e))
          .toList(),
      createdAt: data['createdAt'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }

  /// Object → Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'media': media.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    };
  }
}
