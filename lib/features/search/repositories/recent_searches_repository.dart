import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_local_repository.dart';
import '../model/recent_search_model.dart';

/// Talks to the backend `/recent-searches` endpoints (requires a signed-in user).
class RecentSearchesRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  RecentSearchesRepository({
    http.Client? client,
    AuthLocalRepository? authLocalRepository,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _authLocalRepository = authLocalRepository ?? AuthLocalRepository(),
        _baseUrl = (baseUrl ?? 'https://music-app-backend-amber.vercel.app')
            .replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authLocalRepository.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Records [query] and returns the stored entry (re-searching moves it to the top).
  Future<RecentSearchModel> saveSearch(String query) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/recent-searches');

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['item'] is Map<String, dynamic>) {
          return RecentSearchModel.fromMap(
            decoded['item'] as Map<String, dynamic>,
          );
        }
      }
      throw Exception('(${response.statusCode}): ${response.body}');
    } catch (e) {
      throw Exception('Failed to save recent search: $e');
    }
  }

  /// Newest first.
  Future<List<RecentSearchModel>> getRecentSearches({int limit = 20}) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/recent-searches?limit=$limit');

    try {
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['items'] is List) {
          return (decoded['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(RecentSearchModel.fromMap)
              .toList();
        }
      }
      throw Exception('(${response.statusCode}): ${response.body}');
    } catch (e) {
      throw Exception('Failed to get recent searches: $e');
    }
  }

  Future<void> deleteSearch(String id) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/recent-searches/${Uri.encodeComponent(id)}');

    try {
      final response = await _client.delete(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('(${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete recent search: $e');
    }
  }

  Future<void> clearAll() async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/recent-searches');

    try {
      final response = await _client.delete(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('(${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to clear recent searches: $e');
    }
  }
}
