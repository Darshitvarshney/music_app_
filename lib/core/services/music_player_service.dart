import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/auth/repositories/auth_local_repository.dart';
import '../../features/search/model/song_model.dart';
import '../../features/search/repositories/search_repository.dart';
import 'audio_handler.dart';
import 'download_service.dart';
import 'recommendation_service.dart';

class MusicPlayerService extends ChangeNotifier {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  final SearchRepository _searchRepository = SearchRepository();
  final RecommendationService _recommendationService = RecommendationService();

  MusicAudioHandler? _audioHandler;
  MusicAudioHandler? get audioHandler => _audioHandler;

  SongModel? _currentSong;
  List<SongModel> _queue = [];
  int _queueIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Autoplay, Loop & Telemetry state
  bool _autoplayEnabled = true;
  bool _isLoopEnabled = false;
  bool _isLoadingAutoplay = false;
  Future<void>? _inFlightAutoplayFuture;
  SongModel? _activeTelemetrySong;
  bool _completedRecorded = false;

  Future<void> initAudioService() async {
    if (_audioHandler != null) return;
    try {
      _audioHandler = await AudioService.init(
        builder: () => MusicAudioHandler(
          player: _player,
          onPlayNext: playNext,
          onPlayPrevious: playPrevious,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.client.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: false,
          // Stay a foreground service while paused so listening rooms keep syncing with the screen off
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'drawable/ic_music_notification',
        ),
      );
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

  // Audio engine state tracking
  String? _loadedSongId;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  MusicPlayerService._internal() {
    _initStreams();
    _loadLastPlayedSong();
  }

  Future<void> _loadLastPlayedSong() async {
    try {
      final lastSong = await AuthLocalRepository().getLastPlayedSong();
      if (lastSong != null && _currentSong == null) {
        _currentSong = lastSong;
        _duration = Duration(seconds: lastSong.duration);
        _queue = [lastSong];
        _queueIndex = 0;
        // _loadedSongId is left null until audio source is actually loaded into _player
        notifyListeners();
      }
    } catch (_) {}
  }

  SongModel? get currentSong => _currentSong;
  List<SongModel> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  bool get hasNext => _queue.isNotEmpty && _queueIndex + 1 < _queue.length;
  bool get hasPrevious => _queue.isNotEmpty && _queueIndex > 0;
  bool get autoplayEnabled => _autoplayEnabled;

  /// True while moving to the next song because the previous one ended (not a manual tap/skip).
  bool _autoAdvancing = false;
  bool get isAutoAdvancing => _autoAdvancing;

  /// Listening rooms: keeps the audio foreground service alive so the app can keep syncing
  /// when nothing is playing and the screen is off.
  void setRoomKeepAlive(bool active) {
    _roomKeepAlive = active;
    _updateKeepAlive();
  }

  /// Device sync: same idea as [setRoomKeepAlive]; the service stays up while either is on.
  void setDeviceSyncKeepAlive(bool active) {
    _syncKeepAlive = active;
    _updateKeepAlive();
  }

  bool _roomKeepAlive = false;
  bool _syncKeepAlive = false;

  void _updateKeepAlive() {
    _audioHandler?.setRoomPlaceholder(
      _roomKeepAlive || _syncKeepAlive,
      forDeviceSync: !_roomKeepAlive && _syncKeepAlive,
    );
  }
  bool get isLoopEnabled => _isLoopEnabled;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progressRatio {
    if (_duration.inMilliseconds > 0) {
      return (_position.inMilliseconds / _duration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
    }
    return 0.0;
  }

  void setAutoplayEnabled(bool enabled) {
    _autoplayEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLoopEnabled(bool enabled) async {
    _isLoopEnabled = enabled;
    try {
      await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    await setLoopEnabled(!_isLoopEnabled);
  }

  void _initStreams() {
    _playerStateSub = _player.playerStateStream.listen(
      (state) {
        final isPlaying = state.playing;
        final processingState = state.processingState;

        _isPlaying =
            isPlaying &&
            processingState != ProcessingState.completed &&
            processingState != ProcessingState.idle;

        _isBuffering =
            processingState == ProcessingState.buffering ||
            processingState == ProcessingState.loading;

        if (processingState == ProcessingState.completed) {
          _handlePlaybackCompleted();
        }
        notifyListeners();
      },
      onError: (err) {
        debugPrint('PlayerState stream error: $err');
        _isBuffering = false;
        _isPlaying = false;
        notifyListeners();
      },
    );

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  void _handlePlaybackCompleted() {
    _position = Duration.zero;
    if (_activeTelemetrySong != null && !_completedRecorded) {
      _completedRecorded = true;
      _sendTelemetry(
        _activeTelemetrySong!,
        'completed',
        duration: _activeTelemetrySong!.duration,
      );
    }
    if (_isLoopEnabled && _currentSong != null) {
      _completedRecorded = false;
      seek(Duration.zero);
      _player.play();
      return;
    }
    _autoAdvancing = true;
    playNext(autoTriggered: true).whenComplete(() => _autoAdvancing = false);
  }

  void _sendTelemetry(SongModel song, String eventType, {int duration = 0}) {
    unawaited(() async {
      try {
        final userId = await AuthLocalRepository().getEffectiveUserId();
        await _recommendationService.sendListeningEvent(
          userId: userId,
          songId: song.id,
          eventType: eventType,
          duration: duration,
          songMetadata: song.toMap(),
        );
      } catch (_) {}
    }());
  }

  Future<void> playQueue(
    List<SongModel> newQueue, {
    int initialIndex = 0,
  }) async {
    if (newQueue.isEmpty) return;
    _queue = List<SongModel>.from(newQueue);
    _queueIndex = (initialIndex >= 0 && initialIndex < _queue.length)
        ? initialIndex
        : 0;
    await playSong(_queue[_queueIndex], queue: _queue);
  }

  /// Plays one song and prefetches personalized autoplay (/api/recommend) behind it.
  Future<void> playSongWithAutoplay(SongModel song) async {
    final bool isAlreadyLoadedInPlayer =
        _loadedSongId == song.id &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.idle;

    if (isAlreadyLoadedInPlayer) {
      if (_isPlaying) {
        await pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }

    _queue = [song];
    _queueIndex = 0;
    await playSong(song, queue: [song]);
    // Eagerly prefetch recommendations from /api/recommend for autoplay
    await _fetchAutoplayQueue(andPlay: false);
  }

  /// Device sync: puts this phone on [song] at [position] and play/pause as asked, without
  /// toggling or restarting a song that is already loaded. [position] is read late, after loading.
  Future<void> applySyncedState(
    SongModel song, {
    required bool playing,
    required Duration Function() position,
  }) async {
    final bool loaded = _loadedSongId == song.id &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.idle;
    if (!loaded) {
      await playSong(
        song,
        queue: <SongModel>[song],
        startAt: position,
        startPlaying: playing,
      );
      return;
    }

    final Duration target = position();
    final int driftMs = (_position - target).inMilliseconds.abs();
    if (driftMs > 400 || _player.processingState == ProcessingState.completed) {
      await _player.seek(target);
    }
    if (playing && !_isPlaying) {
      unawaited(_player.play());
    } else if (!playing && _isPlaying) {
      await _player.pause();
    }
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? queue,
    Duration Function()? startAt,
    bool startPlaying = true,
  }) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List<SongModel>.from(queue);
      final idx = _queue.indexWhere((s) => s.id == song.id);
      _queueIndex = idx != -1 ? idx : 0;
    } else {
      final isAlreadyAtQueueIndex = _queueIndex >= 0 &&
          _queueIndex < _queue.length &&
          _queue[_queueIndex].id == song.id;

      if (!isAlreadyAtQueueIndex) {
        _queue = [song];
        _queueIndex = 0;
      }
    }

    // If the song is already loaded in the audio engine and playable, toggle play/pause
    final bool isAlreadyLoadedInPlayer =
        _loadedSongId == song.id &&
        _player.audioSource != null &&
        _player.processingState != ProcessingState.idle;

    if (isAlreadyLoadedInPlayer) {
      if (_isPlaying) {
        await pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }

    // Telemetry: Handle early skip of previously playing song
    if (_activeTelemetrySong != null &&
        _activeTelemetrySong!.id != song.id &&
        !_completedRecorded &&
        _position.inSeconds < 30) {
      _sendTelemetry(
        _activeTelemetrySong!,
        'skipped',
        duration: _position.inSeconds,
      );
    }

    // Telemetry: If restarting same song from start
    final isReplay =
        _activeTelemetrySong?.id == song.id && _position.inSeconds > 0;

    SongModel activeSong = song;
    _currentSong = activeSong;
    _position = Duration.zero;
    _duration = Duration(seconds: activeSong.duration);
    _isBuffering = true;
    _completedRecorded = false;
    notifyListeners();

    try {
      bool setUrlSuccess = false;

      // 1. Check if song exists locally on device (offline download)
      final localAudioPath = DownloadService.instance.getLocalAudioPath(activeSong.id) ??
          (File(activeSong.mediaUrl).existsSync() ? activeSong.mediaUrl : null);

      if (localAudioPath != null && File(localAudioPath).existsSync()) {
        try {
          await _player.setFilePath(localAudioPath);
          setUrlSuccess = true;
        } catch (e) {
          debugPrint('Failed to load local file ($e). Falling back to network URL...');
        }
      }

      // 2. If no local audio, attempt remote mediaUrl if available
      if (!setUrlSuccess && activeSong.mediaUrl.trim().startsWith('http')) {
        try {
          await _player.setUrl(activeSong.mediaUrl);
          setUrlSuccess = true;
        } catch (e) {
          debugPrint('Stored mediaUrl failed ($e). Re-resolving fresh URL...');
        }
      }

      // 3. If no mediaUrl or previous setUrl failed (e.g., expired CDN link), fetch fresh URL
      if (!setUrlSuccess) {
        try {
          final resolved = await _searchRepository.resolvePlayableSong(
            activeSong,
            forceResolve: true,
          );
          if (resolved != null && resolved.mediaUrl.trim().isNotEmpty) {
            activeSong = activeSong.copyWith(
              mediaUrl: resolved.mediaUrl,
              mediaPreviewUrl: resolved.mediaPreviewUrl,
              duration: resolved.duration > 0
                  ? resolved.duration
                  : activeSong.duration,
              image: resolved.image.isNotEmpty
                  ? resolved.image
                  : activeSong.image,
              permaUrl: resolved.permaUrl.isNotEmpty
                  ? resolved.permaUrl
                  : activeSong.permaUrl,
            );
            _currentSong = activeSong;
            _duration = Duration(seconds: activeSong.duration);
            if (_queueIndex >= 0 && _queueIndex < _queue.length) {
              _queue[_queueIndex] = activeSong;
            }
            notifyListeners();

            if (File(activeSong.mediaUrl).existsSync()) {
              await _player.setFilePath(activeSong.mediaUrl);
            } else {
              await _player.setUrl(activeSong.mediaUrl);
            }
            setUrlSuccess = true;
          }
        } catch (e) {
          debugPrint('Network resolve failed ($e). Device may be offline.');
        }
      }

      if (setUrlSuccess) {
        _loadedSongId = activeSong.id;
        _audioHandler?.setCurrentSong(activeSong);
        AuthLocalRepository().saveLastPlayedSong(activeSong);

        try {
          await _player.setLoopMode(_isLoopEnabled ? LoopMode.one : LoopMode.off);
        } catch (_) {}

        final Duration? resumeAt = startAt?.call();
        if (resumeAt != null && resumeAt > Duration.zero) {
          try {
            await _player.seek(resumeAt);
          } catch (_) {}
        }
        if (startPlaying) await _player.play();

        _activeTelemetrySong = activeSong;
        if (startPlaying) {
          if (isReplay) {
            _sendTelemetry(activeSong, 'replayed', duration: activeSong.duration);
          } else {
            _sendTelemetry(activeSong, 'played', duration: 0);
          }
        }

        // Prefetch recommendations if queue is running low
        _checkAndPrefetchAutoplay();
      } else {
        debugPrint(
          'Could not resolve or play mediaUrl for: ${activeSong.song}',
        );
        _loadedSongId = null;
        _isBuffering = false;
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error playing song: $e');
      _loadedSongId = null;
      _isBuffering = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndPrefetchAutoplay() async {
    if (!_autoplayEnabled || _isLoadingAutoplay || _currentSong == null) return;
    final remainingInQueue = _queue.length - 1 - _queueIndex;
    if (remainingInQueue <= 2) {
      await _fetchAutoplayQueue(andPlay: false);
    }
  }

  Future<void> _fetchAutoplayQueue({bool andPlay = false}) async {
    if (_currentSong == null) return;

    if (_isLoadingAutoplay) {
      if (andPlay && _inFlightAutoplayFuture != null) {
        await _inFlightAutoplayFuture;
        if (hasNext) {
          _queueIndex++;
          await playSong(_queue[_queueIndex]);
        }
      }
      return;
    }

    _isLoadingAutoplay = true;
    final completer = Completer<void>();
    _inFlightAutoplayFuture = completer.future;

    try {
      final userId = await AuthLocalRepository().getEffectiveUserId();
      final excludedIds = _queue.map((s) => s.id).toList();

      final recommendations = await _recommendationService.getAutoplayQueue(
        userId: userId,
        currentSong: _currentSong!.toMap(),
        excludedSongIds: excludedIds,
        limit: 10,
      );

      final playable = recommendations
          .where(
            (r) =>
                r.playbackEligibility.isEligible &&
                (r.mediaUrl.isNotEmpty || r.song.isNotEmpty),
          )
          .map((r) => r.toSongModel())
          .where((s) => !_queue.any((q) => q.id == s.id))
          .toList();

      if (playable.isNotEmpty) {
        _queue.addAll(playable);
        notifyListeners();
        if (andPlay && hasNext) {
          _queueIndex++;
          await playSong(_queue[_queueIndex]);
        }
      }
    } catch (e) {
      debugPrint('Error fetching autoplay queue: $e');
    } finally {
      _isLoadingAutoplay = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
      _inFlightAutoplayFuture = null;
    }
  }

  Future<void> playNext({bool autoTriggered = false}) async {
    // If autoTriggered and loop is enabled, loop the same song
    if (autoTriggered && _isLoopEnabled && _currentSong != null) {
      _completedRecorded = false;
      await seek(Duration.zero);
      await _player.play();
      return;
    }

    // If user manually pressed Next early, track skipped event
    if (!autoTriggered &&
        _activeTelemetrySong != null &&
        !_completedRecorded &&
        _position.inSeconds < 30) {
      _sendTelemetry(
        _activeTelemetrySong!,
        'skipped',
        duration: _position.inSeconds,
      );
    }

    if (hasNext) {
      _queueIndex++;
      await playSong(_queue[_queueIndex]);
    } else if (_autoplayEnabled) {
      // Infinite Autoplay: Queue ran out, fetch next batch and play immediately
      await _fetchAutoplayQueue(andPlay: true);
    }
  }

  Future<void> playPrevious() async {
    if (_position.inSeconds > 3) {
      // Seek back to start if more than 3 seconds in
      await seek(Duration.zero);
      return;
    }

    if (hasPrevious) {
      _queueIndex--;
      await playSong(_queue[_queueIndex]);
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    if (_currentSong != null &&
        (_loadedSongId != _currentSong!.id ||
            _player.audioSource == null ||
            _player.processingState == ProcessingState.idle)) {
      await playSong(_currentSong!);
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    if (_player.audioSource == null) return;
    await _player.seek(position);
  }

  Future<void> stop() async {
    _loadedSongId = null;
    await _player.stop();
    await _audioHandler?.stop();
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioHandler?.stop();
    _player.dispose();
    super.dispose();
  }
}
