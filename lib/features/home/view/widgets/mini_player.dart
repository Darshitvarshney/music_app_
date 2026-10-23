import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';
import 'full_screen_player.dart';

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
  final MusicPlayerService _player = MusicPlayerService();
  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerUpdate);
    _favoritesService.addListener(_onPlayerUpdate);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    _favoritesService.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _handleTapToExpand(BuildContext context, SongModel? currentSong) {
    if (widget.onExpand != null) {
      widget.onExpand!();
    } else if (currentSong != null) {
      FullScreenPlayer.open(context, song: currentSong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _player.currentSong;
    final title = currentSong?.song ?? widget.songTitle;
    final artist = currentSong?.displayArtist ?? widget.artist;
    final isPlaying = _player.isPlaying;
    final isBuffering = _player.isBuffering;
    final progress = _player.progressRatio;
    final imageUrl = currentSong?.image ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTapToExpand(context, currentSong),
      child: Container(
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
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? (imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              )
                            : (File(imageUrl).existsSync()
                                ? Image.file(
                                    File(imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  )))
                        : const Icon(
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
                          title,
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
                          artist,
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
                    tooltip:
                        currentSong != null &&
                            _favoritesService.isLiked(currentSong.id)
                        ? 'Unlike'
                        : 'Like',
                    onPressed: () {
                      if (currentSong != null) {
                        _favoritesService.toggleLike(currentSong);
                      }
                    },
                    icon: Icon(
                      currentSong != null &&
                              _favoritesService.isLiked(currentSong.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color:
                          currentSong != null &&
                              _favoritesService.isLiked(currentSong.id)
                          ? Pallete.gradient2
                          : Pallete.whiteColor,
                      size: 22,
                    ),
                  ),

                  // Play / Pause / Buffering Button
                  IconButton(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    onPressed: isBuffering
                        ? null
                        : () {
                            if (currentSong != null) {
                              _player.togglePlayPause();
                            }
                          },
                    icon: isBuffering
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Pallete.gradient2,
                            ),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Pallete.whiteColor,
                            size: 32,
                          ),
                  ),

                  // Next Button (when queue has songs or autoplay is active)
                  if (_player.hasNext || _player.autoplayEnabled)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Next',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Pallete.whiteColor,
                        size: 26,
                      ),
                      onPressed: () {
                        _player.playNext();
                      },
                    ),
                ],
              ),
            ),

            // Mini Seek / Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Pallete.inactiveSeekColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Pallete.gradient2,
                ),
                minHeight: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
