// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/view/pages/signup_page.dart';
import 'package:client/features/home/view/pages/home_page.dart';

void main() {
  testWidgets('Signup page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: SignupPage(),
      ),
    );

    // Verify that the Sign Up title and button are present.
    expect(find.text('Sign Up'), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Home page smoke test', (WidgetTester tester) async {
    const user = UserModel(id: '123', name: 'Alex', email: 'alex@example.com');
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(user: user),
      ),
    );

    // Verify greeting and user display
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Liked Song'), findsOneWidget);
    expect(find.text('Listen with Friends'), findsOneWidget);
    expect(find.text('Add Friend :'), findsOneWidget);
    expect(find.text('Friends :-'), findsOneWidget);
    expect(find.text('Midnight City Beats'), findsOneWidget);
  });
}
