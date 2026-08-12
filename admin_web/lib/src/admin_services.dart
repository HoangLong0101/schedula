import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'platform_dashboard.dart';
import 'platform_workspace.dart';

class AdminAuthService {
  AdminAuthService([FirebaseAuth? auth]) : _injectedAuth = auth;

  final FirebaseAuth? _injectedAuth;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  Stream<User?> watchUser() => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final token = await credential.user?.getIdTokenResult(true);
    if (token?.claims?['platformAdmin'] != true) {
      await _auth.signOut();
      throw const PlatformAccessException();
    }
  }

  Future<bool> hasPlatformAccess(User user) async {
    final token = await user.getIdTokenResult(true);
    return token.claims?['platformAdmin'] == true;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}

class AdminApi {
  AdminApi([FirebaseFunctions? functions]) : _injectedFunctions = functions;

  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions get _functions =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  Future<PlatformDashboard> getDashboard() async {
    final result = await _functions
        .httpsCallable('getPlatformDashboard')
        .call();
    return PlatformDashboard.fromMap(
      Map<Object?, Object?>.from(result.data as Map),
    );
  }

  Future<PlatformWorkspace> getWorkspace(WorkspaceFilter filter) async {
    final result = await _functions
        .httpsCallable('getPlatformWorkspace')
        .call(filter.toMap());
    return PlatformWorkspace.fromMap(
      Map<Object?, Object?>.from(result.data as Map),
    );
  }

  Future<Map<Object?, Object?>> getBusinessDetail(String tenantId) async {
    final result = await _functions
        .httpsCallable('getPlatformBusinessDetail')
        .call({'tenantId': tenantId});
    return Map<Object?, Object?>.from(result.data as Map);
  }

  Future<void> performAction({
    required String action,
    required String resourceId,
    Map<String, Object?> payload = const {},
  }) async {
    await _functions.httpsCallable('platformAdminAction').call({
      'action': action,
      'resourceId': resourceId,
      'payload': payload,
    });
  }

  Future<void> reconcileTransaction(String paymentId) async {
    await _functions.httpsCallable('reconcilePayOSTransaction').call({
      'paymentId': paymentId,
    });
  }
}

class PlatformAccessException implements Exception {
  const PlatformAccessException();
}
