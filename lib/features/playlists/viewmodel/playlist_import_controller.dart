import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/google_auth_service.dart';
import '../model/import_models.dart';
import '../model/playlist_model.dart';
import '../repositories/playlist_import_repository.dart';
import '../repositories/playlists_repository.dart';

enum ImportStage { idle, fetching, choosing, ready, importing, done }

enum ImportSource { youtube, spotify }

/// Drives one import: read the link, then match songs in small batches and add them as we go.
/// Batches keep each request short enough for the serverless backend.
class PlaylistImportController extends ChangeNotifier {
  final PlaylistImportRepository _repository;
  final PlaylistsRepository _playlistsRepository;
  final ImportSource source;
  GoogleTokenProvider? _googleProvider;
  final int maxTracks;
  final int batchSize;

  PlaylistImportController({
    PlaylistImportRepository? repository,
    PlaylistsRepository? playlistsRepository,
    GoogleTokenProvider? googleTokenProvider,
    this.source = ImportSource.youtube,
    this.maxTracks = 500,
    this.batchSize = 10,
  })  : _repository = repository ?? PlaylistImportRepository(),
        _playlistsRepository = playlistsRepository ?? PlaylistsRepository(),
        _googleProvider = googleTokenProvider;

  GoogleTokenProvider get _google => _googleProvider ??= GoogleAuthService();

  ImportStage _stage = ImportStage.idle;
  String? _errorMessage;
  String _sourceTitle = '';
  int _sourceTotal = 0;
  List<ImportTrack> _tracks = <ImportTrack>[];
  final List<ImportTrack> _unmatched = <ImportTrack>[];
  int _processed = 0;
  int _matched = 0;
  bool _cancelRequested = false;
  bool _fromFile = false;
  PlaylistModel? _playlist;
  String? _googleToken;
  List<MyPlaylistModel> _myPlaylists = <MyPlaylistModel>[];

  ImportStage get stage => _stage;
  String? get errorMessage => _errorMessage;
  String get sourceTitle => _sourceTitle;
  List<ImportTrack> get tracks => List<ImportTrack>.unmodifiable(_tracks);
  List<ImportTrack> get unmatched => List<ImportTrack>.unmodifiable(_unmatched);
  int get processed => _processed;
  int get matched => _matched;
  PlaylistModel? get playlist => _playlist;
  bool get wasTruncated => _sourceTotal > _tracks.length;
  bool get wasCancelled => _cancelRequested;

  /// Spotify links only expose the first 100 songs, so a full list hints at a longer playlist.
  bool get capReached =>
      source == ImportSource.spotify && !_fromFile && _tracks.length >= 100;
  bool get isSignedInToGoogle => _googleToken != null;
  List<MyPlaylistModel> get myPlaylists =>
      List<MyPlaylistModel>.unmodifiable(_myPlaylists);

  /// Reads the whole playlist (page by page, up to [maxTracks]) from the link.
  /// After a Google sign-in the token rides along, so private playlists work too.
  Future<void> loadLink(
    String url, {
    ImportStage failStage = ImportStage.idle,
  }) async {
    final String link = url.trim();
    if (link.isEmpty) return;
    _fromFile = false;

    _stage = ImportStage.fetching;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<ImportTrack> found = <ImportTrack>[];
      String title = '';
      int total = 0;
      if (source == ImportSource.spotify) {
        final SourcePageModel page = await _repository.fetchSpotifyPlaylist(link);
        found.addAll(page.tracks);
        title = page.title ?? '';
        total = page.total;
      } else {
        String? token;
        do {
          final SourcePageModel page = await _repository.fetchYoutubePage(
            link,
            pageToken: token,
            googleToken: _googleToken,
          );
          if (page.title != null) title = page.title!;
          if (page.total > total) total = page.total;
          found.addAll(page.tracks);
          token = page.nextPageToken;
        } while (token != null && found.length < maxTracks);
      }
      _acceptTracks(found, title, total, failStage);
    } catch (e) {
      await _dropExpiredGoogleToken(e);
      _fail(failStage, _messageOf(e, 'Could not read that playlist.'));
    }
  }

  /// Reads the songs from the text of an exported file (CSV or one song per line).
  Future<void> loadFile(String fileName, String text) async {
    _fromFile = true;
    _stage = ImportStage.fetching;
    _errorMessage = null;
    notifyListeners();

    try {
      final SourcePageModel page = await _repository.parseFile(text);
      final String title = fileName.replaceFirst(RegExp(r'\.[^.]*$'), '');
      _acceptTracks(page.tracks, title, page.total, ImportStage.idle);
    } catch (e) {
      _fail(ImportStage.idle, _messageOf(e, 'Could not read that file.'));
    }
  }

  void _acceptTracks(
    List<ImportTrack> found,
    String title,
    int total,
    ImportStage failStage,
  ) {
    if (found.isEmpty) {
      _fail(failStage, 'No songs found in that playlist.');
      return;
    }
    _tracks = found.length > maxTracks ? found.sublist(0, maxTracks) : found;
    _sourceTitle = title;
    _sourceTotal = total < found.length ? found.length : total;
    _stage = ImportStage.ready;
    notifyListeners();
  }

  /// Signs in with Google and lists the user's own playlists to pick from.
  Future<void> loadMyPlaylists() async {
    _stage = ImportStage.fetching;
    _errorMessage = null;
    notifyListeners();

    final String? token = await _google.getAccessToken();
    if (token == null) {
      _fail(ImportStage.idle,
          'Google sign-in was cancelled or did not work. Please try again.');
      return;
    }
    _googleToken = token;

    try {
      final List<MyPlaylistModel> found = <MyPlaylistModel>[];
      String? pageToken;
      int pages = 0;
      do {
        final MyPlaylistsPageModel page =
            await _repository.fetchMyPlaylists(token, pageToken: pageToken);
        found.addAll(page.items);
        pageToken = page.nextPageToken;
        pages++;
      } while (pageToken != null && pages < 4);

      if (found.isEmpty) {
        _fail(ImportStage.idle, 'No playlists found on that Google account.');
        return;
      }
      _myPlaylists = found;
      _stage = ImportStage.choosing;
      notifyListeners();
    } catch (e) {
      await _dropExpiredGoogleToken(e);
      _fail(ImportStage.idle, _messageOf(e, 'Could not load your playlists.'));
    }
  }

  Future<void> loadMyPlaylist(MyPlaylistModel playlist) {
    return loadLink(playlist.id, failStage: ImportStage.choosing);
  }

  void backToLink() {
    _stage = ImportStage.idle;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _dropExpiredGoogleToken(Object error) async {
    if (error is ApiException && error.code == 'google_token_invalid') {
      _googleToken = null;
      await _google.signOut();
    }
  }

  /// Creates the playlist, then fills it batch by batch. Does nothing unless a link is loaded.
  Future<void> startImport(String name) async {
    if (_stage != ImportStage.ready) return;

    _errorMessage = null;
    _processed = 0;
    _matched = 0;
    _unmatched.clear();
    _cancelRequested = false;
    _stage = ImportStage.importing;
    notifyListeners();

    final PlaylistModel playlist;
    try {
      playlist = await _playlistsRepository.createPlaylist(name);
    } catch (e) {
      _fail(ImportStage.ready, _messageOf(e, 'Could not create the playlist.'));
      return;
    }
    _playlist = playlist;

    for (int start = 0; start < _tracks.length; start += batchSize) {
      if (_cancelRequested) break;
      final int end =
          start + batchSize > _tracks.length ? _tracks.length : start + batchSize;
      final List<ImportTrack> batch = _tracks.sublist(start, end);

      try {
        final List<Map<String, dynamic>?> songs =
            await _repository.matchTracks(batch);
        final List<Map<String, dynamic>> found = <Map<String, dynamic>>[];
        for (int i = 0; i < batch.length; i++) {
          final Map<String, dynamic>? song = i < songs.length ? songs[i] : null;
          if (song == null) {
            _unmatched.add(batch[i]);
          } else {
            found.add(song);
          }
        }
        if (found.isNotEmpty) {
          await _repository.addSongs(playlist.id, found);
          _matched += found.length;
        }
        _processed = end;
        notifyListeners();
      } catch (e) {
        final String reason = _messageOf(e, 'Check your connection and try again.');
        _errorMessage =
            'Stopped after $_processed of ${_tracks.length} songs. $reason';
        break;
      }
    }

    _stage = ImportStage.done;
    notifyListeners();
  }

  /// Stops after the batch in flight; what was added so far stays in the playlist.
  void cancel() {
    if (_stage != ImportStage.importing) return;
    _cancelRequested = true;
    notifyListeners();
  }

  void _fail(ImportStage stage, String message) {
    _stage = stage;
    _errorMessage = message;
    notifyListeners();
  }

  static String _messageOf(Object error, String fallback) {
    if (error is ApiException) return error.message;
    if (error is PlaylistException) return error.message;
    return fallback;
  }
}
