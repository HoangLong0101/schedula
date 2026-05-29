import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'flavors.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'firebase_options_staging.dart' as staging;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const kAppFlavor = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
  );
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == kAppFlavor,
    orElse: () => Flavor.dev,
  );

  final firebaseOptions = switch (F.appFlavor) {
    Flavor.staging => staging.DefaultFirebaseOptions.currentPlatform,
    Flavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
    Flavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
  };

  await _initializeFirebase(firebaseOptions);

  await configureDependencies();
  runApp(const App());
  unawaited(NotificationService().initialize());
}

Future<void> _initializeFirebase(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(options: options);
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }
}
