import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/presence/repositories/presence_repository.dart';
import '../../features/search/model/song_model.dart';
import 'music_player_service.dart';

/// Reports the current song so friends can see it. Sends only on song or play/pause
/// change (debounced), plus a keep-alive while playing. Privacy is applied server-side.
class NowPlayingReporter {
  static final NowPlayingReporter _instance = NowPlayingReporter._internal();
  factory NowPlayingReporter() => _instance;

  /// Must stay comfortably below the server's 5 minute window.
  static const Duration keepAliveInterval = Duration(minutes: 3);
  static const Duration defaultDebounce = Duration(seconds: 2);

  final PresenceRepository _repository;
  final Duration _debounce;
  final Duration _keepAlive;

  Listenable? _source;
  SongModel? Function()? _readSong;
  bool Function()? _readPlaying;

  String? _lastKey;
  bool _hasPlayedThisSession = false;
  Timer? _debounceTimer;
  Timer? _keepAliveTimer;

  NowPlayingReporter._internal({PresenceRepository? repository})
      : _repository = repository ?? PresenceRepository(),
        _debounce = defaultDebounce,
        _keepAlive = keepAliveInterval;

  @visibleForTesting
  NowPlayingReporter.test(
    this._repository, {
    Duration debounce = defaultDebounce,
    Duration keepAlive = keepAliveInterval,
  })  : _debounce = debounce,
        _keepAlive = keepAlive;

  bool get isAttached => _source != null;

  /// Starts watching the app's music player. Safe to call repeatedly.
  void start() {
    final player = MusicPlayerService();
    attach(
      source: player,
      currentSong: () => player.currentSong,
      isPlaying: () => player.isPlaying,
    );
  }

  @visibleForTesting
  void attach({
    required Listenable source,
    required SongModel? Function() currentSong,
    required bool Function() isPlaying,
  }) {
    if (_source != null) return;
    _source = source;
    _readSong = currentSong;
    _readPlaying = isPlaying;
    source.addListener(_onPlayerChanged);
    _onPlayerChanged(); // report a song that is already playing
  }

  /// Stops watching. With [clear] the server also forgets the current song (use on logout).
  void stop({bool clear = false}) {
    _source?.removeListener(_onPlayerChanged);
    _source = null;
    _readSong = null;
    _readPlaying = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _lastKey = null;
    _hasPlayedThisSession = false;
    if (clear) {
      _repository.clearNowPlaying();
    }
  }

  void _onPlayerChanged() {
    final song = _readSong?.call();
    final playing = _readPlaying?.call() ?? false;
    final key = song == null ? '' : '${song.id}|$playing';
    if (key == _lastKey) return; // ignore position/buffering ticks
    _lastKey = key;

    if (playing) _hasPlayedThisSession = true;

    _debounceTimer?.cancel();
    // Nothing to report, or only the restored last-played song sitting paused at app launch.
    if (song == null || !_hasPlayedThisSession) {
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      return;
    }
    _debounceTimer = Timer(_debounce, _send);

    if (playing) {
      _keepAliveTimer ??= Timer.periodic(_keepAlive, (_) => _send());
    } else {
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
    }
  }

  void _send() {
    final song = _readSong?.call();
    if (song == null) return;
    _repository.setNowPlaying(song, isPlaying: _readPlaying?.call() ?? false);
  }
}
