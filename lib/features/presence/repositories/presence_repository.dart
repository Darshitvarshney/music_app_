import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_local_repository.dart';
import '../../search/model/song_model.dart';

/// Talks to the backend `/presence` endpoints (requires a signed-in user).
/// Presence is best-effort: none of these methods ever throw.
class PresenceRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  PresenceRepository({
    http.Client? client,
    AuthLocalRepository? authLocalRepository,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _authLocalRepository = authLocalRepository ?? AuthLocalRepository(),
        _baseUrl = (baseUrl ?? 'https://music-app-backend-amber.vercel.app')
            .replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>?> _authHeaders() async {
    final token = await _authLocalRepository.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  /// Tells the server "this user is online right now" (drives the green circle for friends).
  /// Returns whether it succeeded.
  Future<bool> sendHeartbeat() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return false;
      final response = await _client.post(
        Uri.parse('$_baseUrl/presence/heartbeat'),
        headers: headers,
      );
      return _ok(response);
    } catch (_) {
      return false;
    }
  }

  /// Reports what the user is playing (or paused on) so friends can see it.
  Future<bool> setNowPlaying(SongModel song, {required bool isPlaying}) async {
    if (song.id.trim().isEmpty || song.song.trim().isEmpty) return false;
    try {
      final headers = await _authHeaders();
      if (headers == null) return false;

      final artist = _clip(song.displayArtist, 300);
      final album = _clip(song.album, 300);
      final image = _clip(song.image, 1000);
      final perma = _clip(song.permaUrl, 1000);

      final response = await _client.put(
        Uri.parse('$_baseUrl/presence/now-playing'),
        headers: headers,
        body: jsonEncode({
          'song_id': _clip(song.id, 100),
          'title': _clip(song.song, 300),
          if (artist.isNotEmpty) 'artist': artist,
          if (album.isNotEmpty) 'album': album,
          if (image.isNotEmpty) 'image_url': image,
          if (perma.isNotEmpty) 'perma_url': perma,
          'is_playing': isPlaying,
        }),
      );
      return _ok(response);
    } catch (_) {
      return false;
    }
  }

  /// Removes the user's now-playing info (e.g. on logout).
  Future<bool> clearNowPlaying() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return false;
      final response = await _client.delete(
        Uri.parse('$_baseUrl/presence/now-playing'),
        headers: headers,
      );
      return _ok(response);
    } catch (_) {
      return false;
    }
  }

  String _clip(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength ? trimmed : trimmed.substring(0, maxLength);
  }
}
