import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'auth_page.dart';

class UserPage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const UserPage({super.key, required this.userDoc});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  String? _avatarUrl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    final data = widget.userDoc.data() as Map<String, dynamic>;
    _nameCtrl.text = data['name'] ?? '';
    _avatarUrl = data['avatar'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ================= CLOUDINARY =================
  Future<String> _uploadAvatar(File file) async {
    const cloudName = "dofrrrfnm";
    const uploadPreset = "funhub";

    try {
      final uri =
      Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      final request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = "avatars/${widget.userDoc.id}"
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final res = await request.send();
      final body = await res.stream.bytesToString();
      final json = jsonDecode(body);

      if (json['secure_url'] == null) {
        throw Exception("Upload avatar failed");
      }

      return json['secure_url'];
    } catch (e) {
      _showMsg("Upload avatar thất bại: $e");
      rethrow;
    }
  }

  // ================= PICK IMAGE =================
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    if (!mounted) return;
    setState(() => _saving = true);

    try {
      final url = await _uploadAvatar(File(img.path));
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (_) {
      // đã showMsg trong _uploadAvatar
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================= CHANGE PASSWORD =================
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showMsg("Không tìm thấy email người dùng");
      return;
    }

    final hasPassword = user.providerData.any(
          (p) => p.providerId == 'password',
    );

    if (!hasPassword) {
      _showMsg(
          "Tài khoản này đăng nhập bằng Google/Facebook, không có mật khẩu");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      _showMsg("Đã gửi email đổi mật khẩu. Vui lòng kiểm tra hộp thư");
    } catch (e) {
      _showMsg("Gửi email thất bại: $e");
    }
  }

  // ================= SHOW SNACKBAR =================
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .update({
        'name': _nameCtrl.text.trim(),
        'avatar': _avatarUrl,
      });

      // 🔥 RELOAD USER DOC
      final newSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userDoc.id)
          .get();

      if (!mounted) return;

      setState(() {
        _avatarUrl = newSnap['avatar'];
        _nameCtrl.text = newSnap['name'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã lưu thông tin")),
      );
    } catch (e) {
      _showMsg("Lưu thông tin thất bại: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================= CHANGE EMAIL DIALOG =================
  void _showChangeEmailDialog() {
    final newEmailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Đổi email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email mới",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Mật khẩu hiện tại",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              newEmailCtrl.dispose();
              passCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            child: const Text("Xác nhận"),
            onPressed: () async {
              newEmailCtrl.dispose();
              passCtrl.dispose();
              Navigator.pop(ctx);

              final user = FirebaseAuth.instance.currentUser;

              if (user == null || user.email == null) {
                _showMsg("Bạn chưa đăng nhập hợp lệ");
                return;
              }

              try {
                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passCtrl.text.trim(),
                );

                await user.reauthenticateWithCredential(cred);
                await user.verifyBeforeUpdateEmail(newEmailCtrl.text.trim());

                _showMsg("Đã gửi email xác nhận tới email mới");
              } on FirebaseAuthException catch (e) {
                _showMsg(e.message ?? "Lỗi xác thực");
              } catch (e) {
                _showMsg("Đổi email thất bại: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final data = widget.userDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trang cá nhân"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text("Lưu", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// ================= HEADER =================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundImage: _avatarUrl != null &&
                                _avatarUrl!.isNotEmpty
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null || _avatarUrl!.isEmpty
                                ? Text(
                              _nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold),
                            )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nameCtrl.text,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['email'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ================= PROFILE INFO =================
            const Text(
              "Thông tin cá nhân",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text("Tên hiển thị"),
                    subtitle: _editingName
                        ? TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "Nhập tên",
                        border: UnderlineInputBorder(),
                      ),
                    )
                        : Text(_nameCtrl.text),
                    trailing: IconButton(
                      icon: Icon(
                        _editingName ? Icons.check : Icons.edit,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _editingName = !_editingName;
                        });
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text("Email"),
                    subtitle: Text(data['email']),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: _showChangeEmailDialog,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// ================= ACCOUNT SETTINGS =================
            const Text(
              "Cài đặt tài khoản",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text("Đổi mật khẩu"),
                    subtitle: const Text("Gửi email để đặt lại mật khẩu"),
                    onTap: _saving ? null : _changePassword,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Đăng xuất",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                            (route) => false,
                      );                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
