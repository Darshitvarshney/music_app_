import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/repositories/auth_local_repository.dart';
import '../model/profile_model.dart';

/// Talks to the backend `/profile` endpoints (requires a signed-in user).
class ProfileRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  ProfileRepository({
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

  ProfileModel _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ProfileModel.fromMap(decoded);
      }
    }
    throw Exception('(${response.statusCode}): ${response.body}');
  }

  Future<ProfileModel> getProfile() async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/profile');

    try {
      final response = await _client.get(uri, headers: headers);
      return _parse(response);
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  /// Claims or changes the username (once per 30 days). Rejections throw [ApiException]
  /// (`invalid_username`, `username_taken`, `username_cooldown`).
  Future<ProfileModel> setUsername(String username) async {
    final headers = await _getAuthHeaders();
    final response = await _client.put(
      Uri.parse('$_baseUrl/profile/username'),
      headers: headers,
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return ProfileModel.fromMap(decoded);
    }
    throw ApiException(response.statusCode, 'bad_response', 'Unexpected server response.');
  }

  /// `false` = friends only see that you are online, never the song you are playing.
  Future<ProfileModel> setShareListening(bool value) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/profile/settings');

    try {
      final response = await _client.put(
        uri,
        headers: headers,
        body: jsonEncode({'share_listening': value}),
      );
      return _parse(response);
    } catch (e) {
      throw Exception('Failed to update privacy setting: $e');
    }
  }
}
