import 'package:flutter/material.dart';
import '../../../../core/services/playlists_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../search/model/song_model.dart';
import '../../model/playlist_model.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';

/// Bottom sheet to add [song] to (or remove it from) the user's playlists,
/// or to create a new playlist containing it.
Future<void> showAddToPlaylistSheet(BuildContext context, SongModel song) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pallete.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final SongModel song;
  const _AddToPlaylistSheet({required this.song});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final PlaylistsService _service = PlaylistsService();
  Set<String> _containing = <String>{};
  bool _membershipLoaded = false;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final Set<String> ids = await _service.playlistIdsForSong(widget.song.id);
    _service.fetch();
    if (!mounted) return;
    setState(() {
      _containing = ids;
      _membershipLoaded = true;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _toggle(PlaylistModel playlist) async {
    if (_busy.contains(playlist.id)) return;
    setState(() => _busy.add(playlist.id));

    final bool wasIn = _containing.contains(playlist.id);
    String? error;
    String message;
    if (wasIn) {
      error = await _service.removeSong(playlist, widget.song);
      message = 'Removed from "${playlist.name}"';
    } else {
      final AddSongOutcome outcome =
          await _service.addSong(playlist, widget.song);
      error = outcome.ok ? null : outcome.message;
      message = outcome.message;
    }

    if (!mounted) return;
    setState(() {
      _busy.remove(playlist.id);
      if (error == null) {
        if (wasIn) {
          _containing.remove(playlist.id);
        } else {
          _containing.add(playlist.id);
        }
      }
    });
    _toast(error ?? message);
  }

  Future<void> _createNew() async {
    final String? name = await promptPlaylistName(context);
    if (name == null || !mounted) return;

    final PlaylistModel? created = await _service.createAndGet(name);
    if (!mounted) return;
    if (created == null) {
      _toast('Could not create "$name". Is the name already used?');
      return;
    }
    await _toggle(created);
  }

  @override
  Widget build(BuildContext context) {
    final List<PlaylistModel> playlists = _service.playlists;
    final double maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add to playlist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Pallete.whiteColor,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _createNew,
                    icon: const Icon(Icons.add_rounded, color: Pallete.gradient2),
                    label: const Text(
                      'New',
                      style: TextStyle(color: Pallete.gradient2),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: _buildList(playlists)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<PlaylistModel> playlists) {
    if ((_service.isLoading || !_membershipLoaded) && playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: Pallete.gradient2),
        ),
      );
    }

    if (playlists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _service.errorMessage ?? 'No playlists yet. Tap "New" to make one.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Pallete.subtitleText),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: playlists.length,
      itemBuilder: (BuildContext context, int index) {
        final PlaylistModel playlist = playlists[index];
        final bool isIn = _containing.contains(playlist.id);
        final bool isBusy = _busy.contains(playlist.id);

        return ListTile(
          onTap: () => _toggle(playlist),
          leading: PlaylistCover(images: playlist.coverImages, size: 44, radius: 6),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Pallete.whiteColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            playlist.subtitle,
            style: const TextStyle(fontSize: 12, color: Pallete.subtitleText),
          ),
          trailing: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Pallete.gradient2,
                  ),
                )
              : Icon(
                  isIn
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: isIn ? Pallete.gradient2 : Pallete.subtitleText,
                ),
        );
      },
    );
  }
}
