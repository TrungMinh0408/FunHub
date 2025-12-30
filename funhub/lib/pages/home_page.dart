import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:funhub/pages/user_timeline_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/create_post_box.dart';
import '../widgets/post_card.dart';

class HomePage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const HomePage({super.key, required this.userDoc});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollCtrl = ScrollController();

  final List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;

  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    if (_loading) return;
    _loading = true;

    final query = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    _posts.clear();
    _posts.addAll(query.docs);
    _lastDoc = query.docs.isNotEmpty ? query.docs.last : null;
    _hasMore = query.docs.length == _pageSize;

    _loading = false;
    setState(() {});
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading || _lastDoc == null) return;
    _loading = true;

    final query = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDoc!)
        .limit(_pageSize)
        .get();

    _posts.addAll(query.docs);
    _lastDoc = query.docs.isNotEmpty ? query.docs.last : _lastDoc;
    _hasMore = query.docs.length == _pageSize;

    _loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [

          /// 🔹 CREATE POST BOX
          SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity, // 🔥 BẮT BUỘC
              child: CreatePostBox(
                userDoc: widget.userDoc,
                onPostCreated: _loadPosts,
              ),
            ),
          ),


          /// 🔹 POST LIST
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index >= _posts.length) {
                  return _hasMore
                      ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : const SizedBox();
                }

                final doc = _posts[index];
                return PostCard(
                  postId: doc.id,
                  postData: doc.data() as Map<String, dynamic>,
                  userDoc: widget.userDoc,
                  onPostChanged: _loadPosts,
                );
              },
              childCount: _posts.length + 1,
            ),
          ),
        ],
      ),
    );
  }

}




