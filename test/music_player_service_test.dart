import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/services/music_player_service.dart';
import 'package:client/features/search/model/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicPlayerService State Tests', () {
    test('MusicPlayerService singleton instance exists and initial values are valid', () {
      final player = MusicPlayerService();
      expect(player, isNotNull);
      expect(player.isPlaying, isFalse);
    });

    test('SongModel last played song restore structure is valid', () {
      final dummySong = SongModel(
        id: 'YpC-3Gat',
        song: 'Channa Ve',
        album: 'Bhoot',
        primaryArtists: 'Akhil Sachdeva, Mansheel Gujral',
        singers: 'B Praak',
        duration: 211,
        image: 'https://c.saavncdn.com/004/Morning-Chill-Vibes-Hindi-2023-20251226210352-500x500.jpg',
        mediaUrl: 'https://aac.saavncdn.com/004/5bd69e4b6bd092a5ea8f6901a4e50f86_320.mp4',
        mediaPreviewUrl: '',
        year: '2023',
        language: 'hindi',
        hasLyrics: true,
      );

      expect(dummySong.song, 'Channa Ve');
      expect(dummySong.displayArtist, 'Akhil Sachdeva, Mansheel Gujral');
      expect(dummySong.duration, 211);
    });
  });
}
