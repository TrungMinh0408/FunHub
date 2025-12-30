import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final ChatModel chatModel;
  final DocumentSnapshot friendDoc;

  const ChatPage({
    super.key,
    required this.currentUserId,
    required this.chatModel,
    required this.friendDoc,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatModel.chatId;
  }

  Future<void> _confirmDeleteMessage(MessageModel msg) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tin nhắn?'),
        content: const Text('Tin nhắn sẽ bị xóa vĩnh viễn'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .doc(msg.id)
                  .delete();

              Navigator.pop(context);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
  Stream<List<DocumentSnapshot>> _groupMembersStream() {
    return _firestore.collection('chats').doc(_chatId).snapshots().asyncMap(
          (chatSnap) async {
        final data = chatSnap.data() as Map<String, dynamic>? ?? {};
        final userIds = List<String>.from(data['userIds'] ?? []);

        if (userIds.isEmpty) return [];

        final List<DocumentSnapshot> users = [];

        for (int i = 0; i < userIds.length; i += 10) {
          final batch = userIds.sublist(
            i,
            i + 10 > userIds.length ? userIds.length : i + 10,
          );

          final snap = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          users.addAll(snap.docs);
        }

        return users;
      },
    );
  }

  // ================= SEND MESSAGE =================

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();

    final chatRef = _firestore.collection('chats').doc(_chatId);

    await chatRef.collection('messages').add({
      'senderId': widget.currentUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false, // 👈 thêm dòng này
    });

    await chatRef.update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'clear') {
      _confirmClearChat();
    }
  }

  Future<void> _confirmClearChat() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa lịch sử chat?'),
        content: const Text('Tất cả tin nhắn sẽ bị xóa'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final batch = _firestore.batch();
              final msgs = await _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .get();

              for (var d in msgs.docs) {
                batch.delete(d.reference);
              }

              await batch.commit();

              await _firestore.collection('chats').doc(_chatId).update({
                'lastMessage': '',
              });

              Navigator.pop(context);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> addMemberToGroup(String userId) async {
    await _firestore.collection('chats').doc(_chatId).update({
      'userIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeMemberFromGroup(String userId) async {
    await _firestore.collection('chats').doc(_chatId).update({
      'userIds': FieldValue.arrayRemove([userId]),
    });
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAddMemberDialog() {
    final TextEditingController ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm thành viên'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Nhập userId',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final userId = ctrl.text.trim();
              if (userId.isNotEmpty) {
                await _addMember(userId);
              }
              Navigator.pop(context);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }


  Future<void> _addMember(String userId) async {
    await _firestore.collection('chats').doc(_chatId).update({
      'userIds': FieldValue.arrayUnion([userId]),
    });
  }

  void _showRemoveMemberDialog() {
    final TextEditingController ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Nhập userId',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final userId = ctrl.text.trim();
              if (userId.isNotEmpty) {
                await _removeMember(userId);
              }
              Navigator.pop(context);
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _removeMember(String userId) async {
    await _firestore.collection('chats').doc(_chatId).update({
      'userIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> _deleteGroup() async {
    final chatRef = _firestore.collection('chats').doc(_chatId);

    final messages = await chatRef.collection('messages').get();
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }

    await chatRef.delete();

    if (mounted) {
      Navigator.pop(context); // đóng bottomsheet
      Navigator.pop(context); // quay về chat list
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(msg.id)
        .update({
      'isDeleted': true,
      'text': 'Tin nhắn này đã bị xóa',
    });
  }

  void _openGroupManage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Quản lý thành viên',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              Expanded(
                child: StreamBuilder<List<DocumentSnapshot>>(
                  stream: _groupMembersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data!;

                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (_, index) {
                        final u = members[index];
                        final data =
                            u.data() as Map<String, dynamic>? ?? {};

                        final isAdmin =
                        widget.chatModel.admins.contains(u.id);
                        final isMe = u.id == widget.currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                            (data['avatar'] ?? '').toString().startsWith('http')
                                ? NetworkImage(data['avatar'])
                                : null,
                            child: (data['avatar'] ?? '').toString().isEmpty
                                ? Text(
                              (data['name'] ?? 'U')[0].toUpperCase(),
                            )
                                : null,
                          ),
                          title: Text(data['name'] ?? 'User'),
                          subtitle: isAdmin
                              ? const Text('Admin',
                              style: TextStyle(color: Colors.blue))
                              : null,

                          trailing: (!isMe &&
                              widget.chatModel.admins
                                  .contains(widget.currentUserId))
                              ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'remove') {
                                await removeMemberFromGroup(u.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Xóa khỏi group',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),

              if (widget.chatModel.admins.contains(widget.currentUserId))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Thêm thành viên'),
                    onPressed: _openAddMemberPicker,
                  ),
                ),

              if (widget.chatModel.ownerId == widget.currentUserId)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton(
                    onPressed: _deleteGroup,
                    child: const Text(
                      'Xóa group',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddMemberPicker() async {
    final chatSnap =
    await _firestore.collection('chats').doc(_chatId).get();

    final chatData = chatSnap.data() as Map<String, dynamic>? ?? {};
    final memberIds = List<String>.from(chatData['userIds'] ?? []);

    final usersSnap = await _firestore.collection('users').get();

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: usersSnap.docs
            .where((u) => !memberIds.contains(u.id))
            .map((u) {
          final data = u.data() as Map<String, dynamic>? ?? {};
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
              (data['avatar'] ?? '').toString().startsWith('http')
                  ? NetworkImage(data['avatar'])
                  : null,
              child: !(data['avatar'] ?? '').toString().startsWith('http')
                  ? Text((data['name'] ?? 'U')[0].toUpperCase())
                  : null,
            ),
            title: Text(data['name'] ?? 'User'),
            onTap: () async {
              await addMemberToGroup(u.id);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }


  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final friendData =
        widget.friendDoc.data() as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatModel.type == 'group'
              ? (widget.chatModel.name ?? 'Group')
              : (widget.friendDoc.data() as Map<String, dynamic>? ?? {})['name'] ?? 'User',
        ),
        actions: widget.chatModel.type == 'group' &&
            widget.chatModel.admins.contains(widget.currentUserId)
            ? [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openGroupManage,
          )
        ]
            : [],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs
            .map((d) => MessageModel.fromDoc(d))
            .toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index]; // ✅ CÓ msg
            final isMe =
                msg.senderId == widget.currentUserId; // ✅ CÓ isMe

            return GestureDetector(
              onLongPress: isMe
                  ? () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: ListTile(
                      leading:
                      const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        'Xóa tin nhắn',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessage(msg); // ✅ ĐÚNG KIỂU
                      },
                    ),
                  ),
                );
              }
                  : null,
              child: Align(
                alignment:
                isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.deepPurple
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    msg.isDeleted
                        ? 'Tin nhắn này đã bị xóa'
                        : msg.text,
                    style: TextStyle(
                      fontStyle: msg.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          )
        ],
      ),
    );
  }
}

