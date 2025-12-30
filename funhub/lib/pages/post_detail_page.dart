import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/post_card.dart';

class PostDetailPage extends StatelessWidget {
  final String postId;
  final DocumentSnapshot userDoc;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.userDoc,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('posts').doc(postId).snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Post không tồn tại / bị xóa
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Bài viết không tồn tại'),
            );
          }

          final postDoc = snapshot.data!;
          final postData = postDoc.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              PostCard(
                postId: postDoc.id,
                postData: postData,
                userDoc: userDoc,
              ),
            ],
          );
        },
      ),
    );
  }
}
