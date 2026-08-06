import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/services/notification_service.dart';
import 'flavors.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
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
  await _activateAppCheck();

  await configureDependencies();
  getIt<AuthBloc>().add(const AuthStarted());
  runApp(const App());
  unawaited(NotificationService().initialize());
}

Future<void> _activateAppCheck() async {
  if (kIsWeb) return;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      await FirebaseAppCheck.instance.activate(
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return;
  }
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
