import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../search/model/song_model.dart';
import '../model/user_model.dart';
import '../model/auth_response_model.dart';

class AuthLocalRepository {
  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'app_access_token';
  static const String _refreshTokenKey = 'app_refresh_token';
  static const String _userKey = 'app_user_data';
  static const String _lastSongKey = 'app_last_played_song';
  static const String _deviceIdKey = 'app_device_installation_id';

  AuthLocalRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<String> getEffectiveUserId() async {
    final user = await getUser();
    if (user != null && user.id.isNotEmpty) {
      return user.id;
    }
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  Future<void> saveAuthData(AuthResponseModel authData) async {
    await setAccessToken(authData.accessToken);
    if (authData.refreshToken != null && authData.refreshToken!.isNotEmpty) {
      await setRefreshToken(authData.refreshToken!);
    }
    if (authData.user != null) {
      await setUser(authData.user!);
    }
  }

  Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> setUser(UserModel user) async {
    await _storage.write(key: _userKey, value: user.toJson());
  }

  Future<UserModel?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null || userJson.isEmpty) {
      return null;
    }
    try {
      return UserModel.fromJson(userJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastPlayedSong(SongModel song) async {
    await _storage.write(key: _lastSongKey, value: song.toJson());
  }

  Future<SongModel?> getLastPlayedSong() async {
    final songJson = await _storage.read(key: _lastSongKey);
    if (songJson == null || songJson.isEmpty) {
      return null;
    }
    try {
      return SongModel.fromJson(songJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
