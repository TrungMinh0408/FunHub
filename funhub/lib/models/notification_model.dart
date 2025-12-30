import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;          // id document trong Firestore
  final String toUserId;
  final String? fromUserId; // null nếu system
  final String type;        // like, comment, follow, system, ...
  final String? postId;     // null nếu không liên quan bài viết
  final String message;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.toUserId,
    this.fromUserId,
    required this.type,
    this.postId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  // Tạo object từ Firestore snapshot
  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      toUserId: data['toUserId'] ?? '',
      fromUserId: data['fromUserId'],
      type: data['type'] ?? 'system',
      postId: data['postId'],
      message: data['message'] ?? '',
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Chuyển object thành Map để ghi Firestore
  Map<String, dynamic> toMap() {
    return {
      'toUserId': toUserId,
      'fromUserId': fromUserId,
      'type': type,
      'postId': postId,
      'message': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
