import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/playlists_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/import_models.dart';
import '../../model/playlist_model.dart';
import '../../viewmodel/playlist_import_controller.dart';
import 'playlist_detail_page.dart';

/// Imports a playlist from a pasted link (YouTube Music or Spotify), or from an exported file.
class ImportPlaylistPage extends StatefulWidget {
  final ImportSource source;
  const ImportPlaylistPage({super.key, this.source = ImportSource.youtube});

  @override
  State<ImportPlaylistPage> createState() => _ImportPlaylistPageState();
}

class _ImportPlaylistPageState extends State<ImportPlaylistPage> {
  late final PlaylistImportController _controller =
      PlaylistImportController(source: widget.source);
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  ImportStage _lastStage = ImportStage.idle;

  bool get _isSpotify => widget.source == ImportSource.spotify;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.cancel();
    _linkController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_controller.stage == ImportStage.ready &&
        _lastStage != ImportStage.ready) {
      _nameController.text = _controller.sourceTitle;
    }
    if (_controller.stage == ImportStage.done &&
        _lastStage != ImportStage.done) {
      PlaylistsService().fetch();
    }
    _lastStage = _controller.stage;
    setState(() {});
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _linkController.text = text;
  }

  void _findPlaylist() {
    FocusScope.of(context).unfocus();
    _controller.loadLink(_linkController.text);
  }

  Future<void> _pickFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Playlist files',
        extensions: <String>['csv', 'txt'],
        mimeTypes: <String>['text/csv', 'text/plain', 'text/comma-separated-values'],
      );
      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null || !mounted) return;
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _snack('Could not read that file.');
        return;
      }
      if (bytes.length > 900000) {
        _snack('That file is too large. Export just one playlist.');
        return;
      }
      _controller.loadFile(file.name, utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      _snack('Could not open the file picker.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startImport() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    _controller.startImport(name);
  }

  Future<void> _openPlaylist() async {
    final PlaylistModel? created = _controller.playlist;
    if (created == null) return;
    final PlaylistModel playlist = PlaylistsService().playlists.firstWhere(
          (PlaylistModel p) => p.id == created.id,
          orElse: () => created,
        );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) =>
            PlaylistDetailPage(playlist: playlist),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Pallete.subtitleText),
      counterStyle: const TextStyle(color: Pallete.subtitleText),
      suffixIcon: suffix,
      filled: true,
      fillColor: Pallete.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Pallete.gradient2,
          foregroundColor: Pallete.whiteColor,
          disabledBackgroundColor: Pallete.borderColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _error() {
    final String? message = _controller.errorMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: const TextStyle(color: Pallete.errorColor, fontSize: 13),
      ),
    );
  }

  Widget _linkSection() {
    final bool busy = _controller.stage == ImportStage.fetching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSpotify
              ? 'Paste the link of a Spotify playlist. Open it, tap the three-dot menu, '
                  'then Share and Copy link.'
              : 'Paste the link of a public or unlisted YouTube Music or YouTube playlist. '
                  'For private playlists, sign in with Google instead.',
          style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _linkController,
          enabled: !busy,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Pallete.whiteColor),
          cursorColor: Pallete.gradient2,
          decoration: _fieldDecoration(
            _isSpotify
                ? 'https://open.spotify.com/playlist/...'
                : 'https://music.youtube.com/playlist?list=...',
            suffix: IconButton(
              icon: const Icon(Icons.content_paste_rounded,
                  color: Pallete.subtitleText),
              onPressed: busy ? null : _paste,
            ),
          ),
          onSubmitted: (_) => _findPlaylist(),
        ),
        const SizedBox(height: 16),
        _primaryButton(busy ? 'Reading playlist...' : 'Find playlist',
            busy ? null : _findPlaylist),
        const SizedBox(height: 12),
        if (_isSpotify) ...[
          _outlinedButton(Icons.upload_file_rounded, 'Upload a file instead',
              busy ? null : _pickFile),
          _error(),
          Center(
            child: TextButton(
              onPressed: _showPrivateHelp,
              child: const Text(
                'Private playlist or Liked Songs? See how',
                style: TextStyle(color: Pallete.gradient2),
              ),
            ),
          ),
        ] else ...[
          _outlinedButton(
            Icons.account_circle_outlined,
            'Choose from my YouTube playlists',
            busy ? null : _controller.loadMyPlaylists,
          ),
          _error(),
        ],
      ],
    );
  }

  Widget _outlinedButton(IconData icon, String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Pallete.whiteColor),
        label: Text(label, style: const TextStyle(color: Pallete.whiteColor)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Pallete.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _helpHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Pallete.whiteColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _helpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              number,
              style: const TextStyle(
                color: Pallete.gradient2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivateHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pallete.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importing a private playlist',
                  style: TextStyle(
                    color: Pallete.whiteColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try pasting its link as it is first. Many private playlists '
                  'still open from a shared link. If we cannot read it, pick one of these.',
                  style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
                ),
                _helpHeading('Option 1: make it public for a minute'),
                _helpStep('1.', 'In Spotify, open the playlist and tap the three-dot menu.'),
                _helpStep('2.', 'Choose "Make public" (or "Add to profile").'),
                _helpStep('3.', 'Tap the menu again, then Share and Copy link.'),
                _helpStep('4.', 'Paste the link here and tap Find playlist.'),
                _helpStep('5.', 'Once you see the song count, go back to Spotify and choose "Make private" (or "Remove from profile").'),
                _helpHeading('Option 2: upload a file'),
                _helpStep('1.', 'Export the playlist as a CSV file with a tool such as Exportify, TuneMyMusic or Soundiiz.'),
                _helpStep('2.', 'Come back here and tap Upload a file.'),
                _helpHeading('Liked Songs'),
                const Text(
                  'Liked Songs has no link. Add those songs to a new playlist in Spotify '
                  'first, then use option 1, or export it as a file.',
                  style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _primaryButton('Upload a file', () {
                  Navigator.pop(sheetContext);
                  _pickFile();
                }),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text(
                      'Got it',
                      style: TextStyle(color: Pallete.subtitleText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _choosingSection() {
    final List<MyPlaylistModel> mine = _controller.myPlaylists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick a playlist to import',
          style: TextStyle(
            color: Pallete.whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _error(),
        const SizedBox(height: 12),
        for (final MyPlaylistModel playlist in mine)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Pallete.cardColor,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => _controller.loadMyPlaylist(playlist),
                title: Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Pallete.whiteColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${playlist.count} ${playlist.count == 1 ? 'video' : 'videos'}',
                  style: const TextStyle(
                      color: Pallete.subtitleText, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Pallete.subtitleText),
              ),
            ),
          ),
        TextButton(
          onPressed: _controller.backToLink,
          child: const Text(
            'Back',
            style: TextStyle(color: Pallete.subtitleText),
          ),
        ),
      ],
    );
  }

  Widget _readySection() {
    final int count = _controller.tracks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _controller.sourceTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Pallete.whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _controller.wasTruncated
              ? 'Found more than $count songs. The first $count will be imported.'
              : 'Found $count ${count == 1 ? 'song' : 'songs'}.',
          style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
        ),
        if (_controller.capReached)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Spotify only shares the first 100 songs of a playlist through a link. '
              'If yours is longer, upload a file to get the rest.',
              style: TextStyle(color: Pallete.gradient3, fontSize: 13),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Pallete.whiteColor),
          cursorColor: Pallete.gradient2,
          decoration: _fieldDecoration('Playlist name'),
        ),
        const SizedBox(height: 8),
        _primaryButton('Import songs', _startImport),
        _error(),
      ],
    );
  }

  Widget _importingSection() {
    final int total = _controller.tracks.length;
    final double progress = total == 0 ? 0 : _controller.processed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _controller.wasCancelled ? 'Stopping...' : 'Importing songs...',
          style: const TextStyle(
            color: Pallete.whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: Pallete.borderColor,
          color: Pallete.gradient2,
        ),
        const SizedBox(height: 8),
        Text(
          '${_controller.processed} of $total checked • ${_controller.matched} found',
          style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep this screen open until it finishes.',
          style: TextStyle(color: Pallete.subtitleText, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _controller.wasCancelled ? null : _controller.cancel,
          child: const Text(
            'Stop',
            style: TextStyle(color: Pallete.subtitleText),
          ),
        ),
      ],
    );
  }

  Widget _doneSection() {
    final List<ImportTrack> missed = _controller.unmatched;
    final int total = _controller.tracks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Added ${_controller.matched} of $total songs',
          style: const TextStyle(
            color: Pallete.whiteColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _error(),
        const SizedBox(height: 16),
        if (_controller.matched > 0)
          _primaryButton('Open playlist', _openPlaylist),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Done',
            style: TextStyle(color: Pallete.subtitleText),
          ),
        ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "Couldn't find ${missed.length} ${missed.length == 1 ? 'song' : 'songs'}",
            style: const TextStyle(
              color: Pallete.whiteColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final ImportTrack track in missed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                track.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Pallete.subtitleText, fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }

  Widget _body() {
    switch (_controller.stage) {
      case ImportStage.choosing:
        return _choosingSection();
      case ImportStage.ready:
        return _readySection();
      case ImportStage.importing:
        return _importingSection();
      case ImportStage.done:
        return _doneSection();
      case ImportStage.idle:
      case ImportStage.fetching:
        return _linkSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _controller.stage != ImportStage.importing,
      child: Scaffold(
        backgroundColor: Pallete.backgroundColor,
        appBar: AppBar(
          backgroundColor: Pallete.backgroundColor,
          foregroundColor: Pallete.whiteColor,
          elevation: 0,
          title: Text(_isSpotify ? 'Import from Spotify' : 'Import from YouTube Music'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _body(),
          ),
        ),
      ),
    );
  }
}
