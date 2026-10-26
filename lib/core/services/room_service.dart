import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/rooms/model/room_models.dart';
import '../../features/rooms/repositories/rooms_repository.dart';
import '../../features/search/model/song_model.dart';
import '../network/api_exception.dart';
import 'music_player_service.dart';

/// What the room needs from the player. Wraps [MusicPlayerService]; tests use a fake.
abstract class RoomPlayer implements Listenable {
  SongModel? get currentSong;
  bool get isPlaying;

  /// True while moving on because the previous song ended.
  bool get isAutoAdvancing;

  /// Starts [song] from the top; never toggles pause.
  Future<void> playRoomSong(SongModel song);

  /// Keeps the foreground service (and polling) alive in a room, even when idle.
  void setRoomKeepAlive(bool active);
}

class _MusicPlayerAdapter implements RoomPlayer {
  final MusicPlayerService _player = MusicPlayerService();

  @override
  SongModel? get currentSong => _player.currentSong;

  @override
  bool get isPlaying => _player.isPlaying;

  @override
  bool get isAutoAdvancing => _player.isAutoAdvancing;

  @override
  Future<void> playRoomSong(SongModel song) =>
      _player.playSong(song, queue: <SongModel>[song]);

  @override
  void setRoomKeepAlive(bool active) => _player.setRoomKeepAlive(active);

  @override
  void addListener(VoidCallback listener) => _player.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _player.removeListener(listener);
}

/// Listening rooms: up to 3 friends hear the same song. Only song changes are shared
/// (pause and seek stay local). Polls `/rooms/current` every 2s, screen off included.
class RoomService extends ChangeNotifier {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;

  static const Duration inRoomPollInterval = Duration(seconds: 2);
  static const Duration idlePollInterval = Duration(seconds: 20);

  final RoomsRepository _repository;
  final RoomPlayer Function() _playerFactory;
  final Duration _inRoomInterval;
  final Duration _idleInterval;

  RoomService._internal({RoomsRepository? repository})
      : _repository = repository ?? RoomsRepository(),
        _playerFactory = (() => _MusicPlayerAdapter()),
        _inRoomInterval = inRoomPollInterval,
        _idleInterval = idlePollInterval;

  @visibleForTesting
  RoomService.test(
    this._repository,
    RoomPlayer player, {
    Duration inRoomInterval = inRoomPollInterval,
    Duration idleInterval = idlePollInterval,
  })  : _playerFactory = (() => player),
        _inRoomInterval = inRoomInterval,
        _idleInterval = idleInterval;

  RoomPlayer? _playerInstance;
  RoomPlayer get _player => _playerInstance ??= _playerFactory();

  RoomModel? _room;
  List<RoomInviteModel> _invites = [];
  String? _notice;

  bool _started = false;
  bool _appInForeground = true;
  bool _polling = false;
  Timer? _timer;

  /// Highest room song_seq this phone has already acted on.
  int _appliedSeq = 0;
  String? _lastPlayerSongId;
  bool _listeningToPlayer = false;

  RoomModel? get room => _room;
  bool get inRoom => _room != null;
  List<RoomInviteModel> get invites => List.unmodifiable(_invites);

  /// One-shot message for the UI, e.g. "The room has ended". Reading it clears it.
  String? takeNotice() {
    final String? value = _notice;
    _notice = null;
    return value;
  }

  // polling
  /// Begin polling. Safe to call repeatedly.
  void start() {
    if (_started) return;
    _started = true;
    poll().whenComplete(_schedule);
  }

  /// Without a room the app only polls (for invites) in the foreground; inside a room it always polls.
  void setAppForeground(bool foreground) {
    _appInForeground = foreground;
    if (_started) {
      if (foreground && !inRoom) poll().whenComplete(_schedule);
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_started) return;
    final Duration? interval =
        inRoom ? _inRoomInterval : (_appInForeground ? _idleInterval : null);
    if (interval == null) return;
    _timer = Timer(interval, () async {
      await poll();
      _schedule();
    });
  }

  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final CurrentRoomModel current = await _repository.getCurrent();
      _invites = current.invites;
      await _setRoom(current.room);
    } on ApiException catch (e) {
      // Signed out or token expired.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _setRoom(null, quiet: true);
      }
    } catch (_) {
      // Offline: keep the room, retry next tick.
    } finally {
      _polling = false;
    }
  }

  // actions
  /// Returns an error message, or `null` when the room was created.
  Future<String?> createRoom(List<String> usernames) async {
    try {
      final RoomModel room = await _repository.createRoom(usernames);
      _invites = [];
      await _setRoom(room);
      _schedule();
      // Share what is already playing.
      final SongModel? playing = _player.currentSong;
      if (playing != null && _player.isPlaying) {
        unawaited(_publish(playing, auto: false));
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not create the room. Check your connection.';
    }
  }

  Future<String?> invite(String username) async {
    final RoomModel? current = _room;
    if (current == null) return 'You are not in a room.';
    try {
      final RoomModel updated = await _repository.invite(current.id, username);
      await _setRoom(updated);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send the invite. Check your connection.';
    }
  }

  Future<String?> accept(RoomInviteModel invite) async {
    try {
      final RoomModel room = await _repository.accept(invite.roomId);
      _invites = [];
      await _setRoom(room);
      _schedule();
      return null;
    } on ApiException catch (e) {
      _invites = _invites.where((i) => i.roomId != invite.roomId).toList();
      notifyListeners();
      return e.message;
    } catch (_) {
      return 'Could not join the room. Check your connection.';
    }
  }

  Future<void> decline(RoomInviteModel invite) async {
    _invites = _invites.where((i) => i.roomId != invite.roomId).toList();
    notifyListeners();
    try {
      await _repository.decline(invite.roomId);
    } catch (_) {}
  }

  /// Leaves the room (best effort on the network) and stops syncing.
  Future<void> leave() async {
    final RoomModel? current = _room;
    if (current == null) return;
    await _setRoom(null, quiet: true);
    _schedule();
    try {
      await _repository.leave(current.id);
    } catch (_) {
      // The server drops silent members anyway.
    }
  }

  /// Local-only reset, e.g. after logout (call [leave] first while still signed in).
  void reset() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _setRoomSync(null, quiet: true);
    _invites = [];
    notifyListeners();
  }

  // syncing
  Future<void> _setRoom(RoomModel? next, {bool quiet = false}) async {
    final RoomModel? prev = _room;

    // A slow poll can land after our publish; never go back to an older song.
    if (prev != null && next != null && prev.id == next.id && next.songSeq < prev.songSeq) {
      return;
    }

    _setRoomSync(next, quiet: quiet || (prev == null && next == null));
    if (next != null && next.songSeq > _appliedSeq) {
      await _applyRemote(next);
    }
    notifyListeners();
  }

  void _setRoomSync(RoomModel? next, {bool quiet = false}) {
    final RoomModel? prev = _room;
    _room = next;

    if (prev == null && next != null) {
      // Joined: pick up the room's current song.
      _appliedSeq = 0;
      _lastPlayerSongId = _player.currentSong?.id;
      _player.setRoomKeepAlive(true);
      if (!_listeningToPlayer) {
        _player.addListener(_onPlayerChanged);
        _listeningToPlayer = true;
      }
    } else if (prev != null && next == null) {
      if (_listeningToPlayer) {
        _player.removeListener(_onPlayerChanged);
        _listeningToPlayer = false;
      }
      _player.setRoomKeepAlive(false);
      _appliedSeq = 0;
      if (!quiet) _notice = 'The room has ended.';
    }
  }

  /// Another member changed the song: start it here too.
  Future<void> _applyRemote(RoomModel room) async {
    _appliedSeq = room.songSeq;
    final RoomSongModel? song = room.song;
    if (song == null) return;
    // Same song (maybe our own pick): never restart or toggle it.
    if (_player.currentSong?.id == song.songId) return;

    _lastPlayerSongId = song.songId; // so our own listener does not echo it back
    try {
      await _player.playRoomSong(song.toSongModel());
    } catch (_) {}
  }

  /// Runs on every player tick, so it only compares song ids.
  void _onPlayerChanged() {
    final SongModel? song = _player.currentSong;
    final String? id = song?.id;
    if (id == _lastPlayerSongId) return;
    _lastPlayerSongId = id;

    final RoomModel? room = _room;
    if (room == null || song == null || id == null || id.isEmpty) return;
    if (room.song?.songId == id) return; // the room is already on this song
    unawaited(_publish(song, auto: _player.isAutoAdvancing));
  }

  Future<void> _publish(SongModel song, {required bool auto}) async {
    final RoomModel? room = _room;
    if (room == null) return;
    try {
      final RoomSongResult result = await _repository.setSong(
        room.id,
        song,
        auto: auto,
        expectedSeq: room.songSeq,
      );
      if (result.applied) {
        // Our own song, so mark it handled instead of re-applying it.
        _appliedSeq = result.room.songSeq;
      }
      // Not applied: another phone moved on first, _setRoom adopts its song.
      await _setRoom(result.room);
    } catch (_) {
      // Offline: the song stays local.
    }
  }
}
