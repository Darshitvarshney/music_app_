import 'package:google_sign_in/google_sign_in.dart';

/// Source of a Google access token for reading the user's YouTube playlists.
/// A fake can stand in for it in tests.
abstract class GoogleTokenProvider {
  /// Shows Google's sign-in if needed. Returns `null` when cancelled or it fails.
  Future<String?> getAccessToken();

  Future<void> signOut();
}

/// Read-only YouTube access through Google sign-in; the token only lives in memory.
/// Needs the Web OAuth client id passed at build time: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
class GoogleAuthService implements GoogleTokenProvider {
  static const List<String> _scopes = <String>[
    'https://www.googleapis.com/auth/youtube.readonly',
  ];
  static const String _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static bool _initialized = false;

  @override
  Future<String?> getAccessToken() async {
    if (_serverClientId.isEmpty) return null;
    try {
      if (!_initialized) {
        await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
        _initialized = true;
      }
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      final GoogleSignInClientAuthorization? existing =
          await account.authorizationClient.authorizationForScopes(_scopes);
      final GoogleSignInClientAuthorization authorization = existing ??
          await account.authorizationClient.authorizeScopes(_scopes);
      return authorization.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to clean up if sign-out fails.
    }
  }
}
