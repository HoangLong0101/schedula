import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/user.dart';
import '../models/user_model.dart';

@lazySingleton
class FirebaseAuthDataSource {
  FirebaseAuthDataSource(this._firebaseAuth, this._googleSignIn);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Stream<AppUser?> watchCurrentUser() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapUser(credential.user);
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
    return _mapUser(userCredential.user);
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return UserModel(
      id: user.uid,
      email: user.email ?? '',
    );
  }
}