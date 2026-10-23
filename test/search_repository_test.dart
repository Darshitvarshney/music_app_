import 'dart:convert';
import 'package:client/features/search/model/song_model.dart';
import 'package:client/features/search/repositories/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SearchRepository resolvePlayableSong tests', () {
    test('returns song immediately if mediaUrl is already populated', () async {
      const song = SongModel(
        id: '123',
        song: 'Test Song',
        album: 'Test Album',
        primaryArtists: 'Test Artist',
        singers: 'Test Artist',
        duration: 180,
        image: 'https://example.com/img.jpg',
        mediaUrl: 'https://example.com/stream.mp4',
        mediaPreviewUrl: '',
        year: '2025',
        language: 'Hindi',
        hasLyrics: false,
      );

      final repo = SearchRepository();
      final resolved = await repo.resolvePlayableSong(song);

      expect(resolved, isNotNull);
      expect(resolved!.mediaUrl, 'https://example.com/stream.mp4');
    });

    test('falls back to search query when permaUrl is invalid and resolves mediaUrl', () async {
      const songWithoutMedia = SongModel(
        id: 'target_id_456',
        song: 'Khat',
        album: 'Khat',
        primaryArtists: 'Navjot Ahuja',
        singers: 'Navjot Ahuja',
        duration: 296,
        image: 'https://c.saavncdn.com/479/Khat.jpg',
        mediaUrl: '',
        mediaPreviewUrl: '',
        year: '2025',
        language: 'Hindi',
        permaUrl: 'https://www.jiosaavn.com/song/target_id_456',
        hasLyrics: false,
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/result/')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'target_id_456',
                'song': 'Khat',
                'album': 'Khat',
                'primary_artists': 'Navjot Ahuja',
                'singers': 'Navjot Ahuja',
                'duration': 296,
                'image': 'https://c.saavncdn.com/479/Khat.jpg',
                'media_url': 'https://aac.saavncdn.com/khat_320.mp4',
                'media_preview_url': '',
                'year': '2025',
                'language': 'Hindi',
                'perma_url': 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final repo = SearchRepository(client: mockClient);
      final resolved = await repo.resolvePlayableSong(songWithoutMedia);

      expect(resolved, isNotNull);
      expect(resolved!.id, 'target_id_456');
      expect(resolved.mediaUrl, 'https://aac.saavncdn.com/khat_320.mp4');
      expect(resolved.permaUrl, 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws');
    });
  });
}
