import 'package:flutter/material.dart';
import '../../../../core/services/playlists_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/playlist_model.dart';
import '../pages/playlist_detail_page.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';

/// "Create playlist" tile plus one tile per playlist, for the Library tab.
class LibraryPlaylistsSection extends StatefulWidget {
  const LibraryPlaylistsSection({super.key});

  @override
  State<LibraryPlaylistsSection> createState() =>
      _LibraryPlaylistsSectionState();
}

class _LibraryPlaylistsSectionState extends State<LibraryPlaylistsSection> {
  final PlaylistsService _service = PlaylistsService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _service.fetch();
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _createPlaylist() async {
    final String? name = await promptPlaylistName(context);
    if (name == null || !mounted) return;

    final String? error = await _service.create(name);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _open(PlaylistModel playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) =>
            PlaylistDetailPage(playlist: playlist),
      ),
    );
  }

  Widget _tile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: leading,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Pallete.whiteColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Pallete.subtitleText),
          ),
          trailing: trailing ??
              const Icon(Icons.chevron_right_rounded, color: Pallete.subtitleText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PlaylistModel> playlists = _service.playlists;

    return Column(
      children: [
        _tile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Pallete.borderColor,
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
          title: 'Create playlist',
          subtitle: 'Make your own with any name',
          onTap: _createPlaylist,
          trailing: const SizedBox.shrink(),
        ),
        if (_service.isLoading && playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Pallete.gradient2,
                ),
              ),
            ),
          ),
        if (!_service.isLoading &&
            playlists.isEmpty &&
            _service.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: _service.fetch,
              icon: const Icon(Icons.refresh_rounded, color: Pallete.subtitleText),
              label: Text(
                '${_service.errorMessage} Tap to retry',
                style: const TextStyle(color: Pallete.subtitleText, fontSize: 12),
              ),
            ),
          ),
        for (final PlaylistModel playlist in playlists)
          _tile(
            leading: PlaylistCover(images: playlist.coverImages),
            title: playlist.name,
            subtitle: playlist.subtitle,
            onTap: () => _open(playlist),
          ),
      ],
    );
  }
}
