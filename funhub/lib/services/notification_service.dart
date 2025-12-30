import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../pages/comment_sheet.dart';
import '../pages/home_page.dart';

/// Notification service
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createLikeNotification({
    required String postId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return; // ko gửi notification cho chính mình
    await _firestore.collection('notifications').add({
      'postId': postId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'type': 'like',
      'message': '$fromUserName đã thích bài viết của bạn',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createCommentNotification({
    required String postId,
    required String fromUserId,
    required String fromUserName,
    required String commentText,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return;
    await _firestore.collection('notifications').add({
      'postId': postId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'type': 'comment',
      'message': '$fromUserName đã bình luận: "$commentText"',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

