import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_services.dart';
import 'admin_shell.dart';
import 'admin_theme.dart';
import 'login_page.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final auth = AdminAuthService();
  final api = AdminApi();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedula Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light,
      home: StreamBuilder<User?>(
        stream: auth.watchUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          }
          final user = snapshot.data;
          if (user == null) return LoginPage(auth: auth);
          return FutureBuilder<bool>(
            future: auth.hasPlatformAccess(user),
            builder: (context, access) {
              if (access.connectionState != ConnectionState.done) {
                return const _LoadingScreen();
              }
              if (access.hasError || access.data != true) {
                return _AccessDeniedPage(onSignOut: auth.signOut);
              }
              return AdminShell(user: user, auth: auth, api: api);
            },
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AdminTheme.loadingBackground,
      body: Center(child: CircularProgressIndicator(color: AdminTheme.teal)),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 38,
                    color: AdminTheme.mutedInk,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có quyền truy cập',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tài khoản chưa được cấp quyền quản trị hệ thống.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AdminTheme.mutedInk),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: onSignOut,
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
