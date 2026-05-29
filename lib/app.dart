import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_flavor.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = getIt.isRegistered<GoRouter>() ? getIt<GoRouter>() : AppRouter.router;

    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(const AuthStarted()),
      child: MaterialApp.router(
        title: F.title,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
