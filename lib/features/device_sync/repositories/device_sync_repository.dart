import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../auth/repositories/auth_local_repository.dart';
import '../../search/model/song_model.dart';
import '../model/device_sync_models.dart';

/// Per-install settings: a random device id and whether sync is switched on.
/// Kept out of [AuthLocalRepository] so logging out does not touch the device id.
class DeviceSyncStore {
  static const String _deviceIdKey = 'device_sync_device_id';
  static const String _enabledKey = 'device_sync_enabled';

  final FlutterSecureStorage _storage;

  DeviceSyncStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String> getDeviceId() async {
    try {
      final String? saved = await _storage.read(key: _deviceIdKey);
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    final Random random = Random.secure();
    final String created = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    try {
      await _storage.write(key: _deviceIdKey, value: created);
    } catch (_) {}
    return created;
  }

  Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _enabledKey)) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
    } catch (_) {}
  }
}

/// Talks to the backend `/device-sync` endpoints (requires a signed-in user).
/// Server-side errors are thrown as [ApiException]; network failures propagate as-is.
class DeviceSyncRepository {
  final http.Client _client;
  final AuthLocalRepository _authLocalRepository;
  final String _baseUrl;

  DeviceSyncRepository({
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

  /// The account's current playback state. This is the sync poll.
  Future<DeviceSyncState> getState() async {
    final Map<String, String> headers = await _getAuthHeaders();
    final http.Response response =
        await _client.get(Uri.parse('$_baseUrl/device-sync/state'), headers: headers);
    return DeviceSyncState.fromMap(_decodeObject(response));
  }

  /// Reports a song change, pause/resume or seek. [auto] marks "the previous song ended";
  /// [expectedSeq] lets the server drop duplicate auto-advances sent by several devices.
  Future<DeviceSyncPutResult> putState({
    required String deviceId,
    required SongModel song,
    required bool isPlaying,
    required int positionMs,
    bool auto = false,
    int? expectedSeq,
  }) async {
    final Map<String, String> headers = await _getAuthHeaders();
    // The server rejects over-long text, which would silently stop syncing.
    const Map<String, int> limits = {
      'title': 300,
      'artist': 300,
      'album': 300,
      'image_url': 1000,
      'perma_url': 1000,
      'language': 100,
      'year': 20,
    };
    final Map<String, dynamic> songPayload = Map<String, dynamic>.from(song.toFavoritePayload());
    limits.forEach((String key, int max) {
      final dynamic value = songPayload[key];
      if (value is String && value.length > max) songPayload[key] = value.substring(0, max);
    });
    final http.Response response = await _client.put(
      Uri.parse('$_baseUrl/device-sync/state'),
      headers: headers,
      body: jsonEncode({
        ...songPayload,
        'device_id': deviceId,
        'is_playing': isPlaying,
        'position_ms': positionMs < 0 ? 0 : positionMs,
        'auto': auto,
        if (expectedSeq != null) 'expected_seq': expectedSeq,
      }),
    );
    final Map<String, dynamic> body = _decodeObject(response);
    final dynamic rawState = body['state'];
    if (rawState is! Map<String, dynamic>) {
      throw ApiException(response.statusCode, 'bad_response', 'Unexpected server response.');
    }
    return DeviceSyncPutResult(
      applied: body['applied'] == true,
      state: DeviceSyncState.fromMap(rawState),
    );
  }
}
