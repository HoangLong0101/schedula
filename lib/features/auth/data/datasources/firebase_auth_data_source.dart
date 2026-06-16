import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/auth_exception.dart';
import '../../domain/entities/user.dart';
import '../models/user_model.dart';

@lazySingleton
class FirebaseAuthDataSource {
  FirebaseAuthDataSource(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Stream<AppUser?> watchCurrentUser() {
    // Dùng asyncMap vì việc lấy custom claims (token) là tác vụ bất đồng bộ
    return _firebaseAuth.authStateChanges().asyncMap(_mapUserAsync);
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureAuthorized(credential.user);
    return _mapUserAsync(credential.user);
  }

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    final token = await user?.getIdTokenResult(true);
    final claimsRole = token?.claims?['role'] as String?;
    final claimsTenantId = token?.claims?['tenantId'] as String?;
    final profile =
        user != null && (claimsRole == null || claimsTenantId == null)
        ? await _readUserProfile(user.uid)
        : null;
    final role = claimsRole ?? profile?['role'] as String?;
    final tenantId = claimsTenantId ?? profile?['tenantId'] as String?;

    if (role == null || role.isEmpty || tenantId == null || tenantId.isEmpty) {
      throw const AuthProfileSetupRequiredException();
    }

    return _mapUserAsync(userCredential.user);
  }

  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  // Hàm map mới xử lý việc bóc tách Custom Claims
  Future<AppUser?> _mapUserAsync(User? user) async {
    if (user == null) {
      return null;
    }

    // forceRefresh = false để ưu tiên cache, nhưng vì _ensureAuthorized đã forceRefresh trước đó,
    // token ở đây luôn là mới nhất.
    final token = await user.getIdTokenResult(false);
    final claimsRole = token.claims?['role'] as String?;
    final claimsTenantId = token.claims?['tenantId'] as String?;
    final profile = claimsRole == null || claimsTenantId == null
        ? await _readUserProfile(user.uid)
        : null;
    final role = claimsRole ?? profile?['role'] as String? ?? '';
    final tenantId = claimsTenantId ?? profile?['tenantId'] as String? ?? '';

    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      role: role,
      tenantId: tenantId,
    );
  }

  Future<void> _ensureAuthorized(User? user) async {
    // forceRefresh = true để lấy quyền mới nhất từ server mỗi khi đăng nhập
    final token = await user?.getIdTokenResult(true);
    final claimsRole = token?.claims?['role'] as String?;
    final claimsTenantId = token?.claims?['tenantId'] as String?;
    final profile =
        user != null && (claimsRole == null || claimsTenantId == null)
        ? await _readUserProfile(user.uid)
        : null;
    final role = claimsRole ?? profile?['role'] as String?;
    final tenantId = claimsTenantId ?? profile?['tenantId'] as String?;

    if (role == null || role.isEmpty || tenantId == null || tenantId.isEmpty) {
      await signOut();
      throw const AuthAccessDeniedException();
    }
  }

  Future<Map<String, dynamic>?> _readUserProfile(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return snapshot.data();
  }
}
