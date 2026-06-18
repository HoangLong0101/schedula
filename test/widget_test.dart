// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:schedula/flavors.dart';
import 'package:schedula/features/auth/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App renders the splash page', (WidgetTester tester) async {
    // Ensure a flavor is set for tests so `F.title` is available and
    // pump only the SplashPage to avoid router/DI side-effects.
    F.appFlavor = Flavor.prod;
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.text('Schedula'), findsWidgets);
    expect(find.text('Enter dashboard'), findsOneWidget);
  });
}
