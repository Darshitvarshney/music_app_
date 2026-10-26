import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/search/model/song_model.dart';
import 'download_service.dart';
import 'favorites_service.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;

  SongModel? _currentSong;

  MusicAudioHandler({
    required this.player,
    required this.onPlayNext,
    required this.onPlayPrevious,
  }) {
    _initStreams();
  }

  void setCurrentSong(SongModel song) {
    _currentSong = song;
    _broadcastMediaItem(song);
    _broadcastPlaybackState();
  }

  bool _roomPlaceholderActive = false;

  /// Shows a "waiting" notification in a room with nothing loaded, so the foreground
  /// service (and room sync) survives screen-off. A real song replaces it.
  void setRoomPlaceholder(bool active) {
    _roomPlaceholderActive = active;
    if (player.processingState != ProcessingState.idle) return;
    if (active) {
      _broadcastRoomPlaceholder();
    } else {
      stop();
    }
  }

  void _broadcastRoomPlaceholder() {
    mediaItem.add(
      const MediaItem(
        id: 'dirito_room',
        title: 'Listening room',
        artist: 'Waiting for the next song',
      ),
    );
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.stop],
        systemActions: const {MediaAction.stop},
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.ready,
        playing: true,
      ),
    );
  }

  void _initStreams() {
    // Listen to playback event changes (position, buffered position, processing state)
    player.playbackEventStream.listen((event) {
      _broadcastPlaybackState();
    });

    // Listen to player playing state changes
    player.playerStateStream.listen((state) {
      _broadcastPlaybackState();
    });

    // Listen to favorite status toggles to update the heart icon in notification & lockscreen
    FavoritesService().addListener(_broadcastPlaybackState);
  }

  void _broadcastMediaItem(SongModel song) {
    Uri? artUri;
    final localArt = DownloadService.instance.getLocalArtworkPath(song.id);
    if (localArt != null && File(localArt).existsSync()) {
      artUri = Uri.file(localArt);
    } else if (song.image.trim().isNotEmpty) {
      if (song.image.startsWith('http')) {
        artUri = Uri.parse(song.image.trim());
      } else if (File(song.image.trim()).existsSync()) {
        artUri = Uri.file(song.image.trim());
      }
    }

    final duration = song.duration > 0
        ? Duration(seconds: song.duration)
        : (player.duration ?? Duration.zero);

    mediaItem.add(
      MediaItem(
        id: song.id,
        album: song.album.isNotEmpty ? song.album : 'JioSaavn Music',
        title: song.song,
        artist: song.displayArtist,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  void _broadcastPlaybackState() {
    if (_roomPlaceholderActive && player.processingState == ProcessingState.idle) {
      _broadcastRoomPlaceholder();
      return;
    }
    final isLiked = _currentSong != null &&
        FavoritesService().isLiked(_currentSong!.id);

    final favoriteControl = MediaControl(
      androidIcon: isLiked
          ? 'drawable/ic_heart_filled'
          : 'drawable/ic_heart_outline',
      label: isLiked ? 'Unlike' : 'Like',
      action: MediaAction.custom,
      customAction: const CustomMediaAction(name: 'favorite'),
    );

    final isPlaying = player.playing;
    final processingState = player.processingState;

    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    final isIdle = audioProcessingState == AudioProcessingState.idle;

    playbackState.add(
      PlaybackState(
        controls: isIdle
            ? const []
            : [
                MediaControl.skipToPrevious,
                if (isPlaying) MediaControl.pause else MediaControl.play,
                MediaControl.skipToNext,
                favoriteControl,
              ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop,
        },
        androidCompactActionIndices: isIdle ? const [] : const [0, 1, 2],
        processingState: audioProcessingState,
        playing: isPlaying,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    onPlayNext();
  }

  @override
  Future<void> skipToPrevious() async {
    onPlayPrevious();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(
      PlaybackState(
        controls: const [],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await super.onNotificationDeleted();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'favorite') {
      if (_currentSong != null) {
        await FavoritesService().toggleLike(_currentSong!);
        _broadcastPlaybackState();
      }
    }
    return super.customAction(name, extras);
  }
}
