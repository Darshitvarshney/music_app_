import 'dart:convert';
import 'package:client/features/auth/repositories/auth_local_repository.dart';
import 'package:client/features/favorites/repositories/favorites_repository.dart';
import 'package:client/features/search/model/song_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({'app_access_token': 'fake_jwt_token'});

  late AuthLocalRepository authLocalRepository;

  setUp(() {
    authLocalRepository = AuthLocalRepository();
  });

  const sampleSong = SongModel(
    id: 'IKc2REl8',
    song: 'Khat',
    album: 'Khat',
    primaryArtists: 'Navjot Ahuja',
    singers: 'Navjot Ahuja',
    duration: 296,
    image: 'https://c.saavncdn.com/479/Khat-Hindi-2025-500x500.jpg',
    mediaUrl: 'https://example.com/audio.mp4',
    mediaPreviewUrl: '',
    year: '2025',
    language: 'hindi',
    permaUrl: 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws',
    hasLyrics: false,
  );

  group('FavoritesRepository Tests', () {
    test('addFavorite sends POST /favorites with Bearer token and favorite payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/favorites');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer fake_jwt_token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['song_id'], 'IKc2REl8');
        expect(body['perma_url'], 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws');
        expect(body['title'], 'Khat');
        expect(body['artist'], 'Navjot Ahuja');

        return http.Response(
          jsonEncode({
            'message': 'Song added to favorites',
            'is_liked': true,
            'favorite': {
              'id': 'uuid-1',
              'song_id': 'IKc2REl8',
              'title': 'Khat',
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FavoritesRepository(
        client: mockClient,
        authLocalRepository: authLocalRepository,
        baseUrl: 'https://music-app-backend-amber.vercel.app',
      );

      final result = await repo.addFavorite(sampleSong);
      expect(result, isTrue);
    });

    test('removeFavorite sends DELETE /favorites/{song_id}', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/favorites/IKc2REl8');
        expect(request.method, 'DELETE');
        expect(request.headers['Authorization'], 'Bearer fake_jwt_token');

        return http.Response(
          jsonEncode({
            'message': 'Song removed from favorites',
            'is_liked': false,
            'favorite': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FavoritesRepository(
        client: mockClient,
        authLocalRepository: authLocalRepository,
      );

      final result = await repo.removeFavorite('IKc2REl8');
      expect(result, isTrue);
    });

    test('getFavorites sends GET /favorites and parses items accurately', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/favorites');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['limit'], '20');

        return http.Response(
          jsonEncode({
            'total': 1,
            'page': 1,
            'limit': 20,
            'items': [
              {
                'id': 'row-1',
                'song_id': 'IKc2REl8',
                'perma_url': 'https://www.jiosaavn.com/song/khat/OSMIAyZ1Wws',
                'title': 'Khat',
                'artist': 'Navjot Ahuja',
                'album': 'Khat',
                'image_url': 'https://c.saavncdn.com/479/Khat-Hindi-2025-500x500.jpg',
                'duration': '296',
                'language': 'hindi',
                'year': '2025',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FavoritesRepository(
        client: mockClient,
        authLocalRepository: authLocalRepository,
      );

      final page = await repo.getFavorites(page: 1, limit: 20);
      expect(page.total, 1);
      expect(page.items.length, 1);
      expect(page.items.first.id, 'IKc2REl8');
      expect(page.items.first.song, 'Khat');
      expect(page.items.first.displayArtist, 'Navjot Ahuja');
    });

    test('checkFavoriteStatus sends GET /favorites/{song_id}/status', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/favorites/IKc2REl8/status');
        return http.Response(
          jsonEncode({'song_id': 'IKc2REl8', 'is_liked': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FavoritesRepository(
        client: mockClient,
        authLocalRepository: authLocalRepository,
      );

      final isLiked = await repo.checkFavoriteStatus('IKc2REl8');
      expect(isLiked, isTrue);
    });

    test('checkBatchStatus sends POST /favorites/status-batch', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/favorites/status-batch');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['song_ids'], ['IKc2REl8', 'song2']);

        return http.Response(
          jsonEncode({
            'liked_song_ids': ['IKc2REl8']
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FavoritesRepository(
        client: mockClient,
        authLocalRepository: authLocalRepository,
      );

      final likedList = await repo.checkBatchStatus(['IKc2REl8', 'song2']);
      expect(likedList, ['IKc2REl8']);
    });
  });
}
