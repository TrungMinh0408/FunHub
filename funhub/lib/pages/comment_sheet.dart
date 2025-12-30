import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comment_model.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  final DocumentSnapshot userDoc;
  final ScrollController? scrollController;
  final Function(String commentText)? onCommentAdded; // <-- thêm callback

  const CommentSheet({
    super.key,
    required this.postId,
    required this.userDoc,
    this.scrollController,
    this.onCommentAdded, // <-- nhận callback
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController ctrl = TextEditingController();
  String? replyTo;

  void _setReply(QueryDocumentSnapshot c) {
    setState(() {
      replyTo = c.id;
      ctrl.text = "@${c['userName']} ";
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    final replies = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .get();

    for (var r in replies.docs) {
      await r.reference.delete();
    }

    await commentRef.delete();

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    await postRef.update({'commentCount': FieldValue.increment(-(1 + replies.docs.length))});
  }

  Future<void> _editComment(String commentId, String newContent) async {
    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    await commentRef.update({
      'content': newContent,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleLikeComment(String commentId) async {
    final uid = widget.userDoc.id;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    final likeRef = commentRef.collection('likes').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(commentRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(commentRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> _send() async {
    if (ctrl.text.trim().isEmpty) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc();

    final comment = CommentModel(
      id: commentRef.id,
      postId: widget.postId,
      userId: widget.userDoc.id,
      userName: widget.userDoc['name'],
      userAvatar: widget.userDoc['avatar'],
      content: ctrl.text.trim(),
      parentCommentId: replyTo,
      createdAt: Timestamp.now(),
      likeCount: 0,
    );

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(commentRef, comment.toMap());
      tx.update(postRef, {'commentCount': FieldValue.increment(1)});
    });

    // Gọi callback nếu có
    if (widget.onCommentAdded != null) {
      widget.onCommentAdded!(ctrl.text.trim());
    }

    setState(() {
      ctrl.clear();
      replyTo = null;
    });
  }

  Widget _input() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: replyTo == null ? "Viết bình luận..." : "Trả lời...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentItem(QueryDocumentSnapshot c) {
    final commentId = c.id;
    final data = c.data() as Map<String, dynamic>;
    final likeCount = (data['likeCount'] ?? 0) as int;

    return ListTile(
      onTap: () => _setReply(c),
      leading: CircleAvatar(
        backgroundImage:
        (c['userAvatar'] ?? '') != '' ? NetworkImage(c['userAvatar']) : null,
        child: (c['userAvatar'] ?? '') == '' ? const Icon(Icons.person) : null,
      ),
      title: Text(
        c['userName'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['content']),
          const SizedBox(height: 6),
          Row(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .doc(commentId)
                    .collection('likes')
                    .doc(widget.userDoc.id)
                    .snapshots(),
                builder: (context, snap) {
                  final liked = snap.hasData && snap.data!.exists;
                  return IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _toggleLikeComment(commentId),
                  );
                },
              ),
              const SizedBox(width: 4),
              Text('$likeCount', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (value) async {
          if (value == 'edit') {
            ctrl.text = c['content'];
            replyTo = null;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Chỉnh sửa bình luận"),
                content: TextField(controller: ctrl),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Hủy"),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _editComment(c.id, ctrl.text.trim());
                      ctrl.clear();
                      Navigator.pop(context);
                    },
                    child: const Text("Lưu"),
                  ),
                ],
              ),
            );
          } else if (value == 'delete') {
            await _deleteComment(c.id);
          }
        },
        itemBuilder: (context) {
          if (c['userId'] == widget.userDoc.id) {
            return const [
              PopupMenuItem(value: 'edit', child: Text("Chỉnh sửa")),
              PopupMenuItem(value: 'delete', child: Text("Xóa")),
            ];
          } else {
            return const [
              PopupMenuItem(value: 'report', child: Text("Báo cáo")),
            ];
          }
        },
      ),
    );
  }

  Widget _buildComment(QueryDocumentSnapshot c, List<QueryDocumentSnapshot> all) {
    final replies = all.where((r) => r['parentCommentId'] == c.id).toList();
    bool showReplies = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _commentItem(c),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: StatefulBuilder(
              builder: (context, setSB) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showReplies) ...replies.map(_commentItem).toList(),
                    TextButton(
                      onPressed: () => setSB(() => showReplies = !showReplies),
                      child: Text(
                        showReplies
                            ? 'Ẩn trả lời'
                            : 'Xem ${replies.length} trả lời',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .collection('comments')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final all = snap.data!.docs;
              final roots = all.where((e) => e['parentCommentId'] == null).toList();
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: roots.length,
                itemBuilder: (_, i) => _buildComment(roots[i], all),
              );
            },
          ),
        ),
        _input(),
      ],
    );
  }
}
