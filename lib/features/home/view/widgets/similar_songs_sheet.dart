import 'package:flutter/material.dart';
import '../../../../core/models/recommendation_models.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';

class SimilarSongsSheet extends StatefulWidget {
  final SongModel currentSong;

  const SimilarSongsSheet({super.key, required this.currentSong});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SimilarSongsSheet(currentSong: song),
    );
  }

  @override
  State<SimilarSongsSheet> createState() => _SimilarSongsSheetState();
}

class _SimilarSongsSheetState extends State<SimilarSongsSheet> {
  final RecommendationService _recommendationService = RecommendationService();
  final MusicPlayerService _player = MusicPlayerService();

  List<RecommendedSongModel> _similarSongs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSimilarSongs();
  }

  Future<void> _fetchSimilarSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _recommendationService.getSimilarSongs(
        widget.currentSong.id,
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _similarSongs = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load similar songs right now.';
          _isLoading = false;
        });
      }
    }
  }

  void _playSimilarSong(RecommendedSongModel recSong, int index) {
    final playableSongs = _similarSongs
        .where((s) => s.playbackEligibility.isEligible && s.mediaUrl.isNotEmpty)
        .map((s) => s.toSongModel())
        .toList();

    final targetSong = recSong.toSongModel();
    if (playableSongs.isEmpty) {
      playableSongs.add(targetSong);
    }

    _player.playQueue(
      playableSongs,
      initialIndex: index.clamp(0, playableSongs.length - 1),
    );
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing "${recSong.song}" from Song Radio'),
        backgroundColor: Pallete.cardColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.72,
      decoration: const BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Pallete.borderColor.withAlpha(150),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Pallete.gradient1, Pallete.gradient2],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Song Radio & Similar Tracks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Pallete.whiteColor,
                        ),
                      ),
                      Text(
                        'Similar to "${widget.currentSong.song}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Pallete.subtitleText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Pallete.subtitleText,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Pallete.borderColor, height: 1),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Pallete.gradient2),
            SizedBox(height: 16),
            Text(
              'Finding similar tracks with AI...',
              style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Pallete.errorColor,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Pallete.subtitleText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchSimilarSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: Pallete.gradient1,
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_similarSongs.isEmpty) {
      return const Center(
        child: Text(
          'No similar songs found for this track yet.',
          style: TextStyle(color: Pallete.subtitleText),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _similarSongs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final song = _similarSongs[index];
        final matchPercent = (song.recommendationScore * 100).round();

        return Material(
          color: Pallete.backgroundColor.withAlpha(180),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Pallete.borderColor.withAlpha(80)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.image.isNotEmpty
                  ? Image.network(
                      song.image,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _fallbackCover(),
                    )
                  : _fallbackCover(),
            ),
            title: Text(
              song.song,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Pallete.whiteColor,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  song.displayArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Pallete.subtitleText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Pallete.gradient1.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Pallete.gradient1.withAlpha(120),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$matchPercent% Match',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Pallete.gradient2,
                        ),
                      ),
                    ),
                    if (song.matchingGenres.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        song.matchingGenres.first,
                        style: const TextStyle(
                          color: Pallete.subtitleText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.play_circle_filled_rounded,
                color: Pallete.gradient2,
                size: 32,
              ),
              onPressed: () => _playSimilarSong(song, index),
            ),
            onTap: () => _playSimilarSong(song, index),
          ),
        );
      },
    );
  }

  Widget _fallbackCover() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note_rounded, color: Pallete.gradient1),
    );
  }
}
