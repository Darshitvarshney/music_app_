import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

/// Avatar colours; one is picked per friend from their username so it stays stable.
const List<List<Color>> friendAvatarGradients = [
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFFFF416C), Color(0xFFFF4B2B)],
  [Color(0xFF606C38), Color(0xFF283618)],
  [Color(0xFFF7971E), Color(0xFFFFD200)],
  [Color(0xFF00B4DB), Color(0xFF0083B0)],
];

List<Color> friendGradientFor(String key) {
  var sum = 0;
  for (final unit in key.codeUnits) {
    sum += unit;
  }
  return friendAvatarGradients[sum % friendAvatarGradients.length];
}

/// What a friend card shows. Built from the backend's friend activity.
class FriendModel {
  final String username;
  final String name;

  /// One short line: the song title, "Paused • title", "Online", "Offline"...
  final String statusText;

  /// Green circle.
  final bool isOnline;

  /// True while they are actively playing something (shows the equalizer icon).
  final bool isListening;

  /// True when there is a shared song we can play ("Tune In").
  final bool canTuneIn;
  final List<Color> avatarGradient;

  const FriendModel({
    required this.username,
    required this.name,
    required this.statusText,
    required this.isOnline,
    required this.isListening,
    required this.canTuneIn,
    required this.avatarGradient,
  });
}

class FriendCard extends StatelessWidget {
  final FriendModel friend;
  final VoidCallback onListenAlong;

  const FriendCard({
    super.key,
    required this.friend,
    required this.onListenAlong,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = friend.name.isNotEmpty ? friend.name : friend.username;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: friend.isOnline
              ? Pallete.gradient1.withAlpha(80)
              : Pallete.borderColor.withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Online Indicator
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: friend.avatarGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: friend.avatarGradient.first.withAlpha(70),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Pallete.cardColor,
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x8000E676),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Friend Name
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Pallete.whiteColor,
            ),
          ),

          Text(
            '@${friend.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Pallete.subtitleText),
          ),

          // Current activity
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (friend.isListening)
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Pallete.gradient2,
                    size: 13,
                  ),
                if (friend.isListening) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    friend.statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: friend.isListening
                          ? Pallete.gradient2
                          : Pallete.subtitleText,
                      fontWeight: friend.isListening
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: friend.canTuneIn ? onListenAlong : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: friend.canTuneIn
                    ? Pallete.gradient1.withAlpha(50)
                    : Pallete.borderColor.withAlpha(50),
                foregroundColor: friend.canTuneIn
                    ? Pallete.gradient2
                    : Pallete.subtitleText,
                padding: EdgeInsets.zero,
                elevation: 0,
                side: BorderSide(
                  color: friend.canTuneIn
                      ? Pallete.gradient1.withAlpha(120)
                      : Colors.transparent,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                friend.canTuneIn
                    ? 'Tune In'
                    : (friend.isOnline ? 'Online' : 'Away'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
