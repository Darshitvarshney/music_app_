import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_local_repository.dart';
import '../../search/model/song_model.dart';
import '../model/favorites_page_result.dart';

class FavoritesRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  FavoritesRepository({
    http.Client? client,
    AuthLocalRepository? authLocalRepository,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _authLocalRepository = authLocalRepository ?? AuthLocalRepository(),
        _baseUrl = baseUrl ?? 'https://music-app-backend-amber.vercel.app';

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authLocalRepository.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> addFavorite(SongModel song) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/favorites');
    final payload = song.toFavoritePayload();

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['is_liked'] == true;
        }
        return true;
      }
      throw Exception('Failed to add favorite (${response.statusCode}): ${response.body}');
    } catch (e) {
      throw Exception('Failed to add favorite: $e');
    }
  }

  Future<bool> removeFavorite(String songId) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/favorites/${Uri.encodeComponent(songId)}');

    try {
      final response = await _client.delete(
        uri,
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw Exception('Failed to remove favorite (${response.statusCode}): ${response.body}');
    } catch (e) {
      throw Exception('Failed to remove favorite: $e');
    }
  }

  Future<FavoritesPageResult> getFavorites({int page = 1, int limit = 50}) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/favorites?page=$page&limit=$limit');

    try {
      final response = await _client.get(
        uri,
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return FavoritesPageResult.fromMap(decoded);
        }
      }
      throw Exception('Failed to get favorites (${response.statusCode}): ${response.body}');
    } catch (e) {
      throw Exception('Failed to get favorites: $e');
    }
  }

  Future<bool> checkFavoriteStatus(String songId) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/favorites/${Uri.encodeComponent(songId)}/status');

    try {
      final response = await _client.get(
        uri,
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['is_liked'] == true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> checkBatchStatus(List<String> songIds) async {
    if (songIds.isEmpty) {
      return [];
    }

    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/favorites/status-batch');

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'song_ids': songIds}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['liked_song_ids'] is List) {
          return (decoded['liked_song_ids'] as List)
              .map((id) => id.toString())
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
