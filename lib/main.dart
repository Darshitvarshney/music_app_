import 'package:flutter/material.dart';
import 'core/services/download_service.dart';
import 'core/services/music_player_service.dart';
import 'core/theme/theme.dart';
import 'features/auth/view/pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background audio service for lockscreen and notification bar controls
  await MusicPlayerService().initAudioService();

  // Initialize offline downloads service
  DownloadService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkThemeMode,
      home: const AuthGate(),
    );
  }
}
