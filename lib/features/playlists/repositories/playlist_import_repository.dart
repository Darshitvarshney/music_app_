import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/repositories/auth_local_repository.dart';
import '../model/import_models.dart';

/// Talks to the backend `/import` endpoints and the bulk song add (requires a signed-in user).
/// Server-side errors are thrown as [ApiException]; network failures propagate as-is.
class PlaylistImportRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  PlaylistImportRepository({
    http.Client? client,
    AuthLocalRepository? authLocalRepository,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _authLocalRepository = authLocalRepository ?? AuthLocalRepository(),
        _baseUrl = (baseUrl ?? 'https://music-app-backend-amber.vercel.app')
            .replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _getAuthHeaders() async {
    final String? token = await _authLocalRepository.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodes bytes as UTF-8 because titles can be non-Latin and the response has no charset.
  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(
        response.statusCode, 'bad_response', 'Unexpected server response.');
  }

  /// [googleToken] lets the server read private playlists as that user; it is never stored.
  Future<SourcePageModel> fetchYoutubePage(
    String url, {
    String? pageToken,
    String? googleToken,
  }) async {
    final Map<String, String> headers = await _getAuthHeaders();
    if (googleToken != null) headers['X-Google-Token'] = googleToken;
    final Uri uri = Uri.parse('$_baseUrl/import/youtube').replace(
      queryParameters: <String, String>{
        'url': url,
        if (pageToken != null) 'page_token': pageToken,
      },
    );
    final http.Response response =
        await _client.get(uri, headers: headers).timeout(_timeout);
    return SourcePageModel.fromMap(_decodeObject(response));
  }

  /// A Spotify playlist anyone can open; the server reads it without a Spotify login.
  Future<SourcePageModel> fetchSpotifyPlaylist(String url) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final Uri uri = Uri.parse('$_baseUrl/import/spotify')
        .replace(queryParameters: <String, String>{'url': url});
    final http.Response response =
        await _client.get(uri, headers: headers).timeout(_timeout);
    return SourcePageModel.fromMap(_decodeObject(response));
  }

  /// Songs found in the text of an exported playlist file.
  Future<SourcePageModel> parseFile(String text) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client
        .post(
          Uri.parse('$_baseUrl/import/file'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{'text': text}),
        )
        .timeout(_timeout);
    return SourcePageModel.fromMap(_decodeObject(response));
  }

  Future<MyPlaylistsPageModel> fetchMyPlaylists(
    String googleToken, {
    String? pageToken,
  }) async {
    final Map<String, String> headers = await _getAuthHeaders();
    headers['X-Google-Token'] = googleToken;
    final Uri uri = Uri.parse('$_baseUrl/import/youtube/playlists').replace(
      queryParameters: <String, String>{
        if (pageToken != null) 'page_token': pageToken,
      },
    );
    final http.Response response =
        await _client.get(uri, headers: headers).timeout(_timeout);
    return MyPlaylistsPageModel.fromMap(_decodeObject(response));
  }

  /// A catalog song (playlist-song payload) per track, in order; `null` where nothing matched.
  Future<List<Map<String, dynamic>?>> matchTracks(
    List<ImportTrack> tracks,
  ) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client
        .post(
          Uri.parse('$_baseUrl/import/match'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'tracks': tracks.map((ImportTrack t) => t.toMap()).toList(),
          }),
        )
        .timeout(_timeout);
    final dynamic results = _decodeObject(response)['results'];

    final List<Map<String, dynamic>?> songs = <Map<String, dynamic>?>[];
    if (results is List) {
      for (final dynamic item in results) {
        final dynamic song = item is Map<String, dynamic> ? item['song'] : null;
        songs.add(song is Map<String, dynamic> ? song : null);
      }
    }
    while (songs.length < tracks.length) {
      songs.add(null);
    }
    return songs;
  }

  /// Appends [songs] (max 100) to the playlist; returns how many were actually new.
  Future<int> addSongs(
    String playlistId,
    List<Map<String, dynamic>> songs,
  ) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client
        .post(
          Uri.parse(
            '$_baseUrl/playlists/${Uri.encodeComponent(playlistId)}/songs/bulk',
          ),
          headers: headers,
          body: jsonEncode(<String, dynamic>{'songs': songs}),
        )
        .timeout(_timeout);
    final dynamic added = _decodeObject(response)['added'];
    return added is int ? added : int.tryParse('$added') ?? 0;
  }
}
