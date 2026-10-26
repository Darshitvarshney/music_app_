import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_local_repository.dart';
import '../../search/model/song_model.dart';
import '../model/playlist_model.dart';

/// An error whose message is safe to show to the user (e.g. "name already used").
class PlaylistException implements Exception {
  final String message;
  const PlaylistException(this.message);

  @override
  String toString() => message;
}

/// Result of adding a song: the refreshed playlist and whether it was newly added.
class AddSongResult {
  final PlaylistModel? playlist;
  final bool added;
  const AddSongResult({required this.playlist, required this.added});
}

/// Talks to the backend `/playlists` endpoints (requires a signed-in user).
class PlaylistsRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  PlaylistsRepository({
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

  bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  /// Turns a failed response into a [PlaylistException] using FastAPI's `detail` text.
  PlaylistException _failure(http.Response response, String fallback) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return PlaylistException(decoded['detail'] as String);
      }
    } catch (_) {}
    return PlaylistException('$fallback (${response.statusCode})');
  }

  Map<String, dynamic> _decodeMap(http.Response response, String fallback) {
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw PlaylistException(fallback);
  }

  PlaylistModel? _playlistFrom(Map<String, dynamic> decoded) {
    final dynamic raw = decoded['playlist'];
    return raw is Map<String, dynamic> ? PlaylistModel.fromMap(raw) : null;
  }

  Future<List<PlaylistModel>> getPlaylists() async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/playlists');

    try {
      final response = await _client.get(uri, headers: headers);
      if (!_ok(response)) throw _failure(response, 'Could not load playlists');
      final Map<String, dynamic> decoded =
          _decodeMap(response, 'Could not load playlists');
      final dynamic items = decoded['items'];
      if (items is! List) throw const PlaylistException('Could not load playlists');
      return items
          .whereType<Map<String, dynamic>>()
          .map(PlaylistModel.fromMap)
          .toList();
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not load playlists: $e');
    }
  }

  Future<PlaylistDetailModel> getPlaylist(String id) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(id)}');

    try {
      final response = await _client.get(uri, headers: headers);
      if (!_ok(response)) throw _failure(response, 'Could not load playlist');
      return PlaylistDetailModel.fromMap(
        _decodeMap(response, 'Could not load playlist'),
      );
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not load playlist: $e');
    }
  }

  Future<PlaylistModel> createPlaylist(String name, {String? description}) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/playlists');

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'name': name,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        }),
      );
      if (!_ok(response)) throw _failure(response, 'Could not create playlist');
      final PlaylistModel? playlist = _playlistFrom(
        _decodeMap(response, 'Could not create playlist'),
      );
      if (playlist == null) {
        throw const PlaylistException('Could not create playlist');
      }
      return playlist;
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not create playlist: $e');
    }
  }

  Future<PlaylistModel> renamePlaylist(String id, String name) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(id)}');

    try {
      final response = await _client.patch(
        uri,
        headers: headers,
        body: jsonEncode({'name': name}),
      );
      if (!_ok(response)) throw _failure(response, 'Could not rename playlist');
      final PlaylistModel? playlist = _playlistFrom(
        _decodeMap(response, 'Could not rename playlist'),
      );
      if (playlist == null) {
        throw const PlaylistException('Could not rename playlist');
      }
      return playlist;
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not rename playlist: $e');
    }
  }

  Future<void> deletePlaylist(String id) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(id)}');

    try {
      final response = await _client.delete(uri, headers: headers);
      if (!_ok(response)) throw _failure(response, 'Could not delete playlist');
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not delete playlist: $e');
    }
  }

  Future<AddSongResult> addSong(String playlistId, SongModel song) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse(
      '$_baseUrl/playlists/${Uri.encodeComponent(playlistId)}/songs',
    );

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(song.toFavoritePayload()),
      );
      if (!_ok(response)) throw _failure(response, 'Could not add song');
      final Map<String, dynamic> decoded =
          _decodeMap(response, 'Could not add song');
      return AddSongResult(
        playlist: _playlistFrom(decoded),
        added: decoded['added'] == true,
      );
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not add song: $e');
    }
  }

  Future<PlaylistModel?> removeSong(String playlistId, String songId) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse(
      '$_baseUrl/playlists/${Uri.encodeComponent(playlistId)}/songs/${Uri.encodeComponent(songId)}',
    );

    try {
      final response = await _client.delete(uri, headers: headers);
      if (!_ok(response)) throw _failure(response, 'Could not remove song');
      return _playlistFrom(_decodeMap(response, 'Could not remove song'));
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not remove song: $e');
    }
  }

  /// IDs of the user's playlists that already contain [songId].
  Future<Set<String>> getPlaylistIdsForSong(String songId) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse(
      '$_baseUrl/playlists/by-song/${Uri.encodeComponent(songId)}',
    );

    try {
      final response = await _client.get(uri, headers: headers);
      if (!_ok(response)) throw _failure(response, 'Could not check playlists');
      final Map<String, dynamic> decoded =
          _decodeMap(response, 'Could not check playlists');
      final dynamic ids = decoded['playlist_ids'];
      if (ids is! List) return <String>{};
      return ids.map((dynamic e) => e.toString()).toSet();
    } on PlaylistException {
      rethrow;
    } catch (e) {
      throw PlaylistException('Could not check playlists: $e');
    }
  }
}
