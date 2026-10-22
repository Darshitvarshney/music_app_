import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../model/auth_response_model.dart';
import '../model/user_model.dart';
import '../repositories/auth_local_repository.dart';
import '../repositories/sign_up_in.dart';

class AuthViewModel extends ChangeNotifier {
  final SignUpInRepository _remoteRepository;
  final AuthLocalRepository _localRepository;

  UserModel? _currentUser;
  String? _accessToken;
  bool _isLoading = false;

  AuthViewModel({
    SignUpInRepository? remoteRepository,
    AuthLocalRepository? localRepository,
  })  : _remoteRepository = remoteRepository ?? SignUpInRepository(),
        _localRepository = localRepository ?? AuthLocalRepository();

  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Attempts to sign up a new user.
  /// Returns null on success, or an error message on failure.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _remoteRepository.signUp(
        name: name,
        email: email,
        password: password,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authData = AuthResponseModel.fromJson(response.body);
        await _localRepository.saveAuthData(authData);
        _accessToken = authData.accessToken;
        _currentUser = authData.user;
        notifyListeners();
        return null;
      }

      return _remoteRepository.errorMessage(
        response,
        fallback: 'Unable to sign up. Please try again.',
      );
    } catch (_) {
      return 'Unable to sign up. Check your connection and try again.';
    } finally {
      _setLoading(false);
    }
  }

  /// Attempts to sign in an existing user.
  /// Returns null on success, or an error message on failure.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _remoteRepository.signIn(
        email: email,
        password: password,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authData = AuthResponseModel.fromJson(response.body);
        await _localRepository.saveAuthData(authData);
        _accessToken = authData.accessToken;
        _currentUser = authData.user;
        notifyListeners();
        return null;
      }

      return _remoteRepository.errorMessage(
        response,
        fallback: 'Unable to sign in. Check your email and password.',
      );
    } catch (_) {
      return 'Unable to sign in. Check your connection and try again.';
    } finally {
      _setLoading(false);
    }
  }

  /// Validates cached session by checking the refresh token and acquiring a new access token.
  /// Returns true if successfully authenticated, false otherwise.
  Future<bool> checkAuthAndRefreshToken() async {
    final refreshToken = await _localRepository.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      _accessToken = null;
      _currentUser = null;
      return false;
    }

    try {
      final response = await _remoteRepository.refresh(
        refreshToken: refreshToken,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final newAccessToken = data['access_token']?.toString();
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            _accessToken = newAccessToken;
            await _localRepository.setAccessToken(newAccessToken);

            // Update refresh token if backend rotated it
            final newRefreshToken = data['refresh_token']?.toString();
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await _localRepository.setRefreshToken(newRefreshToken);
            }

            // Restore user data from local repository or response
            if (data['user'] is Map<String, dynamic>) {
              _currentUser = UserModel.fromMap(data['user'] as Map<String, dynamic>);
              await _localRepository.setUser(_currentUser!);
            } else {
              _currentUser = await _localRepository.getUser();
            }

            notifyListeners();
            return true;
          }
        }
      }

      // If refresh failed (token expired/invalidated), clear cached credentials
      await _localRepository.clear();
      _accessToken = null;
      _currentUser = null;
      notifyListeners();
      return false;
    } catch (_) {
      // In case of network errors during background check, do not necessarily invalidate
      return false;
    }
  }

  /// Logs out the user and clears all cached tokens and data.
  Future<void> logout() async {
    await _localRepository.clear();
    _currentUser = null;
    _accessToken = null;
    notifyListeners();
  }
}
