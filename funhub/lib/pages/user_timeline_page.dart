import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../widgets/create_post_box.dart';
import '../widgets/followercount_click.dart';
import '../widgets/post_card.dart';
import 'chat_list_page.dart';
import 'chat_page.dart';
import 'follow_list_sheet.dart';

class PersonalProfilePage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const PersonalProfilePage({super.key, required this.userDoc});

  @override
  State<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends State<PersonalProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String _currentUserId;
  late final String _profileUserId;
  late final bool _isOwner;

  bool _isFollowing = false;
  bool _isFollowLoading = false;

  int _followerCount = 0;
  int _followingCount = 0;

  static const int _pageSize = 10;
  final List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _profileUserId = widget.userDoc.id;
    _isOwner = _currentUserId == _profileUserId;

    _loadFollowStats();
    if (!_isOwner) _checkIsFollowing();
    _loadInitialPosts();
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _openPrivateChatFromProfile() async {
    /// 👑 Nếu là chủ tài khoản → mở ChatListPage
    if (_isOwner) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatListPage(userDoc: widget.userDoc),
        ),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;

    /// 1️⃣ Tìm chat private đã tồn tại
    final snap = await firestore
        .collection('chats')
        .where('type', isEqualTo: 'private')
        .where('userIds', arrayContains: _currentUserId)
        .get();

    DocumentSnapshot? chatDoc;

    for (final doc in snap.docs) {
      final users = List<String>.from(doc['userIds']);
      if (users.length == 2 && users.contains(_profileUserId)) {
        chatDoc = doc;
        break;
      }
    }

    /// 2️⃣ Nếu chưa có → tạo chat
    if (chatDoc == null) {
      final ids = [_currentUserId, _profileUserId]..sort();

      final ref = await firestore.collection('chats').add({
        'type': 'private',
        'userIds': ids,
        'admins': [],
        'ownerId': _currentUserId,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      chatDoc = await ref.get();
    }

    /// 3️⃣ MỞ CHAT PAGE
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          currentUserId: _currentUserId,
          chatModel: ChatModel.fromDoc(chatDoc!),
          friendDoc: widget.userDoc, // profile đang xem
        ),
      ),
    );
  }


  // ================= FOLLOW LOGIC =================
  Future<void> _checkIsFollowing() async {
    final doc = await _firestore
        .collection('users')
        .doc(_profileUserId)
        .collection('followers')
        .doc(_currentUserId)
        .get();

    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading || _isOwner) return;
    setState(() => _isFollowLoading = true);

    final currentUserRef = _firestore.collection('users').doc(_currentUserId);
    final profileUserRef = _firestore.collection('users').doc(_profileUserId);
    final followerRef = profileUserRef.collection('followers').doc(_currentUserId);
    final followingRef = currentUserRef.collection('following').doc(_profileUserId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(followerRef);

        if (snap.exists) {
          tx.delete(followerRef);
          tx.delete(followingRef);
          tx.update(profileUserRef, {'followerCount': FieldValue.increment(-1)});
          tx.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});
          _isFollowing = false;
          _followerCount--;
        } else {
          tx.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});
          tx.set(followingRef, {'createdAt': FieldValue.serverTimestamp()});
          tx.update(profileUserRef, {'followerCount': FieldValue.increment(1)});
          tx.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
          _isFollowing = true;
          _followerCount++;
        }
      });

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _loadFollowStats() async {
    final snap = await _firestore.collection('users').doc(_profileUserId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (mounted) {
      setState(() {
        _followerCount = data['followerCount'] ?? 0;
        _followingCount = data['followingCount'] ?? 0;
      });
    }
  }

  // ================= POSTS =================
  void _onScroll() {
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;
    _isLoading = true;

    final query = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: _profileUserId)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    _posts.addAll(query.docs);
    _lastDoc = query.docs.isNotEmpty ? query.docs.last : null;
    if (query.docs.length < _pageSize) _hasMore = false;

    _isLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore || _lastDoc == null) return;
    _isLoading = true;

    final query = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: _profileUserId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDoc!)
        .limit(_pageSize)
        .get();

    _posts.addAll(query.docs);
    _lastDoc = query.docs.isNotEmpty ? query.docs.last : _lastDoc;
    if (query.docs.length < _pageSize) _hasMore = false;

    _isLoading = false;
    if (mounted) setState(() {});
  }

  void _showFollowList({required bool isFollower}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: FollowListSheet(userId: _profileUserId, isFollower: isFollower),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.deepPurple,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildActionBar()),
          SliverPadding(
            padding: const EdgeInsets.only(top: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index >= _posts.length) {
                    return _hasMore
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                        : const SizedBox(height: 50);
                  }

                  final doc = _posts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: PostCard(
                      postId: doc.id,
                      postData: doc.data() as Map<String, dynamic>,
                      userDoc: widget.userDoc,
                    ),
                  );
                },
                childCount: _posts.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final data = widget.userDoc.data() as Map<String, dynamic>? ?? {};
    return Stack(
      children: [
        Container(
          height: 160,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.deepPurple, Colors.indigo]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 110, left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.deepPurple,
                  backgroundImage: (data['avatar'] != null && data['avatar'].toString().isNotEmpty)
                      ? NetworkImage(data['avatar'])
                      : null,
                  child: (data['avatar'] == null || data['avatar'].toString().isEmpty)
                      ? Text(
                    (data['name'] != null && data['name'].toString().isNotEmpty)
                        ? data['name'].toString().trim()[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(data['name'] ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('@${data['username'] ?? 'username'}', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _isOwner ? _buildCreatePostBtn() : _buildFollowBtns(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(_profileUserId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final followers = data['followerCount'] ?? 0;
                  final following = data['followingCount'] ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('Bài viết', _posts.length.toString()),
                      ClickableStat(
                        label: 'Đang theo dõi',
                        value: following.toString(),
                        onTap: () => _showFollowList(isFollower: false),
                      ),
                      ClickableStat(
                        label: 'Follower',
                        value: followers.toString(),
                        onTap: () => _showFollowList(isFollower: true),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostBtn() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: CreatePostBox(
                      userDoc: widget.userDoc,
                      onPostCreated: () {
                        // Callback VoidCallback
                        // Tự load lại danh sách bài viết
                        _refreshPosts();
                      },
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("Thêm bài viết"),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.mail_outline),
          onPressed: _openPrivateChatFromProfile,
        ),

      ],
    );
  }

// Hàm refresh danh sách post
  Future<void> _refreshPosts() async {
    _posts.clear();
    _lastDoc = null;
    _hasMore = true;
    await _loadInitialPosts();
  }

  Widget _buildFollowBtns() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isFollowLoading ? null : _toggleFollow,
            child: _isFollowLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isFollowing ? 'Đã theo dõi' : 'Theo dõi'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.mail_outline),
          onPressed: _openPrivateChatFromProfile,
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
