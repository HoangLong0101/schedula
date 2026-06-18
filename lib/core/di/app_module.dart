import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../router/app_router.dart';

@module
abstract class AppModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  @lazySingleton
  FirebaseDatabase get realtimeDatabase => FirebaseDatabase.instance;

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn(
        serverClientId:
            const String.fromEnvironment('FIREBASE_ANDROID_WEB_CLIENT_ID'),
        scopes: const <String>['email', 'profile'],
      );

  @lazySingleton
  GoRouter get router => AppRouter.router;

  @lazySingleton
  Dio get dio => Dio();

  @Named('bookingCascadeBaseUrl')
  String get bookingCascadeBaseUrl =>
      const String.fromEnvironment('BOOKING_CASCADE_API_BASE_URL');
}
