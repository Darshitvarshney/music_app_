import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';
import '../widgets/full_screen_player.dart';

class OfflineSongsPage extends StatefulWidget {
  const OfflineSongsPage({super.key});

  @override
  State<OfflineSongsPage> createState() => _OfflineSongsPageState();
}

class _OfflineSongsPageState extends State<OfflineSongsPage> {
  final DownloadService _downloadService = DownloadService();
  final MusicPlayerService _playerService = MusicPlayerService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _downloadService.addListener(_onServiceUpdate);
    _playerService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onServiceUpdate);
    _playerService.removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _playAll({bool shuffle = false}) {
    final songs = List<SongModel>.from(_downloadService.downloadedSongs);
    if (songs.isEmpty) return;

    if (shuffle) {
      songs.shuffle();
    }
    _playerService.playSong(songs.first, queue: songs);
  }

  void _confirmDeleteSong(SongModel song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Download?',
          style: TextStyle(
            color: Pallete.whiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to delete "${song.song}" from this device to free up storage?',
          style: const TextStyle(color: Pallete.subtitleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Pallete.subtitleText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadService.deleteSong(song.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${song.song}" from device storage.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadedSongs = _downloadService.downloadedSongs;
    final currentPlayingSong = _playerService.currentSong;
    final isPlaying = _playerService.isPlaying;

    final filteredSongs = _searchQuery.isEmpty
        ? downloadedSongs
        : downloadedSongs.where((song) {
            final query = _searchQuery.toLowerCase();
            return song.song.toLowerCase().contains(query) ||
                song.displayArtist.toLowerCase().contains(query) ||
                song.album.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar & Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Back button, Title & Search toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Pallete.whiteColor,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38EF7D).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF38EF7D).withAlpha(80),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.offline_pin_rounded,
                                    color: Color(0xFF38EF7D),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '100% Offline',
                                    style: TextStyle(
                                      color: const Color(0xFF38EF7D),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (downloadedSongs.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  _isSearching ? Icons.close : Icons.search_rounded,
                                  color: Pallete.whiteColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearching = !_isSearching;
                                    if (!_isSearching) {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Title & Summary Hero Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF11998E),
                            Color(0xFF38EF7D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF11998E).withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(50),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_download_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Offline Downloads',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${downloadedSongs.length} ${downloadedSongs.length == 1 ? 'song' : 'songs'} • ${_downloadService.totalFormattedStorage}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withAlpha(220),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Songs downloaded here are stored directly on your device. You can play them anytime, anywhere with zero cellular data or Wi-Fi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(230),
                              height: 1.35,
                            ),
                          ),
                          if (downloadedSongs.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _playAll(shuffle: false),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      'Play All',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _playAll(shuffle: true),
                                    icon: const Icon(
                                      Icons.shuffle_rounded,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'Shuffle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Search input if open
                    if (_isSearching && downloadedSongs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Pallete.whiteColor),
                        decoration: InputDecoration(
                          hintText: 'Filter offline tracks...',
                          hintStyle: TextStyle(
                            color: Pallete.subtitleText.withAlpha(150),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Pallete.subtitleText,
                          ),
                          filled: true,
                          fillColor: Pallete.cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Pallete.borderColor.withAlpha(120),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Pallete.borderColor.withAlpha(120),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF38EF7D),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Downloaded Song List or Empty State
            if (downloadedSongs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else if (filteredSongs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        color: Pallete.subtitleText.withAlpha(160),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No matches for "$_searchQuery"',
                        style: const TextStyle(
                          color: Pallete.subtitleText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = filteredSongs[index];
                      final isCurrentSong = currentPlayingSong?.id == song.id;
                      final isCurrentPlaying = isCurrentSong && isPlaying;

                      return _buildSongTile(
                        song: song,
                        isCurrentPlaying: isCurrentPlaying,
                        onTap: () {
                          _playerService.playSong(song, queue: filteredSongs);
                          FullScreenPlayer.open(context, song: song);
                        },
                        onDelete: () => _confirmDeleteSong(song),
                      );
                    },
                    childCount: filteredSongs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile({
    required SongModel song,
    required bool isCurrentPlaying,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final localArt = _downloadService.getLocalArtworkPath(song.id);
    final hasLocalArt = localArt != null && File(localArt).existsSync();
    final fileSize = _downloadService.formatSongFileSize(song.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrentPlaying
            ? const Color(0xFF11998E).withAlpha(40)
            : Pallete.cardColor.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlaying
              ? const Color(0xFF38EF7D).withAlpha(140)
              : Pallete.borderColor.withAlpha(90),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: onTap,
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Pallete.gradient1, Pallete.gradient2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLocalArt
                  ? Image.file(
                      File(localArt),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _tileFallbackArtwork(),
                    )
                  : (song.image.isNotEmpty && song.image.startsWith('http')
                      ? Image.network(
                          song.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _tileFallbackArtwork(),
                        )
                      : _tileFallbackArtwork()),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.offline_pin_rounded,
                  color: Color(0xFF38EF7D),
                  size: 14,
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
            fontWeight: FontWeight.bold,
            color: isCurrentPlaying
                ? const Color(0xFF38EF7D)
                : Pallete.whiteColor,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '${song.displayArtist} • ${song.formattedDuration}${fileSize.isNotEmpty ? ' • $fileSize' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Pallete.subtitleText,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentPlaying)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38EF7D).withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF38EF7D),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PLAYING',
                      style: TextStyle(
                        color: Color(0xFF38EF7D),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              tooltip: 'Delete download',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Pallete.subtitleText,
                size: 22,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileFallbackArtwork() {
    return const Center(
      child: Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF11998E).withAlpha(60),
                    const Color(0xFF38EF7D).withAlpha(60),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF38EF7D).withAlpha(120),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF38EF7D),
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Offline Downloads Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Pallete.whiteColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Listen without using mobile data. Open any song in full screen and tap the download button to save it locally on your device.',
              style: TextStyle(
                fontSize: 14,
                color: Pallete.subtitleText.withAlpha(220),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38EF7D),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: const Text(
                'Explore Music',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
