import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:funhub/layouts/main_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final service = FirestoreService();

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  void _msg(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showVerifyEmailDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Xác nhận email"),
          content: const Text(
            "Chúng tôi đã gửi email xác nhận.\n\n"
                "Vui lòng mở email và nhấn link xác nhận trước khi đăng nhập.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await user?.reload();

                final refreshedUser = FirebaseAuth.instance.currentUser;
                if (refreshedUser != null && refreshedUser.emailVerified) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) Navigator.pop(context); // đóng dialog
                  _msg("Xác nhận email thành công 🎉");
                  setState(() => isLogin = true);
                } else {
                  _msg("Bạn vẫn chưa xác nhận email");
                }
              },
              child: const Text("Tôi đã xác nhận"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _submit() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      _msg("Vui lòng nhập đầy đủ thông tin");
      return;
    }

    setState(() => loading = true);

    try {
      if (isLogin) {
        /// ================= LOGIN =================
        final userDoc = await service.login(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainLayout(userDoc: userDoc),
          ),
        );
      } else {
        /// ================= REGISTER =================
        if (nameCtrl.text.trim().isEmpty) {
          _msg("Vui lòng nhập tên");
          return;
        }

        await service.register(
          name: nameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
        );

        if (!mounted) return;

        /// 🔥 SHOW DIALOG XÁC NHẬN EMAIL
        showDialog(
          context: context,
          barrierDismissible: false, // không cho bấm ra ngoài
          builder: (_) => AlertDialog(
            title: const Text("Xác nhận email"),
            content: const Text(
              "Chúng tôi đã gửi email xác nhận.\n\n"
                  "Vui lòng kiểm tra hộp thư và xác nhận trước khi đăng nhập.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // đóng dialog
                  setState(() => isLogin = true); // quay về login
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      _msg(
        e.toString()
            .replaceAll("Exception:", "")
            .replaceAll("firebase_auth/", ""),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset(
              "assets/images/Login_bg.jpg",
              fit: BoxFit.cover,
            ),
          ),

          /// DARK OVERLAY
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          /// CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// LOGO
                        Icon(
                          Icons.people_alt_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "FunHub",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin
                              ? "Chào mừng quay lại"
                              : "Tạo tài khoản mới",
                          style: TextStyle(color: Colors.grey[700]),
                        ),

                        const SizedBox(height: 32),

                        /// NAME (REGISTER ONLY)
                        if (!isLogin)
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Tên hiển thị",
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        if (!isLogin) const SizedBox(height: 16),

                        /// EMAIL
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 16),

                        /// PASSWORD
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Mật khẩu",
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),

                        const SizedBox(height: 28),

                        /// SUBMIT
                        loading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            child: Text(
                              isLogin ? "Đăng nhập" : "Tạo tài khoản",
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        /// SWITCH MODE
                        TextButton(
                          onPressed: () {
                            setState(() => isLogin = !isLogin);
                          },
                          child: Text(
                            isLogin
                                ? "Chưa có tài khoản? Đăng ký"
                                : "Đã có tài khoản? Đăng nhập",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
