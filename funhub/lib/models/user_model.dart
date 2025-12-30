import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final Timestamp createdAt;

  final int followerCount;
  final int followingCount;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.createdAt,
    required this.followerCount,
    required this.followingCount,
  });

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      avatar: data['avatar'] ?? '',
      createdAt: data['createdAt'],
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
      'followerCount': followerCount,
      'followingCount': followingCount,
    };
  }
}
