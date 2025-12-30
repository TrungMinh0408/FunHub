import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/user_page.dart';

class FollowListSheet extends StatelessWidget {
  final String userId;
  final bool isFollower;

  const FollowListSheet({
    super.key,
    required this.userId,
    required this.isFollower,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(isFollower ? 'followers' : 'following');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isFollower ? 'Follower' : 'Đang theo dõi',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: ref.get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(
                  child: Text('Danh sách trống'),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, index) {
                  final targetUserId = docs[index].id;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(targetUserId)
                        .get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) {
                        return const SizedBox();
                      }

                      final data =
                      userSnap.data!.data() as Map<String, dynamic>;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                          (data['avatar']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(data['avatar'])
                              : null,
                          child: (data['avatar']?.toString().isEmpty ?? true)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(data['name'] ?? 'User'),
                        subtitle: Text('@${data['username'] ?? ''}'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserPage(userDoc: userSnap.data!),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
