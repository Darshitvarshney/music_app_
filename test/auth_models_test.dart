import 'dart:convert';
import 'package:client/features/auth/model/auth_response_model.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel tests', () {
    test('fromJson and toJson works accurately', () {
      const jsonString =
          '{"id":"dbb50c86-db9f-4f21-980c-9365bc91da75","name":"d","email":"d@d.d"}';
      final user = UserModel.fromJson(jsonString);

      expect(user.id, 'dbb50c86-db9f-4f21-980c-9365bc91da75');
      expect(user.name, 'd');
      expect(user.email, 'd@d.d');

      final map = user.toMap();
      expect(map['id'], 'dbb50c86-db9f-4f21-980c-9365bc91da75');
      expect(map['name'], 'd');
      expect(map['email'], 'd@d.d');
    });
  });

  group('AuthResponseModel tests', () {
    test('parses login API response properly', () {
      final jsonMap = {
        'message': 'Login successful',
        'access_token': 'sample_access_token',
        'refresh_token': 'sample_refresh_token',
        'token_type': 'bearer',
        'user': {
          'id': 'dbb50c86-db9f-4f21-980c-9365bc91da75',
          'name': 'd',
          'email': 'd@d.d',
        },
      };

      final authResponse = AuthResponseModel.fromJson(jsonEncode(jsonMap));

      expect(authResponse.message, 'Login successful');
      expect(authResponse.accessToken, 'sample_access_token');
      expect(authResponse.refreshToken, 'sample_refresh_token');
      expect(authResponse.tokenType, 'bearer');
      expect(authResponse.user, isNotNull);
      expect(authResponse.user!.name, 'd');
      expect(authResponse.user!.email, 'd@d.d');
    });

    test('parses refresh API response with missing user and message properly', () {
      final jsonMap = {
        'access_token': 'new_access_token',
        'refresh_token': 'new_refresh_token',
        'token_type': 'bearer',
      };

      final authResponse = AuthResponseModel.fromJson(jsonEncode(jsonMap));

      expect(authResponse.accessToken, 'new_access_token');
      expect(authResponse.refreshToken, 'new_refresh_token');
      expect(authResponse.tokenType, 'bearer');
      expect(authResponse.user, isNull);
    });
  });
}
