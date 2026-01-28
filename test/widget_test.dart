// Simple widget test to verify app builds and HomePage is present
import 'package:flutter_test/flutter_test.dart';
import 'package:grades/main.dart';
import 'package:grades/pages/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App builds and shows HomePage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
