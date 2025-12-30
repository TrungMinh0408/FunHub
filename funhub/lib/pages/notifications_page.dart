import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:funhub/pages/post_detail_page.dart';
import '../models/notification_model.dart';
import '../pages/user_page.dart';

class NotificationsPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const NotificationsPage({
    super.key,
    required this.userDoc,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AppNotification>> _getNotificationsFuture() async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: widget.userDoc.id)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AppNotification.fromDoc(doc))
        .toList();
  }

  Future<void> _markAsRead(AppNotification notif) async {
    if (!notif.read) {
      try {
        await _firestore
            .collection('notifications')
            .doc(notif.id)
            .update({'read': true});
      } catch (e) {
        debugPrint("Đánh dấu đã đọc thất bại: $e");
      }
    }
  }

  void _onTapNotification(AppNotification notif) async {
    Future.delayed(const Duration(milliseconds: 300), () {
      _markAsRead(notif);
    });

    if (!mounted) return;

    try {
      if ((notif.type == 'like' || notif.type == 'comment') &&
          notif.postId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailPage(
              postId: notif.postId!,
              userDoc: widget.userDoc,
            ),
          ),
        );
        return;
      }

      if (notif.type == 'follow' && notif.fromUserId != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(notif.fromUserId)
            .get();

        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Người dùng không tồn tại')),
          );
          return;
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserPage(userDoc: userDoc)),
        );
        return;
      }

      if (notif.type == 'system') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notif.message)),
        );
      }
    } catch (e) {
      debugPrint("Lỗi xử lý notification: $e");
    }
  }

  // ================== HIỂN THỊ ==================

  String _buildNotificationText(AppNotification notif) {
    switch (notif.type) {
      case 'like':
        return 'đã thích bài viết của bạn';
      case 'comment':
        return 'đã bình luận bài viết của bạn';
      case 'follow':
        return 'đã kết bạn với bạn';
      case 'system':
        return notif.message;
      default:
        return notif.message;
    }
  }

  IconData _buildNotificationIcon(AppNotification notif) {
    switch (notif.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _buildIconColor(AppNotification notif) {
    switch (notif.type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: FutureBuilder<List<AppNotification>>(
        future: _getNotificationsFuture(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(child: Text('Chưa có thông báo nào'));
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final notif = notifications[index];

              return ListTile(
                onTap: () => _onTapNotification(notif),
                leading: CircleAvatar(
                  backgroundColor:
                  notif.read ? Colors.grey[300] : Colors.deepPurple[200],
                  child: Icon(
                    _buildNotificationIcon(notif),
                    color: _buildIconColor(notif),
                  ),
                ),
                title: Text(
                  _buildNotificationText(notif),
                  style: TextStyle(
                    fontWeight:
                    notif.read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(_formatTime(notif.createdAt)),
                trailing: notif.read
                    ? null
                    : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                tileColor:
                notif.read ? Colors.white : Colors.deepPurple[50],
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}
