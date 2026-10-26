import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/repositories/auth_local_repository.dart';
import '../model/friend_models.dart';

/// Talks to the backend `/friends` endpoints (requires a signed-in user).
/// Server-side errors are thrown as [ApiException]; network failures propagate as-is.
class FriendsRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  FriendsRepository({
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

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(response.statusCode, 'bad_response', 'Unexpected server response.');
  }

  /// Every friend with their online state and (if shared) current song.
  Future<List<FriendActivityModel>> getActivity() async {
    final headers = await _getAuthHeaders();
    final response = await _client.get(Uri.parse('$_baseUrl/friends/activity'), headers: headers);
    final body = _decodeObject(response);
    final items = body['items'];
    if (items is! List) return <FriendActivityModel>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map((m) => FriendActivityModel.fromMap(m))
        .where((f) => f.username.isNotEmpty)
        .toList();
  }

  Future<FriendRequestsModel> getRequests() async {
    final headers = await _getAuthHeaders();
    final response = await _client.get(Uri.parse('$_baseUrl/friends/requests'), headers: headers);
    return FriendRequestsModel.fromMap(_decodeObject(response));
  }

  /// Sends a friend request by username. If they already asked you, this accepts it.
  Future<FriendRequestResult> sendRequest(String username) async {
    final headers = await _getAuthHeaders();
    final response = await _client.post(
      Uri.parse('$_baseUrl/friends/requests'),
      headers: headers,
      body: jsonEncode({'username': username}),
    );
    return FriendRequestResult.fromMap(_decodeObject(response));
  }

  Future<FriendRequestResult> acceptRequest(String requestId) async {
    final headers = await _getAuthHeaders();
    final response = await _client.post(
      Uri.parse('$_baseUrl/friends/requests/${Uri.encodeComponent(requestId)}/accept'),
      headers: headers,
    );
    return FriendRequestResult.fromMap(_decodeObject(response));
  }

  Future<void> declineRequest(String requestId) async {
    final headers = await _getAuthHeaders();
    final response = await _client.post(
      Uri.parse('$_baseUrl/friends/requests/${Uri.encodeComponent(requestId)}/decline'),
      headers: headers,
    );
    _decodeObject(response);
  }
}
