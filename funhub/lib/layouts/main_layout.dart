import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:funhub/pages/user_page.dart';

import '../pages/auth_page.dart';
import '../pages/chat_list_page.dart';
import '../pages/home_page.dart';
import '../pages/friend_page.dart';
import '../pages/notifications_page.dart';
import '../pages/post_search_delegate.dart';
import '../pages/user_timeline_page.dart';
import '../pages/saved_posts_page.dart';

class MainLayout extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const MainLayout({super.key, required this.userDoc});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;

  late final List<Widget> pages;

  final titles = const [
    'FunHub',
    'Bạn bè',
    'Trang cá nhân',
    'Bài đăng đã lưu',
  ];

  @override
  void initState() {
    super.initState();
    pages = [
      HomePage(userDoc: widget.userDoc),
      FriendsPage(userDoc: widget.userDoc),
      PersonalProfilePage(userDoc: widget.userDoc),
      SavedPostsPage(userDoc: widget.userDoc),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: PostSearchDelegate(userDoc: widget.userDoc),
              );
            },
          ),


          // ===== NÚT CHAT =====
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              // Mở trang danh sách chat
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatListPage(userDoc: widget.userDoc),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              if (widget.userDoc.id.isEmpty) return;

              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsPage(
                    userDoc: widget.userDoc,
                  ),
                ),
              );
            },
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Cài đặt'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
            onSelected: (v) async {
              if (v == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserPage(userDoc: widget.userDoc),
                  ),
                );
              }

              if (v == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: IndexedStack(
        index: _index,
        children: pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}
