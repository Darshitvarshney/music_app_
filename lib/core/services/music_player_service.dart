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
          androidStopForegroundOnPause: true,
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
    playNext(autoTriggered: true);
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
    await playSong(_queue[_queueIndex]);
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List<SongModel>.from(queue);
      final idx = _queue.indexWhere((s) => s.id == song.id);
      _queueIndex = idx != -1 ? idx : 0;
    } else if (_queue.isEmpty) {
      _queue = [song];
      _queueIndex = 0;
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

        await _player.play();

        _activeTelemetrySong = activeSong;
        if (isReplay) {
          _sendTelemetry(activeSong, 'replayed', duration: activeSong.duration);
        } else {
          _sendTelemetry(activeSong, 'played', duration: 0);
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
    if (_isLoadingAutoplay || _currentSong == null) return;
    _isLoadingAutoplay = true;

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
            (r) => r.playbackEligibility.isEligible && r.mediaUrl.isNotEmpty,
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
