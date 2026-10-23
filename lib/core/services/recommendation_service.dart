import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation_models.dart';

/// Flutter API Service for the Personalized Music Recommendation Backend
class RecommendationService {
  static RecommendationService? _instance;
  factory RecommendationService({
    String? baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  }) {
    _instance ??= RecommendationService._internal(
      baseUrl: baseUrl,
      client: client,
      timeout: timeout,
    );
    return _instance!;
  }

  static void resetForTesting() {
    _instance = null;
  }

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  RecommendationService._internal({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  })  : baseUrl = (baseUrl ?? 'https://recommendation-taupe.vercel.app').replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  /// Headers helper
  Map<String, String> _headers(String? userId) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (userId != null && userId.isNotEmpty) 'x-user-id': userId,
      };

  /// Fetches ranked song recommendations
  Future<List<RecommendedSongModel>> getRecommendations({
    required String userId,
    required Map<String, dynamic> currentSong,
    List<Map<String, dynamic>> candidateSongs = const [],
    int limit = 10,
    String mode = 'autoplay',
    List<String> excludedSongIds = const [],
    Map<String, dynamic>? userPreferences,
  }) async {
    final uri = Uri.parse('$baseUrl/api/recommend');

    final payload = <String, dynamic>{
      'userId': userId,
      'currentSong': currentSong,
      'candidateSongs': candidateSongs,
      'limit': limit,
      'mode': mode,
      'excludedSongIds': excludedSongIds,
    };
    if (userPreferences != null) {
      payload['userPreferences'] = userPreferences;
    }

    try {
      final response = await _client
          .post(uri, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final resModel = RecommendationResponseModel.fromMap(decoded);
          return resModel.recommendations;
        }
      }
      return [];
    } on TimeoutException {
      // Timeout fallback: Return eligible candidates passed by client if available
      return candidateSongs
          .where((c) => (c['media_url']?.toString().isNotEmpty ?? false) && c['disabled'] != true)
          .map((c) => RecommendedSongModel.fromMap(c))
          .take(limit)
          .toList();
    } catch (e) {
      // Log and fail gracefully
      return [];
    }
  }

  /// Convenience method to generate the next autoplay queue
  Future<List<RecommendedSongModel>> getAutoplayQueue({
    required String userId,
    required Map<String, dynamic> currentSong,
    List<String> excludedSongIds = const [],
    int limit = 10,
  }) async {
    return getRecommendations(
      userId: userId,
      currentSong: currentSong,
      limit: limit,
      mode: 'autoplay',
      excludedSongIds: excludedSongIds,
    );
  }

  /// Convenience method to generate personalized recommendations based on long-term user taste
  Future<List<RecommendedSongModel>> getPersonalizedRecommendations({
    required String userId,
    Map<String, dynamic>? currentSong,
    List<Map<String, dynamic>> candidateSongs = const [],
    List<String> excludedSongIds = const [],
    int limit = 10,
  }) async {
    return getRecommendations(
      userId: userId,
      currentSong: currentSong ?? const {'song': 'Popular', 'language': 'Hindi'},
      candidateSongs: candidateSongs,
      limit: limit,
      mode: 'personalized',
      excludedSongIds: excludedSongIds,
    );
  }

  /// Fetches complete dynamic homepage recommendation sections from GET /api/homepage
  Future<HomepageResponseModel?> getHomepageRecommendations({
    required String userId,
    int limit = 8,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{
      'userId': userId,
      'limit': limit.toString(),
      if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final uri = Uri.parse('$baseUrl/api/homepage').replace(queryParameters: queryParams);

    final headers = _headers(userId);
    if (forceRefresh) {
      headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      headers['Pragma'] = 'no-cache';
    }

    try {
      final response = await _client.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return HomepageResponseModel.fromMap(decoded);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Records a listening event (played, completed, skipped, replayed)
  Future<bool> sendListeningEvent({
    required String userId,
    required String songId,
    required String eventType, // 'played', 'completed', 'skipped', 'replayed'
    int duration = 0,
    Map<String, dynamic>? songMetadata,
  }) async {
    final uri = Uri.parse('$baseUrl/api/events');

    final payload = <String, dynamic>{
      'userId': userId,
      'songId': songId,
      'eventType': eventType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'duration': duration,
    };
    if (songMetadata != null) {
      payload['songMetadata'] = songMetadata;
    }

    try {
      final response = await _client
          .post(uri, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 4));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Silently fail telemetry without interrupting audio playback
      return false;
    }
  }

  /// Fetches the user preference profile
  Future<UserPreferenceProfileModel?> getUserPreferences(String userId) async {
    final uri = Uri.parse('$baseUrl/api/preferences?userId=${Uri.encodeComponent(userId)}');

    try {
      final response = await _client.get(uri, headers: _headers(userId)).timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['profile'] is Map<String, dynamic>) {
          return UserPreferenceProfileModel.fromMap(decoded['profile']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sends explicit like / dislike feedback
  Future<bool> sendFeedback({
    required String userId,
    required String songId,
    required String action, // 'like' | 'dislike'
    Map<String, dynamic>? songMetadata,
  }) async {
    final uri = Uri.parse('$baseUrl/api/feedback');

    final payload = <String, dynamic>{
      'userId': userId,
      'songId': songId,
      'action': action,
    };
    if (songMetadata != null) {
      payload['songMetadata'] = songMetadata;
    }

    try {
      final response = await _client
          .post(uri, headers: _headers(userId), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches similar tracks for a given song ID
  Future<List<RecommendedSongModel>> getSimilarSongs(String songId, {String? userId, int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/api/similar?id=${Uri.encodeComponent(songId)}&limit=$limit');

    try {
      final response = await _client.get(uri, headers: _headers(userId)).timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final resModel = RecommendationResponseModel.fromMap(decoded);
          return resModel.recommendations;
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
