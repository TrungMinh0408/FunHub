import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:funhub/pages/user_timeline_page.dart';

class FriendsPage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const FriendsPage({super.key, required this.userDoc});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get currentUserId => widget.userDoc.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================= Build avatar with navigation =================
  Widget buildAvatarWithNavigation(DocumentSnapshot userDoc, {double radius = 24}) {
    final data = userDoc.data() as Map<String, dynamic>? ?? {};
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonalProfilePage(userDoc: userDoc),
          ),
        );
      },
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.deepPurple,
        backgroundImage: (data['avatar'] != null && data['avatar'].toString().isNotEmpty)
            ? NetworkImage(data['avatar'])
            : null,
        child: (data['avatar'] == null || data['avatar'].toString().isEmpty)
            ? Text(
          (data['name'] ?? 'U').toString().trim()[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ===== SEARCH BAR =====
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm bạn bè...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
              onChanged: (v) => setState(() {}),
            ),
          ),

          // ===== TAB BAR =====
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),

          // ===== TAB VIEW =====
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_searchCtrl.text.isNotEmpty) {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .where('name',
            isGreaterThanOrEqualTo: _searchCtrl.text,
            isLessThanOrEqualTo: _searchCtrl.text + '\uf8ff')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs
              .where((doc) => doc.id != currentUserId)
              .toList();

          if (users.isEmpty) return const Center(child: Text('Không tìm thấy người dùng'));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  leading: buildAvatarWithNavigation(doc),
                  title: Text(data['name'] ?? 'User'),
                  subtitle: Text('@${data['username'] ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.deepPurple),
                    onPressed: () async {
                      await _firestore.collection('friends').add({
                        'from': currentUserId,
                        'to': doc.id,
                        'status': 'pending',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã gửi lời mời')));
                    },
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      // NORMAL FRIENDS LIST
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('friends').where('status', isEqualTo: 'accepted').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final friends = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['from'] == currentUserId || data['to'] == currentUserId;
          }).toList();

          if (friends.isEmpty) return const Center(child: Text('Không có bạn bè'));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final doc = friends[index];
              final data = doc.data() as Map<String, dynamic>;
              final friendId = data['from'] == currentUserId ? data['to'] : data['from'];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(friendId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};

                  if (userSnap.data!.id == currentUserId) return const SizedBox();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: buildAvatarWithNavigation(userSnap.data!),
                      title: Text(userData['name'] ?? 'User'),
                      subtitle: Text('@${userData['username'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () async {
                          await _firestore.collection('friends').doc(doc.id).delete();
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('friends').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final requests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['to'] == currentUserId &&
              (data['fromName'] ?? '').toString().toLowerCase().contains(_searchCtrl.text.toLowerCase());
        }).toList();

        if (requests.isEmpty) return const Center(child: Text('Không có lời mời'));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final fromId = data['from'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(fromId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();

                final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    leading: buildAvatarWithNavigation(userSnap.data!),
                    title: Text(userData['name'] ?? 'User'),
                    subtitle: Text('@${userData['username'] ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () async {
                            await _firestore.collection('friends').doc(doc.id).update({'status': 'accepted'});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () async {
                            await _firestore.collection('friends').doc(doc.id).delete();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ===================== User Profile Page =====================
class UserProfilePage extends StatelessWidget {
  final DocumentSnapshot userDoc;

  const UserProfilePage({super.key, required this.userDoc});

  @override
  Widget build(BuildContext context) {
    final data = userDoc.data() as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: Text(data['name'] ?? 'User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: (data['avatar'] ?? '').toString().startsWith('http')
                  ? NetworkImage(data['avatar'])
                  : null,
              child: (data['avatar'] ?? '').toString().isEmpty
                  ? Text(
                (data['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 40),
              )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              data['name'] ?? 'User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            // Bạn có thể thêm email, bio, vv.
          ],
        ),
      ),
    );
  }
}
