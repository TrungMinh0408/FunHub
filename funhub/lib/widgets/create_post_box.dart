import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class CreatePostBox extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final VoidCallback onPostCreated;

  const CreatePostBox({
    super.key,
    required this.userDoc,
    required this.onPostCreated,
  });

  @override
  State<CreatePostBox> createState() => _CreatePostBoxState();
}

class _CreatePostBoxState extends State<CreatePostBox> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _contentCtrl = TextEditingController();

  final List<File> _mediaFiles = [];
  final List<String> _mediaTypes = [];

  bool posting = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80);
    if (files != null) {
      for (var f in files) {
        _mediaFiles.add(File(f.path));
        _mediaTypes.add('image');
      }
      setState(() {});
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _mediaFiles.add(File(video.path));
      _mediaTypes.add('video');
      setState(() {});
    }
  }

  Future<List<Map<String, dynamic>>> _uploadMedia() async {
    const cloudName = "dofrrrfnm";
    const uploadPreset = "funhub";

    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < _mediaFiles.length; i++) {
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/${_mediaTypes[i] == 'image' ? 'image' : 'video'}/upload",
      );

      final request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          _mediaFiles[i].path,
        ));

      final res = await request.send();
      final json = jsonDecode(await res.stream.bytesToString());

      result.add({
        'url': json['secure_url'],
        'type': _mediaTypes[i],
      });
    }
    return result;
  }

  Future<void> _createPost() async {
    if (_contentCtrl.text.trim().isEmpty && _mediaFiles.isEmpty) return;

    setState(() => posting = true);

    try {
      final media = await _uploadMedia();
      final data = widget.userDoc.data() as Map<String, dynamic>?;

      await _firestore.collection('posts').add({
        'content': _contentCtrl.text.trim(),
        'userId': widget.userDoc.id,
        'userName': data?['name'] ?? 'Người dùng',
        'userAvatar': data?['avatar'],
        'media': media,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _contentCtrl.clear();
      _mediaFiles.clear();
      _mediaTypes.clear();

      widget.onPostCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đăng bài thất bại: $e")),
      );
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.userDoc.data() as Map<String, dynamic>?;

    final avatarUrl = data?['avatar'] as String?;
    final userName  = data?['name'] as String?;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blue.shade300,
                backgroundImage:
                (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                  (userName != null && userName.isNotEmpty)
                      ? userName.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    hintText: "Bạn đang nghĩ gì?",
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                ),
              ),
            ],
          ),

          const Divider(),

          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImages,
              ),
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: _pickVideo,
              ),
              const Spacer(),
              posting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : SizedBox(
                height: 40,
                width: 90, // 👈 BẮT BUỘC
                child: ElevatedButton(
                  onPressed: _createPost,
                  child: const Text("Đăng"),
                ),
              ),
            ],
          ),
          if (_mediaFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaFiles.length,
                  itemBuilder: (context, index) {
                    final file = _mediaFiles[index];
                    final type = _mediaTypes[index];

                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black12,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: type == 'image'
                                ? Image.file(
                              file,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// ❌ NÚT XOÁ
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _mediaFiles.removeAt(index);
                                _mediaTypes.removeAt(index);
                              });
                            },
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black87,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
