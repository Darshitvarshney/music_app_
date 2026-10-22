import 'dart:convert';

import 'user_model.dart';

class AuthResponseModel {
  final String? message;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final UserModel? user;

  const AuthResponseModel({
    this.message,
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    this.user,
  });

  AuthResponseModel copyWith({
    String? message,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    UserModel? user,
  }) {
    return AuthResponseModel(
      message: message ?? this.message,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (message != null) 'message': message,
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'token_type': tokenType,
      if (user != null) 'user': user!.toMap(),
    };
  }

  factory AuthResponseModel.fromMap(Map<String, dynamic> map) {
    return AuthResponseModel(
      message: map['message']?.toString(),
      accessToken: map['access_token']?.toString() ?? '',
      refreshToken: map['refresh_token']?.toString(),
      tokenType: map['token_type']?.toString() ?? 'bearer',
      user: map['user'] is Map<String, dynamic>
          ? UserModel.fromMap(map['user'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AuthResponseModel.fromJson(String source) =>
      AuthResponseModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'AuthResponseModel(message: $message, accessToken: $accessToken, refreshToken: $refreshToken, tokenType: $tokenType, user: $user)';
  }
}
