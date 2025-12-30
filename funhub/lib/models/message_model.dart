import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.isDeleted,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'],
      text: data['text'],
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}
