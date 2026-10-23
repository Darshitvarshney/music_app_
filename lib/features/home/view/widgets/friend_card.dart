import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

class FriendModel {
  final String id;
  final String name;
  final String currentSong;
  final String artist;
  final bool isOnline;
  final List<Color> avatarGradient;

  const FriendModel({
    required this.id,
    required this.name,
    required this.currentSong,
    required this.artist,
    required this.isOnline,
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
                    friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'F',
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
            friend.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Pallete.whiteColor,
            ),
          ),

          const SizedBox(height: 2),

          // Current Song Activity
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (friend.isOnline)
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Pallete.gradient2,
                    size: 13,
                  ),
                if (friend.isOnline) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    friend.isOnline ? friend.currentSong : 'Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: friend.isOnline
                          ? Pallete.gradient2
                          : Pallete.subtitleText,
                      fontWeight: friend.isOnline
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: friend.isOnline ? onListenAlong : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: friend.isOnline
                    ? Pallete.gradient1.withAlpha(50)
                    : Pallete.borderColor.withAlpha(50),
                foregroundColor: friend.isOnline
                    ? Pallete.gradient2
                    : Pallete.subtitleText,
                padding: EdgeInsets.zero,
                elevation: 0,
                side: BorderSide(
                  color: friend.isOnline
                      ? Pallete.gradient1.withAlpha(120)
                      : Colors.transparent,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                friend.isOnline ? 'Tune In' : 'Away',
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
