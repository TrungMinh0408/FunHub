import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// ================= REGISTER =================
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user!;
    await user.sendEmailVerification();

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'avatar': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🔥 BẮT BUỘC
    await _auth.signOut();
  }



  /// ================= LOGIN =================
  Future<DocumentSnapshot<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception("Đăng nhập thất bại");
    }

    if (!user.emailVerified) {
      await _auth.signOut();
      throw Exception("Vui lòng xác nhận email");
    }

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      throw Exception("Không tìm thấy dữ liệu người dùng");
    }

    return doc;
  }
}
