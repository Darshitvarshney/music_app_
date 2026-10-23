import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/song_model.dart';
import '../../repositories/search_repository.dart';
import '../widgets/search_song_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SearchRepository _searchRepository = SearchRepository();
  final MusicPlayerService _playerService = MusicPlayerService();
  final FavoritesService _favoritesService = FavoritesService();

  Timer? _debounceTimer;
  bool _isLoading = false;
  String _errorMessage = '';
  List<SongModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _playerService.addListener(_onPlayerStateChanged);
    _favoritesService.addListener(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _playerService.removeListener(_onPlayerStateChanged);
    _favoritesService.removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _errorMessage = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await _searchRepository.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        if (results.isNotEmpty) {
          _favoritesService.checkBatchStatus(results.map((s) => s.id).toList());
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load songs. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final currentSong = _playerService.currentSong;
    final isPlaying = _playerService.isPlaying;

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Search Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Search',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Pallete.whiteColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Search Bar Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Pallete.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Pallete.borderColor,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Pallete.whiteColor),
                  decoration: InputDecoration(
                    hintText: 'What do you want to listen to?',
                    hintStyle: const TextStyle(color: Pallete.subtitleText, fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded, color: Pallete.whiteColor),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Pallete.subtitleText),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Body Content
            Expanded(
              child: _buildSearchBody(currentSong, isPlaying),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBody(SongModel? currentSong, bool isPlaying) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Pallete.gradient2,
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Pallete.errorColor, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(color: Pallete.subtitleText),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _executeSearch(_searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Pallete.cardColor,
              ),
              child: const Text('Retry', style: TextStyle(color: Pallete.whiteColor)),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded, color: Pallete.subtitleText, size: 50),
            const SizedBox(height: 12),
            Text(
              'No results found for "${_searchController.text.trim()}"',
              style: const TextStyle(
                color: Pallete.whiteColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check the spelling or try searching for another song.',
              style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        final isSelected = currentSong?.id == song.id;

        return SearchSongTile(
          song: song,
          isSelected: isSelected,
          isPlaying: isPlaying,
          onTap: () {
            _playerService.playSong(song);
          },
        );
      },
    );
  }
}
