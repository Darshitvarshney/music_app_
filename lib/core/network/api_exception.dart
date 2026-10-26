import 'dart:convert';
import 'package:http/http.dart' as http;

/// Error from our backend. `detail` is `{code, message}` (older endpoints: a plain string).
/// UI branches on [code] and can show [message] directly.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException(this.statusCode, this.code, this.message);

  factory ApiException.fromResponse(http.Response response) {
    var code = 'error';
    var message = 'Something went wrong (${response.statusCode}).';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is Map<String, dynamic>) {
          code = detail['code']?.toString() ?? code;
          message = detail['message']?.toString() ?? message;
        } else if (detail is String && detail.trim().isNotEmpty) {
          message = detail;
        }
      }
    } catch (_) {
      // Non-JSON body: keep the generic message.
    }
    return ApiException(response.statusCode, code, message);
  }

  @override
  String toString() => message;
}
