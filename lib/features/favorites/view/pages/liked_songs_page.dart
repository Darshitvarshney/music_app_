import 'package:flutter/material.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';

class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  final FavoritesService _favoritesService = FavoritesService();
  final MusicPlayerService _playerService = MusicPlayerService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _favoritesService.addListener(_onServiceUpdate);
    _playerService.addListener(_onServiceUpdate);
    _scrollController.addListener(_onScroll);

    // Initial load after current frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _favoritesService.likedSongs.isEmpty) {
        _favoritesService.fetchLikedSongs(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _favoritesService.removeListener(_onServiceUpdate);
    _playerService.removeListener(_onServiceUpdate);
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_favoritesService.isLoading &&
        _favoritesService.hasMore) {
      _favoritesService.fetchLikedSongs();
    }
  }

  void _playAll({bool shuffle = false}) {
    final songs = List<SongModel>.from(_favoritesService.likedSongs);
    if (songs.isEmpty) return;

    if (shuffle) {
      songs.shuffle();
    }
    _playerService.playSong(songs.first, queue: songs);
  }

  @override
  Widget build(BuildContext context) {
    final likedSongs = _favoritesService.likedSongs;
    final totalCount = _favoritesService.totalLikedCount > likedSongs.length
        ? _favoritesService.totalLikedCount
        : likedSongs.length;
    final isLoading = _favoritesService.isLoading;
    final currentPlayingSong = _playerService.currentSong;
    final isPlaying = _playerService.isPlaying;

    final filteredSongs = _filterQuery.isEmpty
        ? likedSongs
        : likedSongs.where((song) {
            final query = _filterQuery.toLowerCase();
            return song.song.toLowerCase().contains(query) ||
                song.displayArtist.toLowerCase().contains(query) ||
                song.album.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: Pallete.gradient2,
          backgroundColor: Pallete.cardColor,
          onRefresh: () async {
            await _favoritesService.fetchLikedSongs(refresh: true);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Custom Sliver App Bar with Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button & Search Filter Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Pallete.whiteColor, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Liked Songs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Pallete.whiteColor,
                            ),
                          ),
                          const SizedBox(width: 48), // Balancing spacer
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Hero Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C1654), Color(0xFF130D29)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Pallete.gradient1.withAlpha(80),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(140),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Big Glowing Heart Square
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Pallete.gradient1, Pallete.gradient2],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Pallete.gradient2.withAlpha(100),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Text Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Playlist',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Pallete.gradient2,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Liked Songs',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Pallete.whiteColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalCount ${totalCount == 1 ? 'song' : 'songs'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Pallete.subtitleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick Action Bar: Filter Search Bar & Play/Shuffle Controls
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Pallete.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Pallete.borderColor),
                              ),
                              child: TextField(
                                controller: _filterController,
                                onChanged: (value) {
                                  setState(() {
                                    _filterQuery = value.trim();
                                  });
                                },
                                style: const TextStyle(
                                  color: Pallete.whiteColor,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Find in liked songs',
                                  hintStyle: const TextStyle(
                                    color: Pallete.subtitleText,
                                    fontSize: 13,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Pallete.subtitleText,
                                    size: 20,
                                  ),
                                  suffixIcon: _filterQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            color: Pallete.subtitleText,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _filterController.clear();
                                            setState(() => _filterQuery = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Shuffle Button
                          IconButton(
                            onPressed: () => _playAll(shuffle: true),
                            tooltip: 'Shuffle Play',
                            icon: const Icon(
                              Icons.shuffle_rounded,
                              color: Pallete.whiteColor,
                              size: 26,
                            ),
                          ),

                          // Big Play Button
                          ElevatedButton(
                            onPressed: () => _playAll(shuffle: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Pallete.gradient2,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              elevation: 6,
                              shadowColor: Pallete.gradient2.withAlpha(160),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Empty State
              if (likedSongs.isEmpty && !isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Pallete.cardColor,
                              border: Border.all(color: Pallete.borderColor),
                            ),
                            child: const Icon(
                              Icons.favorite_border_rounded,
                              size: 56,
                              color: Pallete.subtitleText,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Songs you like will appear here',
                            style: TextStyle(
                              color: Pallete.whiteColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Save tracks you love by tapping the heart icon anywhere in the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Pallete.subtitleText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Pallete.gradient1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.search_rounded, color: Colors.white),
                            label: const Text(
                              'Find Songs',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Filtered list has no results
              if (likedSongs.isNotEmpty && filteredSongs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text(
                        'No songs matching "$_filterQuery"',
                        style: const TextStyle(
                          color: Pallete.subtitleText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // Track List
              if (filteredSongs.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = filteredSongs[index];
                      final isSelected = currentPlayingSong?.id == song.id;

                      return _buildSongTile(
                        index: index + 1,
                        song: song,
                        isSelected: isSelected,
                        isPlaying: isPlaying,
                        onTap: () {
                          _playerService.playSong(song, queue: filteredSongs);
                        },
                      );
                    },
                    childCount: filteredSongs.length,
                  ),
                ),

              // Bottom Loading Indicator / Spacing for Mini Player
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Pallete.gradient2,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const SizedBox(height: 60), // Room above MiniPlayer
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile({
    required int index,
    required SongModel song,
    required bool isSelected,
    required bool isPlaying,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: isSelected ? Pallete.cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Pallete.gradient2 : Pallete.subtitleText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 48,
                height: 48,
                color: Pallete.cardColor,
                child: song.image.isNotEmpty
                    ? Image.network(
                        song.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Pallete.borderColor,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Pallete.subtitleText,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        color: Pallete.subtitleText,
                      ),
              ),
            ),
          ],
        ),
        title: Text(
          song.song,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Pallete.gradient2 : Pallete.whiteColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            song.displayArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Pallete.subtitleText,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unlike / Heart Button
            IconButton(
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Remove from favorites',
              onPressed: () {
                _favoritesService.toggleLike(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "${song.song}" from Liked Songs'),
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: Pallete.gradient2,
                      onPressed: () {
                        _favoritesService.toggleLike(song);
                      },
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(
                Icons.favorite_rounded,
                color: Pallete.gradient2,
              ),
            ),
            const SizedBox(width: 12),

            // Duration
            Text(
              song.formattedDuration,
              style: const TextStyle(
                fontSize: 12,
                color: Pallete.subtitleText,
              ),
            ),
            const SizedBox(width: 10),

            // Mini play indicator if active
            if (isSelected)
              Icon(
                isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded,
                color: Pallete.gradient2,
                size: 20,
              ),
          ],
        ),
      ),
    ),
  );
}
}
