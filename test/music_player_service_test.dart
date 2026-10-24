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

    test('playSong resets queue when played as single song without queue', () {
      final player = MusicPlayerService();
      final songA = const SongModel(
        id: 'song_a',
        song: 'Song A',
        album: 'Album A',
        primaryArtists: 'Artist A',
        singers: '',
        duration: 180,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2024',
        language: 'Hindi',
        hasLyrics: false,
      );

      final songB = const SongModel(
        id: 'song_b',
        song: 'Song B',
        album: 'Album B',
        primaryArtists: 'Artist B',
        singers: '',
        duration: 200,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2024',
        language: 'Hindi',
        hasLyrics: false,
      );

      player.playQueue([songA, songB], initialIndex: 0);
      expect(player.queue.length, 2);

      final songC = const SongModel(
        id: 'song_c',
        song: 'Song C',
        album: 'Album C',
        primaryArtists: 'Artist C',
        singers: '',
        duration: 210,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2024',
        language: 'Hindi',
        hasLyrics: false,
      );

      player.playSong(songC);
      // Fresh single song play must isolate queue to [songC] for /api/recommend autoplay
      expect(player.queue.length, 1);
      expect(player.queue.first.id, 'song_c');
    });

    test('playSongWithAutoplay isolates queue to selected song rather than homepage list', () async {
      final player = MusicPlayerService();
      final homepageSectionSong1 = const SongModel(
        id: 'home_1',
        song: 'Home Song 1',
        album: 'Home Album',
        primaryArtists: 'Home Artist 1',
        singers: '',
        duration: 200,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2024',
        language: 'Hindi',
        hasLyrics: false,
      );
      final homepageSectionSong2 = const SongModel(
        id: 'home_2',
        song: 'Home Song 2',
        album: 'Home Album',
        primaryArtists: 'Home Artist 2',
        singers: '',
        duration: 210,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2024',
        language: 'Hindi',
        hasLyrics: false,
      );

      // Suppose user had previously played songs from a playlist or homepage section
      player.playQueue([homepageSectionSong1, homepageSectionSong2]);
      expect(player.queue.length, 2);

      // Now user selects a song from 'Recommend for You'
      final selectedFromRecs = const SongModel(
        id: 'selected_rec_99',
        song: 'Kesariya',
        album: 'Brahmastra',
        primaryArtists: 'Arijit Singh',
        singers: 'Arijit Singh',
        duration: 268,
        image: '',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2022',
        language: 'Hindi',
        hasLyrics: true,
      );

      await player.playSongWithAutoplay(selectedFromRecs);

      // The queue must NOT contain the homepage recommendation section songs
      expect(player.queue.any((s) => s.id == 'home_1'), isFalse);
      expect(player.queue.any((s) => s.id == 'home_2'), isFalse);
      // The queue starts with the selected song, ready for /api/recommend autoplay
      expect(player.queue.first.id, 'selected_rec_99');
      expect(player.queueIndex, 0);
    });
  });
}
