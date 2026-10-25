import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/presentation/screens/legal/about_screen.dart';
import 'package:mykhata/presentation/screens/legal/privacy_policy_screen.dart';
import 'package:mykhata/presentation/screens/legal/terms_conditions_screen.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('PrivacyPolicyScreen renders successfully', (tester) async {
    await tester.pumpWidget(host(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('100% Private & Offline'), findsOneWidget);
  });

  testWidgets('TermsConditionsScreen renders successfully', (tester) async {
    await tester.pumpWidget(host(const TermsConditionsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets('AboutScreen renders successfully and shows version', (tester) async {
    await tester.pumpWidget(host(const AboutScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('About MyKhata'), findsOneWidget);
    expect(find.text('MyKhata'), findsWidgets);
  });
}
