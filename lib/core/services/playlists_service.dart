import 'package:flutter/foundation.dart';
import '../../features/playlists/model/playlist_model.dart';
import '../../features/playlists/repositories/playlists_repository.dart';
import '../../features/search/model/song_model.dart';

/// The user's playlists, shared by the Library and the add-to-playlist sheet.
/// Mutating methods return an error message (null on success) instead of throwing.
class PlaylistsService extends ChangeNotifier {
  static final PlaylistsService _instance = PlaylistsService._internal();
  factory PlaylistsService() => _instance;

  final PlaylistsRepository _repository;

  PlaylistsService._internal({PlaylistsRepository? repository})
      : _repository = repository ?? PlaylistsRepository();

  @visibleForTesting
  PlaylistsService.test(this._repository);

  final List<PlaylistModel> _playlists = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PlaylistModel> get playlists => List.unmodifiable(_playlists);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetch() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<PlaylistModel> result = await _repository.getPlaylists();
      _playlists
        ..clear()
        ..addAll(result);
    } catch (e) {
      _errorMessage = _messageOf(e, 'Could not load your playlists.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or `null` when the playlist was created.
  Future<String?> create(String name) async {
    try {
      final PlaylistModel created = await _repository.createPlaylist(name);
      _playlists.insert(0, created);
      notifyListeners();
      return null;
    } catch (e) {
      return _messageOf(e, 'Could not create playlist.');
    }
  }

  /// Creates a playlist and returns it (for "create and add this song" flows).
  Future<PlaylistModel?> createAndGet(String name) async {
    try {
      final PlaylistModel created = await _repository.createPlaylist(name);
      _playlists.insert(0, created);
      notifyListeners();
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<String?> rename(PlaylistModel playlist, String name) async {
    try {
      final PlaylistModel updated =
          await _repository.renamePlaylist(playlist.id, name);
      _replace(updated);
      return null;
    } catch (e) {
      return _messageOf(e, 'Could not rename playlist.');
    }
  }

  /// Returns an error message, or `null` when the playlist was deleted.
  Future<String?> delete(PlaylistModel playlist) async {
    final int index = _playlists.indexWhere((p) => p.id == playlist.id);
    PlaylistModel? removed;
    if (index != -1) {
      removed = _playlists.removeAt(index);
      notifyListeners();
    }

    try {
      await _repository.deletePlaylist(playlist.id);
      return null;
    } catch (e) {
      if (removed != null) {
        final int at = index > _playlists.length ? _playlists.length : index;
        _playlists.insert(at, removed);
        notifyListeners();
      }
      return _messageOf(e, 'Could not delete playlist.');
    }
  }

  /// Loads one playlist with its songs. Returns `null` on failure.
  Future<PlaylistDetailModel?> loadDetail(String id) async {
    try {
      final PlaylistDetailModel detail = await _repository.getPlaylist(id);
      _replace(detail.playlist);
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// Returns a user-facing result message. [added] tells whether the song was new there.
  Future<AddSongOutcome> addSong(PlaylistModel playlist, SongModel song) async {
    try {
      final AddSongResult result =
          await _repository.addSong(playlist.id, song);
      if (result.playlist != null) _replace(result.playlist!);
      return AddSongOutcome(
        ok: true,
        added: result.added,
        message: result.added
            ? 'Added to "${playlist.name}"'
            : 'Already in "${playlist.name}"',
      );
    } catch (e) {
      return AddSongOutcome(
        ok: false,
        added: false,
        message: _messageOf(e, 'Could not add song.'),
      );
    }
  }

  /// Returns an error message, or `null` when the song was removed.
  Future<String?> removeSong(PlaylistModel playlist, SongModel song) async {
    try {
      final PlaylistModel? updated =
          await _repository.removeSong(playlist.id, song.id);
      if (updated != null) _replace(updated);
      return null;
    } catch (e) {
      return _messageOf(e, 'Could not remove song.');
    }
  }

  /// IDs of playlists already holding [songId]; empty on failure.
  Future<Set<String>> playlistIdsForSong(String songId) async {
    try {
      return await _repository.getPlaylistIdsForSong(songId);
    } catch (_) {
      return <String>{};
    }
  }

  /// Drop in-memory playlists, e.g. on logout.
  void reset() {
    _playlists.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void _replace(PlaylistModel updated) {
    final int index = _playlists.indexWhere((p) => p.id == updated.id);
    if (index == -1) {
      _playlists.insert(0, updated);
    } else {
      _playlists.removeAt(index);
      // Changed playlists float to the top, matching the server's ordering.
      _playlists.insert(0, updated);
    }
    notifyListeners();
  }

  static String _messageOf(Object error, String fallback) {
    if (error is PlaylistException) return error.message;
    return fallback;
  }
}

class AddSongOutcome {
  final bool ok;
  final bool added;
  final String message;
  const AddSongOutcome({
    required this.ok,
    required this.added,
    required this.message,
  });
}
