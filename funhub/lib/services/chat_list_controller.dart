import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_model.dart';

class ChatListController {
  final String currentUserId;
  final List<String> friendsIds;

  ChatListController({
    required this.currentUserId,
    required this.friendsIds,
  });

  Stream<List<ChatModel>> getChatsStream() {
    final firestore = FirebaseFirestore.instance;

    final chatStream = firestore
        .collection('chats')
        .where('userIds', arrayContains: currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => ChatModel.fromDoc(d)).toList());

    final dummyChats = friendsIds.map((fid) {
      return ChatModel(
        chatId: '',
        type: 'private',
        userIds: [currentUserId, fid],
        admins: [currentUserId],
        ownerId: currentUserId,
        lastMessage: '',
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();

    return chatStream.map((realChats) {
      final filteredDummy = dummyChats.where((dummy) {
        return !realChats.any((real) =>
        real.type == 'private' &&
            real.userIds.length == 2 &&
            real.userIds.toSet().containsAll(dummy.userIds));
      }).toList();

      return [...realChats, ...filteredDummy];
    });
  }
}

