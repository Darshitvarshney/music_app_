import 'package:flutter/material.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/services/playlists_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';
import '../../model/playlist_model.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/playlist_dialogs.dart';

class PlaylistDetailPage extends StatefulWidget {
  final PlaylistModel playlist;
  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final PlaylistsService _service = PlaylistsService();
  final MusicPlayerService _playerService = MusicPlayerService();

  late PlaylistModel _playlist;
  List<SongModel> _songs = <SongModel>[];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _playerService.addListener(_onPlayerUpdate);
    _load();
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final PlaylistDetailModel? detail = await _service.loadDetail(_playlist.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (detail == null) {
        _loadError = 'Could not load this playlist.';
      } else {
        _playlist = detail.playlist;
        _songs = detail.songs;
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// Plays the whole playlist, either in saved order or shuffled.
  void _playAll({required bool shuffle}) {
    if (_songs.isEmpty) return;
    final List<SongModel> queue = List<SongModel>.from(_songs);
    if (shuffle) queue.shuffle();
    _playerService.playSong(queue.first, queue: queue);
  }

  Future<void> _remove(SongModel song) async {
    final int index = _songs.indexWhere((s) => s.id == song.id);
    if (index == -1) return;
    setState(() => _songs.removeAt(index));

    final String? error = await _service.removeSong(_playlist, song);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        final int at = index > _songs.length ? _songs.length : index;
        _songs.insert(at, song);
      });
      _toast(error);
    } else {
      setState(() {
        _playlist = PlaylistModel(
          id: _playlist.id,
          name: _playlist.name,
          description: _playlist.description,
          songCount: _songs.length,
          coverImages: _playlist.coverImages,
          updatedAt: _playlist.updatedAt,
        );
      });
      _toast('Removed "${song.song}"');
    }
  }

  Future<void> _rename() async {
    final String? name = await promptPlaylistName(
      context,
      title: 'Rename playlist',
      confirmLabel: 'Save',
      initialName: _playlist.name,
    );
    if (name == null || name == _playlist.name || !mounted) return;

    final String? error = await _service.rename(_playlist, name);
    if (!mounted) return;
    if (error != null) {
      _toast(error);
      return;
    }
    await _load();
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        title: const Text(
          'Delete playlist?',
          style: TextStyle(color: Pallete.whiteColor),
        ),
        content: Text(
          '"${_playlist.name}" will be deleted. Your songs are not affected.',
          style: const TextStyle(color: Pallete.subtitleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Pallete.subtitleText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Pallete.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final String? error = await _service.delete(_playlist);
    if (!mounted) return;
    if (error != null) {
      _toast(error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Pallete.whiteColor,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Pallete.whiteColor),
            color: Pallete.cardColor,
            onSelected: (String value) {
              if (value == 'rename') _rename();
              if (value == 'delete') _delete();
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename', style: TextStyle(color: Pallete.whiteColor)),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Delete playlist',
                  style: TextStyle(color: Pallete.errorColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bool hasSongs = _songs.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlaylistCover(images: _playlist.coverImages, size: 96, radius: 10),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Pallete.whiteColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _playlist.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Pallete.subtitleText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: hasSongs ? () => _playAll(shuffle: false) : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Pallete.gradient2,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Pallete.borderColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: hasSongs ? () => _playAll(shuffle: true) : null,
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('Shuffle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Pallete.whiteColor,
                        side: const BorderSide(color: Pallete.borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _songs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Pallete.gradient2),
      );
    }

    if (_loadError != null && _songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Pallete.errorColor, size: 48),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              style: const TextStyle(color: Pallete.whiteColor, fontSize: 16),
            ),
            TextButton(
              onPressed: _load,
              child: const Text(
                'Try again',
                style: TextStyle(color: Pallete.gradient2),
              ),
            ),
          ],
        ),
      );
    }

    final SongModel? current = _playerService.currentSong;

    return RefreshIndicator(
      color: Pallete.gradient2,
      backgroundColor: Pallete.cardColor,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _songs.isEmpty ? 2 : _songs.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) return _buildHeader();

          if (_songs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    color: Pallete.subtitleText,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This playlist is empty',
                    style: TextStyle(
                      color: Pallete.whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Use the playlist icon on any song to add it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final SongModel song = _songs[index - 1];
          final bool isSelected = current?.id == song.id;
          return _buildSongTile(song, isSelected);
        },
      ),
    );
  }

  Widget _buildSongTile(SongModel song, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: isSelected ? Pallete.cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _playerService.playSong(song, queue: _songs),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: ClipRRect(
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
          subtitle: Text(
            song.displayArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Pallete.subtitleText),
          ),
          trailing: IconButton(
            tooltip: 'Remove from playlist',
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: Pallete.subtitleText,
              size: 22,
            ),
            onPressed: () => _remove(song),
          ),
        ),
      ),
    );
  }
}
