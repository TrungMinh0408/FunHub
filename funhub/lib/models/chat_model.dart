import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final String type;
  final String? name;
  final String? avatar;
  final List<String> userIds;
  final List<String> admins;
  final String ownerId;
  final String lastMessage;
  final DateTime lastUpdated;
  final Map<String, dynamic>? lastMessageData; // ✅ THÊM

  ChatModel({
    required this.chatId,
    required this.type,
    this.name,
    this.avatar,
    required this.userIds,
    required this.admins,
    required this.ownerId,
    required this.lastMessage,
    required this.lastUpdated,
    this.lastMessageData,
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    return ChatModel(
      chatId: doc.id,
      type: d['type'] ?? 'private',
      name: d['name'],
      avatar: d['avatar'],
      userIds: List<String>.from(d['userIds'] ?? []),
      admins: List<String>.from(d['admins'] ?? []),
      ownerId: d['ownerId'] ?? '',
      lastMessage: d['lastMessage'] ?? '',
      lastUpdated:
      (d['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageData: d['lastMessageData'], // ✅ FIX
    );
  }
}
