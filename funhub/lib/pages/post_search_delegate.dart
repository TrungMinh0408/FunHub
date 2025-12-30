import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/post_card.dart';

class PostSearchDelegate extends SearchDelegate {
  final DocumentSnapshot userDoc;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PostSearchDelegate({required this.userDoc});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final results = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final content = (data['content'] ?? '').toString().toLowerCase();
          return content.contains(query.toLowerCase());
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('Không tìm thấy bài viết nào'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (_, index) {
            final doc = results[index];
            return PostCard(
              postId: doc.id,
              postData: doc.data() as Map<String, dynamic>,
              userDoc: userDoc,
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(child: Text('Nhập từ khóa để tìm bài viết'));
  }
}
