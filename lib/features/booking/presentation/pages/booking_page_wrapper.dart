import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'booking_page.dart';

class BookingPageWrapper extends StatefulWidget {
  const BookingPageWrapper({super.key});

  @override
  State<BookingPageWrapper> createState() => _BookingPageWrapperState();
}

class _BookingPageWrapperState extends State<BookingPageWrapper> {
  String? _tenantId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTenantId();
  }

  Future<void> _loadTenantId() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in';
        _loading = false;
      });
      return;
    }

    try {
      final token = await user.getIdTokenResult(true);
      final tenantId = token.claims?['tenantId'] as String?;
      setState(() {
        _tenantId = tenantId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to read tenant claims';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookings')),
        body: Center(child: Text(_error!)),
      );
    }

    return BookingPage(tenantId: _tenantId);
  }
}
