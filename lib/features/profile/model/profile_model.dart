class ProfileModel {
  final String name;
  final String email;
  final String? username;
  final bool canChangeUsername;

  /// When the username may next be changed (null = can change now).
  final DateTime? usernameChangeAvailableAt;

  /// A free username the server suggests while the user has none yet.
  final String? suggestedUsername;
  final bool shareListening;

  const ProfileModel({
    required this.name,
    required this.email,
    this.username,
    this.canChangeUsername = true,
    this.usernameChangeAvailableAt,
    this.suggestedUsername,
    this.shareListening = true,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    String? optional(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      return text.trim().isEmpty ? null : text;
    }

    return ProfileModel(
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      username: optional(map['username']),
      canChangeUsername: map['can_change_username'] != false,
      usernameChangeAvailableAt: DateTime.tryParse(
        map['username_change_available_at']?.toString() ?? '',
      ),
      suggestedUsername: optional(map['suggested_username']),
      // Only an explicit `false` hides; anything else keeps the default (shared).
      shareListening: map['share_listening'] != false,
    );
  }
}
