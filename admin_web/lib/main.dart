import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/admin_app.dart';
import 'src/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}
