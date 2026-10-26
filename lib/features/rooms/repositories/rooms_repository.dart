import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/repositories/auth_local_repository.dart';
import '../../search/model/song_model.dart';
import '../model/room_models.dart';

/// Talks to the backend `/rooms` endpoints (requires a signed-in user).
/// Server-side errors are thrown as [ApiException]; network failures propagate as-is.
class RoomsRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  RoomsRepository({
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

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(response.statusCode, 'bad_response', 'Unexpected server response.');
  }

  RoomModel _roomFrom(Map<String, dynamic> body) {
    final dynamic raw = body['room'];
    if (raw is Map<String, dynamic>) return RoomModel.fromMap(raw);
    throw const ApiException(500, 'bad_response', 'Unexpected server response.');
  }

  /// The user's room, or their pending invites when they are not in one. Doubles as the heartbeat.
  Future<CurrentRoomModel> getCurrent() async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response =
        await _client.get(Uri.parse('$_baseUrl/rooms/current'), headers: headers);
    return CurrentRoomModel.fromMap(_decodeObject(response));
  }

  Future<RoomModel> createRoom(List<String> usernames) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/rooms'),
      headers: headers,
      body: jsonEncode({'usernames': usernames}),
    );
    return _roomFrom(_decodeObject(response));
  }

  Future<RoomModel> invite(String roomId, String username) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/invite'),
      headers: headers,
      body: jsonEncode({'username': username}),
    );
    return _roomFrom(_decodeObject(response));
  }

  Future<RoomModel> accept(String roomId) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/accept'),
      headers: headers,
    );
    return _roomFrom(_decodeObject(response));
  }

  Future<void> decline(String roomId) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/decline'),
      headers: headers,
    );
    _decodeObject(response);
  }

  Future<void> leave(String roomId) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.post(
      Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/leave'),
      headers: headers,
    );
    _decodeObject(response);
  }

  /// Shares [song] with the room. [auto] marks "the previous song ended"; [expectedSeq] lets the
  /// server drop duplicate auto-advances sent by several phones at once.
  Future<RoomSongResult> setSong(
    String roomId,
    SongModel song, {
    bool auto = false,
    int? expectedSeq,
  }) async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response = await _client.put(
      Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/song'),
      headers: headers,
      body: jsonEncode({
        ...song.toFavoritePayload(),
        'auto': auto,
        if (expectedSeq != null) 'expected_seq': expectedSeq,
      }),
    );
    final Map<String, dynamic> body = _decodeObject(response);
    return RoomSongResult(applied: body['applied'] == true, room: _roomFrom(body));
  }
}
