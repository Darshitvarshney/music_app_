import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

class MiniPlayer extends StatefulWidget {
  final String songTitle;
  final String artist;
  final VoidCallback? onExpand;

  const MiniPlayer({
    super.key,
    this.songTitle = 'Midnight City Beats',
    this.artist = 'Neon Wave • Synth & Chill',
    this.onExpand,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isPlaying = true;
  bool _isLiked = false;
  final double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Pallete.cardColor.withAlpha(240),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Pallete.borderColor.withAlpha(120),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Album Art
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Pallete.gradient1, Pallete.gradient2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.songTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Pallete.whiteColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Pallete.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Like Button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                    });
                  },
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                    color: _isLiked ? Pallete.gradient2 : Pallete.whiteColor,
                    size: 22,
                  ),
                ),

                // Play / Pause Button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Pallete.whiteColor,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          // Mini Seek / Progress bar
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Pallete.inactiveSeekColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Pallete.gradient2),
              minHeight: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}
