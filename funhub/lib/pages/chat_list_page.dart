import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../services/chat_list_controller.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const ChatListPage({super.key, required this.userDoc});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String currentUserId;
  late ChatListController controller;

  List<DocumentSnapshot> friendsDocs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.userDoc.id;
    _init();
  }

  Future<void> _init() async {
    await _loadFriends();

    controller = ChatListController(
      currentUserId: currentUserId,
      friendsIds: friendsDocs.map((e) => e.id).toList(),
    );

    setState(() => isLoading = false);
  }

  // ================= LOAD FRIENDS =================

  Future<void> _loadFriends() async {
    final snap = await _firestore
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendIds = snap.docs
        .where((doc) {
      final d = doc.data();
      return d['from'] == currentUserId || d['to'] == currentUserId;
    })
        .map((doc) {
      final d = doc.data();
      return d['from'] == currentUserId ? d['to'] : d['from'];
    })
        .cast<String>()
        .toList();

    friendsDocs = await Future.wait(
      friendIds.map((id) => _firestore.collection('users').doc(id).get()),
    );
  }

  // ================= OPEN PRIVATE CHAT =================

  Future<void> _openPrivateChat(
      BuildContext context,
      String friendId,
      DocumentSnapshot friendDoc,
      ) async {
    final snap = await _firestore
        .collection('chats')
        .where('type', isEqualTo: 'private')
        .where('userIds', arrayContains: currentUserId)
        .get();

    DocumentSnapshot? chatDoc;

    for (final doc in snap.docs) {
      final users = List<String>.from(doc['userIds']);
      if (users.length == 2 && users.contains(friendId)) {
        chatDoc = doc;
        break;
      }
    }

    if (chatDoc == null) {
      final ids = [currentUserId, friendId]..sort();

      final ref = await _firestore.collection('chats').add({
        'type': 'private',
        'userIds': ids,
        'lastMessage': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      chatDoc = await ref.get();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          currentUserId: currentUserId,
          chatModel: ChatModel.fromDoc(chatDoc!),
          friendDoc: friendDoc,
        ),
      ),
    );
  }

  // ================= CREATE GROUP =================

  Future<void> _createGroup(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final Set<String> selected = {};

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: const Text('Tạo group'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Tên group'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: friendsDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        return CheckboxListTile(
                          value: selected.contains(doc.id),
                          title: Text(data['name'] ?? 'User'),
                          onChanged: (v) {
                            setDialog(() {
                              v == true
                                  ? selected.add(doc.id)
                                  : selected.remove(doc.id);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || selected.isEmpty) return;

                  Navigator.pop(context);

                  try {
                    final ref = await _firestore.collection('chats').add({
                      'type': 'group',
                      'name': nameCtrl.text.trim(),
                      'userIds': [currentUserId, ...selected],
                      'admins': [currentUserId],
                      'lastMessage': '',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    final chatSnapshot = await ref.get();

                    if (!chatSnapshot.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tạo group thất bại')),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          currentUserId: currentUserId,
                          chatModel: ChatModel.fromDoc(chatSnapshot),
                          friendDoc: widget.userDoc, // Group chat không cần friendDoc
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                },
                child: const Text('Tạo'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => _createGroup(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: controller.getChatsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!;

          if (chats.isEmpty) {
            return const Center(child: Text('Chưa có đoạn chat'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];

              // ========== GROUP ==========
              if (chat.type == 'group') {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(chat.name ?? 'Group'),
                  subtitle: Text(
                    chat.lastMessage.isNotEmpty
                        ? chat.lastMessage
                        : 'Chưa có tin nhắn',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          currentUserId: currentUserId,
                          chatModel: chat,
                          friendDoc: widget.userDoc,
                        ),
                      ),
                    );
                  },
                );
              }

              // ========== PRIVATE ==========
              final friendId =
              chat.userIds.firstWhere((id) => id != currentUserId);

              final friendDoc = friendsDocs.firstWhere(
                    (d) => d.id == friendId,
                orElse: () => widget.userDoc,
              );

              final friendData =
                  friendDoc.data() as Map<String, dynamic>? ?? {};

              final avatarUrl = (friendData['avatar'] ?? '').toString();
              final name = (friendData['name'] ?? 'User').toString();

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
                title: Text(name),
                subtitle: Text(
                  chat.lastMessage.isNotEmpty
                      ? chat.lastMessage
                      : 'Chưa có tin nhắn',
                ),
                onTap: () => _openPrivateChat(
                  context,
                  friendId,
                  friendDoc,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
