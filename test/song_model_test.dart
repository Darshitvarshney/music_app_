import 'dart:convert';
import 'package:client/features/search/model/song_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SongModel tests', () {
    test('parses song JSON from search API accurately', () {
      final jsonMap = {
        'id': 'URItmq7h',
        'song': 'Believer',
        'album': 'AiSh: The Covers Collection',
        'primary_artists': 'Aish',
        'singers': 'Aish',
        'duration': '144',
        'image': 'https://c.saavncdn.com/078/AiSh-The-Covers-Collection-Hindi-2022-20260710184759-500x500.jpg',
        'media_url': 'https://aac.saavncdn.com/078/691b7984c2ad4ea849a335c966b84fe2_320.mp4',
        'media_preview_url': 'https://preview.saavncdn.com/078/691b7984c2ad4ea849a335c966b84fe2_96_p.mp4',
        'year': '2022',
        'language': 'english',
        'has_lyrics': 'false',
        'lyrics': null,
      };

      final song = SongModel.fromJson(jsonEncode(jsonMap));

      expect(song.id, 'URItmq7h');
      expect(song.song, 'Believer');
      expect(song.album, 'AiSh: The Covers Collection');
      expect(song.displayArtist, 'Aish');
      expect(song.duration, 144);
      expect(song.formattedDuration, '02:24');
      expect(song.image, contains('500x500.jpg'));
      expect(song.mediaUrl, contains('_320.mp4'));
      expect(song.hasLyrics, false);
    });

    test('handles fallback artist when primary_artists is blank', () {
      final jsonMap = {
        'id': '123',
        'song': 'Instrumental Track',
        'album': '',
        'primary_artists': '',
        'singers': 'John Doe',
        'duration': 65,
        'image': '',
        'media_url': 'https://example.com/audio.mp4',
        'media_preview_url': '',
        'year': '2024',
        'language': 'instrumental',
        'has_lyrics': 'false',
      };

      final song = SongModel.fromMap(jsonMap);

      expect(song.displayArtist, 'John Doe');
      expect(song.formattedDuration, '01:05');
    });

    test('parses song JSON from favorites API response and generates favorite payload', () {
      final favoriteJson = {
        'id': 'uuid-1234',
        'song_id': 'IKc2REl8',
        'perma_url': 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws',
        'title': 'Khat',
        'artist': 'Navjot Ahuja',
        'album': 'Khat',
        'image_url': 'https://c.saavncdn.com/479/Khat-Hindi-2025-500x500.jpg',
        'duration': '296',
        'language': 'hindi',
        'year': '2025',
      };

      final song = SongModel.fromMap(favoriteJson);

      expect(song.id, 'IKc2REl8');
      expect(song.song, 'Khat');
      expect(song.permaUrl, 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws');
      expect(song.displayArtist, 'Navjot Ahuja');
      expect(song.album, 'Khat');
      expect(song.image, 'https://c.saavncdn.com/479/Khat-Hindi-2025-500x500.jpg');
      expect(song.duration, 296);

      final payload = song.toFavoritePayload();
      expect(payload['song_id'], 'IKc2REl8');
      expect(payload['perma_url'], 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws');
      expect(payload['title'], 'Khat');
      expect(payload['artist'], 'Navjot Ahuja');
      expect(payload['image_url'], 'https://c.saavncdn.com/479/Khat-Hindi-2025-500x500.jpg');
      expect(payload['duration'], '296');
    });
  });
}
