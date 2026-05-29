import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.go(DashboardPage.routePath);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Sign in')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Secure access scaffold',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This screen is ready for FirebaseAuth and Google OAuth login.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(labelText: 'Email address'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.read<AuthBloc>().add(const AuthGoogleSignInRequested()),
              child: const Text('Continue with Google'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(DashboardPage.routePath),
              child: const Text('Continue to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}