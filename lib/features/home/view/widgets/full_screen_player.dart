import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';
import 'similar_songs_sheet.dart';

class FullScreenPlayer extends StatefulWidget {
  final SongModel? initialSong;

  const FullScreenPlayer({super.key, this.initialSong});

  static void open(BuildContext context, {SongModel? song}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenPlayer(initialSong: song),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  final MusicPlayerService _player = MusicPlayerService();
  final FavoritesService _favoritesService = FavoritesService();
  final DownloadService _downloadService = DownloadService();

  double? _draggedSeconds;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerUpdate);
    _favoritesService.addListener(_onPlayerUpdate);
    _downloadService.addListener(_onPlayerUpdate);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    _favoritesService.removeListener(_onPlayerUpdate);
    _downloadService.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _player.currentSong ?? widget.initialSong;

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Pallete.backgroundColor,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final isPlaying = _player.isPlaying;
    final isBuffering = _player.isBuffering;
    final isLiked = _favoritesService.isLiked(currentSong.id);

    final totalDuration = _player.duration.inSeconds > 0
        ? _player.duration
        : Duration(seconds: currentSong.duration);

    final currentPosition = _draggedSeconds != null
        ? Duration(seconds: _draggedSeconds!.round())
        : _player.position;

    final double maxSeconds = totalDuration.inSeconds > 0
        ? totalDuration.inSeconds.toDouble()
        : 1.0;

    final double sliderValue =
        _draggedSeconds ??
        currentPosition.inSeconds.toDouble().clamp(0.0, maxSeconds);

    final screenSize = MediaQuery.of(context).size;
    final maxArtworkByHeight = (screenSize.height * 0.38);
    final artworkSize = (screenSize.width - 64).clamp(
      180.0,
      maxArtworkByHeight.clamp(180.0, 340.0),
    );

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Pallete.gradient1.withAlpha(50),
                Pallete.cardColor.withAlpha(220),
                Pallete.backgroundColor,
                Colors.black,
              ],
              stops: const [0.0, 0.35, 0.75, 1.0],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          children: [
                            // Top Navigation Bar (Collapse button, Title, More)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Minimize',
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Pallete.whiteColor,
                                    size: 34,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'PLAYING FROM QUEUE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: Pallete.subtitleText.withAlpha(
                                          220,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentSong.album.isNotEmpty
                                          ? currentSong.album
                                          : 'JioSaavn Music',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Pallete.whiteColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),

                            const Spacer(flex: 1),

                            // Album Artwork with Shadow & Glass Border
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Center(
                                child: Container(
                                  width: artworkSize,
                                  height: artworkSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Pallete.gradient1.withAlpha(90),
                                        blurRadius: 36,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 14),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withAlpha(160),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Pallete.borderColor.withAlpha(140),
                                      width: 1.2,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _buildArtworkImage(currentSong),
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),

                            // Song Title, Artist, Download & Like Buttons
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentSong.song,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Pallete.whiteColor,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentSong.displayArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Pallete.subtitleText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildDownloadButton(currentSong),
                                IconButton(
                                  tooltip: isLiked ? 'Unlike' : 'Like',
                                  icon: Icon(
                                    isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isLiked
                                        ? Pallete.gradient2
                                        : Pallete.whiteColor,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    _favoritesService.toggleLike(currentSong);
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Music Timeline / Draggable Slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                activeTrackColor: Pallete.gradient2,
                                inactiveTrackColor: Colors.white.withAlpha(30),
                                thumbColor: Pallete.whiteColor,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7.0,
                                  elevation: 4.0,
                                ),
                                overlayColor: Pallete.gradient2.withAlpha(60),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16.0,
                                ),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: maxSeconds,
                                value: sliderValue.clamp(0.0, maxSeconds),
                                onChanged: (newValue) {
                                  setState(() {
                                    _draggedSeconds = newValue;
                                  });
                                },
                                onChangeEnd: (finalValue) {
                                  final seekPos = Duration(
                                    seconds: finalValue.round(),
                                  );
                                  _player.seek(seekPos);
                                  setState(() {
                                    _draggedSeconds = null;
                                  });
                                },
                              ),
                            ),

                            // Position and Duration Timestamps
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(currentPosition),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Pallete.subtitleText.withAlpha(
                                        200,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(totalDuration),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Pallete.subtitleText.withAlpha(
                                        200,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Main Playback Controls (Shuffle, Prev, Play/Pause, Next, Autoplay)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Loop / Repeat Song Toggle Button
                                IconButton(
                                  tooltip: _player.isLoopEnabled
                                      ? 'Loop On (Repeating current track)'
                                      : 'Loop Off',
                                  icon: Icon(
                                    _player.isLoopEnabled
                                        ? Icons.repeat_one_rounded
                                        : Icons.all_inclusive_rounded,
                                    color: _player.isLoopEnabled
                                        ? Pallete.gradient2
                                        : Pallete.subtitleText.withAlpha(120),
                                    size: 26,
                                  ),
                                  onPressed: () {
                                    _player.toggleLoop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _player.isLoopEnabled
                                              ? 'Loop enabled: Replaying current track'
                                              : 'Loop disabled: Playing queue',
                                        ),
                                        duration: const Duration(milliseconds: 1200),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),

                                // Previous Button
                                IconButton(
                                  tooltip: 'Previous',
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    color: Pallete.whiteColor,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _player.playPrevious();
                                  },
                                ),

                                // Play / Pause / Buffering Primary Button
                                GestureDetector(
                                  onTap: isBuffering
                                      ? null
                                      : () {
                                          _player.togglePlayPause();
                                        },
                                  child: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Pallete.gradient1,
                                          Pallete.gradient2,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Pallete.gradient2.withAlpha(
                                            140,
                                          ),
                                          blurRadius: 24,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isBuffering
                                          ? const SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3.0,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                    ),
                                  ),
                                ),

                                // Next Button
                                IconButton(
                                  tooltip: 'Next',
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color:
                                        (_player.hasNext ||
                                            _player.autoplayEnabled)
                                        ? Pallete.whiteColor
                                        : Pallete.subtitleText.withAlpha(120),
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _player.playNext();
                                  },
                                ),

                                // Similar Songs Button next to Next button
                                IconButton(
                                  tooltip: 'Similar Tracks & Radio',
                                  icon: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Pallete.gradient2,
                                    size: 26,
                                  ),
                                  onPressed: () {
                                    SimilarSongsSheet.show(
                                      context,
                                      currentSong,
                                    );
                                  },
                                ),
                              ],
                            ),

                            const Spacer(flex: 1),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkImage(SongModel song) {
    final localArt = _downloadService.getLocalArtworkPath(song.id);
    if (localArt != null && File(localArt).existsSync()) {
      return Image.file(
        File(localArt),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackArtwork(),
      );
    }

    final imageUrl = song.image.trim();
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        );
      } else if (File(imageUrl).existsSync()) {
        return Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        );
      }
    }
    return _fallbackArtwork();
  }

  Widget _buildDownloadButton(SongModel song) {
    final isDownloaded = _downloadService.isDownloaded(song.id);
    final isDownloading = _downloadService.isDownloading(song.id);
    final progress = _downloadService.getDownloadProgress(song.id);

    if (isDownloading) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: const Color(0xFF38EF7D),
                  backgroundColor: Colors.white.withAlpha(40),
                ),
              ),
              if (progress > 0)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    color: Pallete.whiteColor,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      tooltip: isDownloaded
          ? 'Downloaded to device (Tap to manage)'
          : 'Download song for offline listening',
      icon: Icon(
        isDownloaded
            ? Icons.download_done_rounded
            : Icons.arrow_circle_down_rounded,
        color: isDownloaded
            ? const Color(0xFF38EF7D)
            : Pallete.whiteColor.withAlpha(220),
        size: 28,
      ),
      onPressed: () => _handleDownloadTap(song, isDownloaded),
    );
  }

  void _handleDownloadTap(
    SongModel song,
    bool isDownloaded,
  ) {
    if (isDownloaded) {
      _showManageDownloadSheet(song);
    } else {
      _startDownload(song);
    }
  }

  Future<void> _startDownload(SongModel song) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF38EF7D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Downloading "${song.song}"...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final success = await _downloadService.downloadSong(song);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF38EF7D),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Downloaded "${song.song}"! Available in Offline Play.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Pallete.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showManageDownloadSheet(SongModel song) {
    final fileSize = _downloadService.formatSongFileSize(song.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Pallete.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38EF7D).withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.offline_pin_rounded,
                        color: Color(0xFF38EF7D),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.song,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Pallete.whiteColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Downloaded on device storage${fileSize.isNotEmpty ? ' • $fileSize' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Pallete.subtitleText.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Pallete.errorColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Pallete.errorColor,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Remove Download',
                    style: TextStyle(
                      color: Pallete.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Delete file from this device to free up space',
                    style: TextStyle(fontSize: 12, color: Pallete.subtitleText),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _downloadService.deleteSong(song.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed "${song.song}" from device.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Pallete.gradient1, Pallete.gradient2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white, size: 72),
      ),
    );
  }
}
