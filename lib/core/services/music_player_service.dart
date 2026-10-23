import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/auth/repositories/auth_local_repository.dart';
import '../../features/search/model/song_model.dart';
import '../../features/search/repositories/search_repository.dart';
import 'recommendation_service.dart';

class MusicPlayerService extends ChangeNotifier {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  final SearchRepository _searchRepository = SearchRepository();
  final RecommendationService _recommendationService = RecommendationService();

  SongModel? _currentSong;
  List<SongModel> _queue = [];
  int _queueIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Autoplay & Telemetry state
  bool _autoplayEnabled = true;
  bool _isLoadingAutoplay = false;
  SongModel? _activeTelemetrySong;
  bool _completedRecorded = false;

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

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progressRatio {
    if (_duration.inMilliseconds > 0) {
      return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  void setAutoplayEnabled(bool enabled) {
    _autoplayEnabled = enabled;
    notifyListeners();
  }

  void _initStreams() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      _isPlaying = isPlaying &&
          processingState != ProcessingState.completed &&
          processingState != ProcessingState.idle;

      _isBuffering = processingState == ProcessingState.buffering ||
          processingState == ProcessingState.loading;

      if (processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
      notifyListeners();
    });

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

  Future<void> playQueue(List<SongModel> newQueue, {int initialIndex = 0}) async {
    if (newQueue.isEmpty) return;
    _queue = List<SongModel>.from(newQueue);
    _queueIndex = (initialIndex >= 0 && initialIndex < _queue.length) ? initialIndex : 0;
    await playSong(_queue[_queueIndex]);
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List<SongModel>.from(queue);
      final idx = _queue.indexWhere((s) => s.id == song.id);
      _queueIndex = idx != -1 ? idx : 0;
    }

    // If the song is already loaded and playable, toggle play/pause
    if (_currentSong?.id == song.id &&
        _currentSong?.mediaUrl == song.mediaUrl &&
        song.mediaUrl.isNotEmpty) {
      if (_isPlaying) {
        await pause();
      } else {
        await resume();
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
    final isReplay = _activeTelemetrySong?.id == song.id && _position.inSeconds > 0;

    SongModel activeSong = song;
    _currentSong = activeSong;
    _position = Duration.zero;
    _duration = Duration(seconds: activeSong.duration);
    _isBuffering = true;
    _completedRecorded = false;
    notifyListeners();

    try {
      if (activeSong.mediaUrl.trim().isEmpty) {
        final resolved = await _searchRepository.resolvePlayableSong(activeSong);
        if (resolved != null && resolved.mediaUrl.trim().isNotEmpty) {
          activeSong = activeSong.copyWith(
            mediaUrl: resolved.mediaUrl,
            mediaPreviewUrl: resolved.mediaPreviewUrl,
            duration: resolved.duration > 0 ? resolved.duration : activeSong.duration,
            image: resolved.image.isNotEmpty ? resolved.image : activeSong.image,
            permaUrl: resolved.permaUrl.isNotEmpty ? resolved.permaUrl : activeSong.permaUrl,
          );
          _currentSong = activeSong;
          _duration = Duration(seconds: activeSong.duration);
          if (_queueIndex >= 0 && _queueIndex < _queue.length) {
            _queue[_queueIndex] = activeSong;
          }
          notifyListeners();
        }
      }

      AuthLocalRepository().saveLastPlayedSong(activeSong);

      if (activeSong.mediaUrl.trim().isNotEmpty) {
        await _player.setUrl(activeSong.mediaUrl);
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
        debugPrint('Could not resolve playable mediaUrl for: ${activeSong.song}');
        _isBuffering = false;
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error playing song: $e');
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
          .where((r) => r.playbackEligibility.isEligible && r.mediaUrl.isNotEmpty)
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
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
