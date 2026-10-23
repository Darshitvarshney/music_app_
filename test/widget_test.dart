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
import 'package:client/features/home/view/widgets/full_screen_player.dart';
import 'package:client/features/search/model/song_model.dart';

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

  testWidgets('FullScreenPlayer smoke test with controls and draggable timeline', (WidgetTester tester) async {
    const testSong = SongModel(
      id: 'test_1',
      song: 'Channa Ve',
      album: 'Bhoot',
      primaryArtists: 'Akhil Sachdeva',
      singers: 'Akhil Sachdeva',
      duration: 211,
      image: '',
      mediaUrl: '',
      mediaPreviewUrl: '',
      year: '2023',
      language: 'hindi',
      hasLyrics: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: FullScreenPlayer(initialSong: testSong),
      ),
    );

    expect(find.text('Channa Ve'), findsOneWidget);
    expect(find.text('Akhil Sachdeva'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });
}
