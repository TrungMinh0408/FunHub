import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../pages/comment_sheet.dart';
import '../pages/home_page.dart';
import '../pages/user_timeline_page.dart';
import '../services/notification_service.dart';
import '../services/post_media_carousel.dart';

class PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final DocumentSnapshot userDoc;
  final VoidCallback? onPostChanged; // callback từ HomePage

  const PostCard({
    super.key,
    required this.postId,
    required this.postData,
    required this.userDoc,
    this.onPostChanged,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  Future<void> _toggleLike(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final uid = userDoc.id;
    final postRef = firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);
    final notifService = NotificationService();

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(likeRef);
      if (snap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});

        // Tạo notification
        final postOwnerId = postData['userId'] ?? '';
        await notifService.createLikeNotification(
          postId: postId,
          fromUserId: uid,
          fromUserName: userDoc['name'],
          toUserId: postOwnerId,
        );
      }
    });
  }

  Future<void> _toggleSavePost() async {
    final firestore = FirebaseFirestore.instance;
    final uid = userDoc.id;
    final saveRef =
    firestore.collection('users').doc(uid).collection('savedPosts').doc(postId);
    final snap = await saveRef.get();
    if (snap.exists) {
      await saveRef.delete();
    } else {
      await saveRef.set({'savedAt': FieldValue.serverTimestamp()});
    }
  }

  void _openCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => CommentSheet(
            postId: postId,
            userDoc: userDoc,
            scrollController: scrollCtrl,
            onCommentAdded: (String commentText) async {
              final notifService = NotificationService();
              final postOwnerId = postData['userId'] ?? '';
              await notifService.createCommentNotification(
                postId: postId,
                fromUserId: userDoc.id,
                fromUserName: userDoc['name'],
                commentText: commentText,
                toUserId: postOwnerId,
              );
              if (onPostChanged != null) onPostChanged!();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa bài viết?'),
        content: const Text('Bạn có chắc chắn muốn xóa bài viết này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );

    if (confirm == true) {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('posts').doc(postId).delete();

      final likes = await firestore.collection('posts').doc(postId).collection('likes').get();
      for (var doc in likes.docs) await doc.reference.delete();

      final comments =
      await firestore.collection('posts').doc(postId).collection('comments').get();
      for (var doc in comments.docs) await doc.reference.delete();

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bài viết đã xóa')));

      if (onPostChanged != null) onPostChanged!();
    }
  }

  Future<void> _editPost(BuildContext context) async {
    final TextEditingController _controller =
    TextEditingController(text: postData['content'] ?? '');
    List<Map<String, dynamic>> media = List<Map<String, dynamic>>.from(postData['media'] ?? []);
    final List<File> newMediaFiles = [];
    final List<String> newMediaTypes = [];
    final picker = ImagePicker();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chỉnh sửa bài viết'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'Nhập nội dung mới'),
                  ),
                  const SizedBox(height: 12),
                  if (media.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: media.length,
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: media[i]['type'] == 'image'
                                  ? Image.network(
                                media[i]['url'],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.videocam,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => media.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final files = await picker.pickMultiImage(imageQuality: 80);
                            if (files != null) {
                              setState(() {
                                for (var f in files) {
                                  newMediaFiles.add(File(f.path));
                                  newMediaTypes.add('image');
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.green[100],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.image_outlined, color: Colors.green),
                                SizedBox(width: 6),
                                Text('Thêm ảnh'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final video = await picker.pickVideo(source: ImageSource.gallery);
                            if (video != null) {
                              setState(() {
                                newMediaFiles.add(File(video.path));
                                newMediaTypes.add('video');
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.red[100],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.videocam_outlined, color: Colors.red),
                                SizedBox(width: 6),
                                Text('Thêm video'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // Upload new media
                List<Map<String, dynamic>> uploaded = [];
                const cloudName = "dofrrrfnm";
                const uploadPreset = "funhub";

                for (int i = 0; i < newMediaFiles.length; i++) {
                  final uri = Uri.parse(
                      "https://api.cloudinary.com/v1_1/$cloudName/${newMediaTypes[i] == 'image' ? 'image' : 'video'}/upload");
                  final request = http.MultipartRequest("POST", uri)
                    ..fields['upload_preset'] = uploadPreset
                    ..fields['folder'] = "posts/${userDoc.id}"
                    ..files.add(await http.MultipartFile.fromPath('file', newMediaFiles[i].path));

                  final res = await request.send();
                  final json = jsonDecode(await res.stream.bytesToString());
                  uploaded.add({
                    'url': json['secure_url'],
                    'type': newMediaTypes[i],
                    'public_id': json['public_id'],
                    'order': i,
                  });
                }

                final finalMedia = [...media, ...uploaded];

                await FirebaseFirestore.instance.collection('posts').doc(postId).update({
                  'content': _controller.text.trim(),
                  'media': finalMedia,
                });

                if (onPostChanged != null) onPostChanged!();

                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Bài viết đã cập nhật')));
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLikedUsers(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;

    final likesSnap = await firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .get();

    if (likesSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chưa có ai thích bài viết này'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final userIds = likesSnap.docs.map((d) => d.id).toList();

    // Firestore whereIn giới hạn 10
    List<DocumentSnapshot> userDocs = [];

    for (int i = 0; i < userIds.length; i += 10) {
      final batch = userIds.sublist(
        i,
        i + 10 > userIds.length ? userIds.length : i + 10,
      );

      final snap = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      userDocs.addAll(snap.docs);
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header với thanh kéo
            Container(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lượt thích (${userDocs.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Danh sách người dùng
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: userDocs.length,
                itemBuilder: (_, index) {
                  final u = userDocs[index];
                  final avatar = u['avatar'] ?? '';
                  final name = u['name'] ?? 'Người dùng';

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(postData['userId'])
                                  .snapshots(),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return CircleAvatar(
                                    radius: 26,
                                    backgroundColor:
                                    Theme.of(context).primaryColor.withOpacity(0.2),
                                  );
                                }

                                final u = snap.data!.data() as Map<String, dynamic>? ?? {};
                                final avatar = (u['avatar'] ?? '').toString();
                                final name = (u['name'] ?? '').toString();

                                return CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                  Theme.of(context).primaryColor.withOpacity(0.2),
                                  backgroundImage:
                                  avatar.startsWith('http') ? NetworkImage(avatar) : null,
                                  child: avatar.isEmpty
                                      ? Text(
                                    name.isNotEmpty ? name.trim()[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  )
                                      : null,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red[400],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Xem',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomePage(userDoc: u),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final media = (postData['media'] as List<dynamic>? ?? []);
    final avatarUrl = postData['userAvatar']?.toString() ?? '';
    final userName = postData['userName']?.toString() ?? '';

    Widget avatarWidget = InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () async {
        final postOwnerId = postData['userId'];
        if (postOwnerId == null) return;

        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(postOwnerId)
            .get();

        if (!context.mounted || !snap.exists) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonalProfilePage(userDoc: snap),
          ),
        );
      },
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        backgroundImage:
        (avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl.isEmpty)
            ? Text(
          userName.isNotEmpty
              ? userName.trim()[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        )
            : null,
      ),
    );


    final isOwner = userDoc.id == postData['userId'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                avatarWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(postData['userName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(_formatTime(postData['createdAt']),
                              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'edit') _editPost(context);
                      else if (value == 'delete') _deletePost(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
              ],
            ),
          ),

          // CONTENT
          if ((postData['content'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(postData['content'],
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ),

          // MEDIA
          if (media.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PostMediaCarousel(media: media),
            ),
          ],

          // STATS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: StreamBuilder<DocumentSnapshot>(
              stream: firestore.collection('posts').doc(postId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final likeCount = data['likeCount'] ?? 0;
                final commentCount = data['commentCount'] ?? 0;

                return Row(
                  children: [
                    if (likeCount > 0)
                      InkWell(
                        onTap: () => _showLikedUsers(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$likeCount',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (likeCount > 0 && commentCount > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),

                    if (commentCount > 0)
                      Text(
                        '$commentCount bình luận',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                  ],
                );
              },
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // ACTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // LIKE
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: firestore
                        .collection('posts')
                        .doc(postId)
                        .collection('likes')
                        .doc(userDoc.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final isLiked = snapshot.hasData && snapshot.data!.exists;
                      return InkWell(
                        onTap: () => _toggleLike(context),
                        onLongPress: () => _showLikedUsers(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.grey[600], size: 22),
                              const SizedBox(width: 6),
                              Text('Thích',
                                  style: TextStyle(
                                      color: isLiked ? Colors.red : Colors.grey[700],
                                      fontWeight: isLiked ? FontWeight.w600 : FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(width: 1, height: 24, color: Colors.grey[300]),

                // COMMENT
                Expanded(
                  child: InkWell(
                    onTap: () => _openCommentSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.grey[600], size: 22),
                          const SizedBox(width: 6),
                          Text('Bình luận',
                              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(width: 1, height: 24, color: Colors.grey[300]),

                // SAVE
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: firestore
                        .collection('users')
                        .doc(userDoc.id)
                        .collection('savedPosts')
                        .doc(postId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final isSaved = snapshot.hasData && snapshot.data!.exists;
                      return InkWell(
                        onTap: _toggleSavePost,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: isSaved ? Theme.of(context).primaryColor : Colors.grey[600], size: 22),
                              const SizedBox(width: 6),
                              Text('Lưu',
                                  style: TextStyle(
                                      color: isSaved ? Theme.of(context).primaryColor : Colors.grey[700],
                                      fontWeight: isSaved ? FontWeight.w600 : FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

  }
}
