import 'dart:convert';

import 'package:http/http.dart' as http;

class SignUpInRepository {
  String errorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'] ?? body['message'] ?? body['error'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List) {
          final messages = detail
              .whereType<Map<String, dynamic>>()
              .map(_validationErrorMessage)
              .whereType<String>()
              .toSet();
          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }
      }
    } on FormatException {
      // Non-JSON response: use the operation-specific fallback below.
    }
    return fallback;
  }

  String? _validationErrorMessage(Map<String, dynamic> error) {
    final location = error['loc'];
    final field = location is List && location.isNotEmpty
        ? location.last.toString()
        : '';
    final type = error['type']?.toString() ?? '';
    final message = error['msg']?.toString() ?? '';
    final normalizedMessage = message.toLowerCase();

    if (normalizedMessage.contains('already exists') ||
        normalizedMessage.contains('already registered') ||
        normalizedMessage.contains('already taken')) {
      return 'An account with this email already exists.';
    }
    if (field == 'email' &&
        (type.contains('pattern') ||
            type.contains('email') ||
            normalizedMessage.contains('email') ||
            normalizedMessage.contains('pattern'))) {
      return 'Please enter a valid email address.';
    }
    if (field == 'email' && type.contains('missing')) {
      return 'Please enter your email address.';
    }
    if (field == 'password' && type.contains('missing')) {
      return 'Please enter your password.';
    }
    if (field == 'invite_code' && type.contains('missing')) {
      return 'Please enter the invite code.';
    }
    if (field == 'name' && type.contains('missing')) {
      return 'Please enter your name.';
    }
    if (message.isNotEmpty && !message.toLowerCase().contains('string should')) {
      return message;
    }
    return null;
  }

  Future<http.Response> signUp({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://music-app-backend-amber.vercel.app/user/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'invite_code': inviteCode,
        }),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  Future<http.Response> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://music-app-backend-amber.vercel.app/user/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<http.Response> refresh({
    required String refreshToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://music-app-backend-amber.vercel.app/user/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to refresh token: $e');
    }
  }
}

