import 'dart:convert';
import 'package:client/core/models/recommendation_models.dart';
import 'package:client/core/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    RecommendationService.resetForTesting();
  });

  group('Recommendation Models Tests', () {
    test('PlaybackEligibilityModel parses correctly', () {
      final map = {
        'isEligible': true,
        'reason': 'ELIGIBLE_DIRECT_STREAM',
        'playbackUrl': 'https://example.com/stream.mp4',
        'isDrm': false,
        'isPreview': false,
      };
      final model = PlaybackEligibilityModel.fromMap(map);
      expect(model.isEligible, isTrue);
      expect(model.reason, 'ELIGIBLE_DIRECT_STREAM');
      expect(model.playbackUrl, 'https://example.com/stream.mp4');
      expect(model.isDrm, isFalse);
      expect(model.isPreview, isFalse);

      final toMap = model.toMap();
      expect(toMap['isEligible'], isTrue);
    });

    test('RecommendedSongModel parses correctly and converts to SongModel', () {
      final map = {
        'id': 'rec_1',
        'song': 'Aankhein',
        'album': 'Aankhein Album',
        'primary_artists': 'Navjot Ahuja',
        'singers': 'Navjot Ahuja',
        'duration': 315,
        'image': 'https://example.com/cover.jpg',
        'media_url': 'https://example.com/song.mp4',
        'media_preview_url': 'https://example.com/preview.mp4',
        'language': 'Hindi',
        'year': '2026',
        'recommendationScore': 0.88,
        'explanation': 'Similar genre and mood',
        'matchingGenres': ['Pop', 'Punjabi'],
        'matchingMoods': ['Romantic', 'Chill'],
        'playbackEligibility': {
          'isEligible': true,
          'reason': 'ELIGIBLE_DIRECT_STREAM',
          'playbackUrl': 'https://example.com/song.mp4',
          'isDrm': false,
          'isPreview': false,
        },
        'metadataConfidence': 0.85,
      };

      final rec = RecommendedSongModel.fromMap(map);
      expect(rec.id, 'rec_1');
      expect(rec.song, 'Aankhein');
      expect(rec.displayArtist, 'Navjot Ahuja');
      expect(rec.recommendationScore, 0.88);
      expect(rec.matchingGenres, contains('Pop'));
      expect(rec.playbackEligibility.isEligible, isTrue);

      final songModel = rec.toSongModel();
      expect(songModel.id, 'rec_1');
      expect(songModel.song, 'Aankhein');
      expect(songModel.mediaUrl, 'https://example.com/song.mp4');
      expect(songModel.displayArtist, 'Navjot Ahuja');
    });

    test('UserPreferenceProfileModel parses taste profile correctly', () {
      final map = {
        'userId': 'user_abc',
        'genres': {'Punjabi': 4.5, 'Pop': 3.2},
        'subgenres': {'Punjabi pop': 3.8},
        'moods': {'Romantic': 4.2, 'Chill': 2.5},
        'artists': {'navjot ahuja': 4.0},
        'languages': {'Hindi': 5.0},
        'totalEvents': 14,
      };

      final profile = UserPreferenceProfileModel.fromMap(map);
      expect(profile.userId, 'user_abc');
      expect(profile.genres['Punjabi'], 4.5);
      expect(profile.moods['Romantic'], 4.2);
      expect(profile.totalEvents, 14);
    });
  });

  group('RecommendationService API Endpoints Tests', () {
    test('getRecommendations parses POST /api/recommend response accurately', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/recommend');
        expect(request.method, 'POST');
        expect(request.headers['x-user-id'], 'test_user_1');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['userId'], 'test_user_1');
        expect(body['mode'], 'autoplay');
        expect(body['limit'], 2);

        return http.Response(
          jsonEncode({
            'status': 'success',
            'mode': 'autoplay',
            'totalCandidatesEvaluated': 40,
            'returnedCount': 1,
            'recommendations': [
              {
                'id': 'rec_123',
                'song': 'Test Song',
                'primary_artists': 'Test Artist',
                'duration': 200,
                'media_url': 'https://example.com/track.mp4',
                'recommendationScore': 0.95,
                'playbackEligibility': {
                  'isEligible': true,
                  'reason': 'ELIGIBLE_DIRECT_STREAM',
                },
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final recs = await service.getAutoplayQueue(
        userId: 'test_user_1',
        currentSong: {'id': 'curr_1', 'song': 'Seed Song'},
        limit: 2,
      );

      expect(recs.length, 1);
      expect(recs.first.id, 'rec_123');
      expect(recs.first.song, 'Test Song');
      expect(recs.first.recommendationScore, 0.95);
    });

    test('sendListeningEvent dispatches POST /api/events with payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/events');
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['userId'], 'user_123');
        expect(body['songId'], 'song_456');
        expect(body['eventType'], 'completed');
        expect(body['duration'], 180);

        return http.Response(
          jsonEncode({'status': 'success', 'message': 'Event recorded'}),
          200,
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final success = await service.sendListeningEvent(
        userId: 'user_123',
        songId: 'song_456',
        eventType: 'completed',
        duration: 180,
      );

      expect(success, isTrue);
    });

    test('sendFeedback dispatches POST /api/feedback with like action', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/feedback');
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['userId'], 'user_123');
        expect(body['songId'], 'song_789');
        expect(body['action'], 'like');

        return http.Response(
          jsonEncode({'status': 'success', 'message': 'Feedback recorded'}),
          200,
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final success = await service.sendFeedback(
        userId: 'user_123',
        songId: 'song_789',
        action: 'like',
      );

      expect(success, isTrue);
    });

    test('getSimilarSongs dispatches GET /api/similar and parses recommendations', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/similar');
        expect(request.url.queryParameters['id'], 'song_999');
        expect(request.url.queryParameters['limit'], '5');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'similarSongs': [
              {
                'id': 'sim_1',
                'song': 'Similar Track',
                'primary_artists': 'Similar Artist',
                'recommendationScore': 0.91,
                'playbackEligibility': {'isEligible': true},
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final similar = await service.getSimilarSongs('song_999', limit: 5);
      expect(similar.length, 1);
      expect(similar.first.id, 'sim_1');
      expect(similar.first.song, 'Similar Track');
      expect(similar.first.recommendationScore, 0.91);
    });

    test('getUserPreferences dispatches GET /api/preferences and returns taste profile', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/preferences');
        expect(request.url.queryParameters['userId'], 'user_xyz');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'profile': {
              'userId': 'user_xyz',
              'genres': {'Pop': 5.0},
              'subgenres': {},
              'moods': {'Energetic': 4.0},
              'artists': {'Drake': 3.5},
              'languages': {},
              'totalEvents': 8,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final profile = await service.getUserPreferences('user_xyz');
      expect(profile, isNotNull);
      expect(profile!.genres['Pop'], 5.0);
      expect(profile.moods['Energetic'], 4.0);
      expect(profile.artists['Drake'], 3.5);
      expect(profile.totalEvents, 8);
    });

    test('getHomepageRecommendations dispatches GET /api/homepage and parses sections', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/homepage');
        expect(request.url.queryParameters['userId'], 'user_home_1');
        expect(request.url.queryParameters['limit'], '6');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'userId': 'user_home_1',
            'source': 'postgresql_favorite_songs',
            'favoritesCount': 2,
            'recentFavorites': [
              {
                'id': 'fav_1',
                'title': 'Khat',
                'artist': 'Navjot Ahuja',
              }
            ],
            'topTaste': {
              'topGenres': ['Pop', 'Punjabi'],
              'topMoods': ['Romantic', 'Chill']
            },
            'sections': [
              {
                'id': 'made_for_you',
                'title': 'Made For You',
                'subtitle': 'Personalized mix of Pop vibes',
                'songs': [
                  {
                    'id': 'sec_song_1',
                    'song': 'Aankhein',
                    'primary_artists': 'Navjot Ahuja',
                    'media_url': 'https://example.com/aankhein.mp4',
                    'recommendationScore': 0.92,
                    'playbackEligibility': {'isEligible': true},
                  }
                ],
              },
              {
                'id': 'because_liked_fav_1',
                'title': 'Because You Liked "Khat"',
                'subtitle': 'Similar tracks by different artists',
                'seedSong': {'id': 'fav_1', 'title': 'Khat'},
                'songs': [
                  {
                    'id': 'sec_song_2',
                    'song': 'Khat (Instrumental)',
                    'primary_artists': 'Sonu Worldwide',
                    'media_url': 'https://example.com/khat_inst.mp4',
                    'recommendationScore': 0.85,
                    'playbackEligibility': {'isEligible': true},
                  }
                ],
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = RecommendationService(
        baseUrl: 'https://recommendation-taupe.vercel.app',
        client: mockClient,
      );

      final homepageData = await service.getHomepageRecommendations(
        userId: 'user_home_1',
        limit: 6,
      );

      expect(homepageData, isNotNull);
      expect(homepageData!.favoritesCount, 2);
      expect(homepageData.topTaste['topGenres'], contains('Pop'));
      expect(homepageData.sections.length, 2);

      final firstSection = homepageData.sections.first;
      expect(firstSection.id, 'made_for_you');
      expect(firstSection.title, 'Made For You');
      expect(firstSection.songs.length, 1);
      expect(firstSection.songs.first.song, 'Aankhein');

      final secondSection = homepageData.sections[1];
      expect(secondSection.title, 'Because You Liked "Khat"');
      expect(secondSection.seedSong?['id'], 'fav_1');
      expect(secondSection.songs.first.song, 'Khat (Instrumental)');
    });
  });
}
