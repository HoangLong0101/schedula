import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'booking_page.dart';

class BookingPageWrapper extends StatelessWidget {
  const BookingPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthLoading || authState is AuthInitial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tenantId = authState is Authenticated
        ? authState.user.tenantId
        : null;
    return BookingPage(tenantId: tenantId);
  }
}
