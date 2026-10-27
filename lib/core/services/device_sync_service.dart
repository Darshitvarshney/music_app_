import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/device_sync/model/device_sync_models.dart';
import '../../features/device_sync/repositories/device_sync_repository.dart';
import '../../features/search/model/song_model.dart';
import '../network/api_exception.dart';
import 'music_player_service.dart';
import 'room_service.dart';

/// What device sync needs from the player. Wraps [MusicPlayerService]; tests use a fake.
abstract class SyncPlayer implements Listenable {
  SongModel? get currentSong;
  bool get isPlaying;
  bool get isBuffering;

  /// True while moving on because the previous song ended.
  bool get isAutoAdvancing;
  Duration get position;

  /// Puts the player on [song] at [position] (read late, after loading) without toggling it.
  Future<void> applySyncedState(
    SongModel song, {
    required bool playing,
    required Duration Function() position,
  });

  /// Keeps the foreground service (and polling) alive when nothing is playing.
  void setKeepAlive(bool active);
}

class _MusicPlayerAdapter implements SyncPlayer {
  final MusicPlayerService _player = MusicPlayerService();

  @override
  SongModel? get currentSong => _player.currentSong;

  @override
  bool get isPlaying => _player.isPlaying;

  @override
  bool get isBuffering => _player.isBuffering;

  @override
  bool get isAutoAdvancing => _player.isAutoAdvancing;

  @override
  Duration get position => _player.position;

  @override
  Future<void> applySyncedState(
    SongModel song, {
    required bool playing,
    required Duration Function() position,
  }) =>
      _player.applySyncedState(song, playing: playing, position: position);

  @override
  void setKeepAlive(bool active) => _player.setDeviceSyncKeepAlive(active);

  @override
  void addListener(VoidCallback listener) => _player.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _player.removeListener(listener);
}

/// Keeps one account's devices in step: song, pause/resume and position.
/// Every device reports its own changes; devices with sync on poll and follow.
class DeviceSyncService extends ChangeNotifier {
  static final DeviceSyncService _instance = DeviceSyncService._internal();
  factory DeviceSyncService() => _instance;

  /// Polling speed while something is playing or changed lately (app in the foreground).
  static const Duration defaultPollInterval = Duration(seconds: 2);

  /// Slower while the app is in the background, and when everything has been idle.
  static const Duration defaultBackgroundInterval = Duration(seconds: 4);
  static const Duration defaultIdleInterval = Duration(seconds: 8);
  static const Duration _busyWindow = Duration(seconds: 60);
  static const Duration defaultDebounce = Duration(milliseconds: 400);

  /// A position jump bigger than this (playing or paused) counts as a seek.
  static const int seekThresholdMs = 1500;

  /// Followers re-seek when they drift further than this from the shared position.
  static const int driftThresholdMs = 800;
  static const Duration _applyDeadline = Duration(seconds: 20);
  static const Duration _applyMismatchGrace = Duration(milliseconds: 800);
  static const Duration _quietAfterApply = Duration(milliseconds: 1500);

  final DeviceSyncRepository _repository;
  final DeviceSyncStore _store;
  final SyncPlayer Function() _playerFactory;
  final bool Function() _isBlocked;
  final DateTime Function() _now;
  final Duration _pollInterval;
  final Duration _backgroundInterval;
  final Duration _idleInterval;
  final Duration _debounce;

  DeviceSyncService._internal()
      : _repository = DeviceSyncRepository(),
        _store = DeviceSyncStore(),
        _playerFactory = (() => _MusicPlayerAdapter()),
        _isBlocked = (() => RoomService().inRoom),
        _now = DateTime.now,
        _pollInterval = defaultPollInterval,
        _backgroundInterval = defaultBackgroundInterval,
        _idleInterval = defaultIdleInterval,
        _debounce = defaultDebounce;

  @visibleForTesting
  DeviceSyncService.test(
    this._repository,
    this._store,
    SyncPlayer player, {
    bool Function()? isBlocked,
    DateTime Function()? now,
    Duration pollInterval = defaultPollInterval,
    Duration backgroundInterval = defaultBackgroundInterval,
    Duration idleInterval = defaultIdleInterval,
    Duration debounce = defaultDebounce,
  })  : _playerFactory = (() => player),
        _isBlocked = (isBlocked ?? (() => false)),
        _now = (now ?? DateTime.now),
        _pollInterval = pollInterval,
        _backgroundInterval = backgroundInterval,
        _idleInterval = idleInterval,
        _debounce = debounce;

  SyncPlayer? _playerInstance;
  SyncPlayer get _player => _playerInstance ??= _playerFactory();

  String? _deviceId;
  bool _enabled = false;
  bool _attached = false;
  bool _following = false;
  bool _connected = true;
  bool _polling = false;
  bool _adoptFirst = false;
  bool _inForeground = true;
  bool _serverPlaying = false;
  DateTime? _lastActivityAt;
  Timer? _pollTimer;

  /// Highest server seq this device has acted on.
  int _appliedSeq = 0;
  int _rttMs = 200;

  // Local changes to report
  String? _lastSongId;
  bool _lastPlaying = false;
  int _basePosMs = 0;
  DateTime? _baseAt;
  bool _rebaseOnNextTick = false;
  DateTime? _quietUntil;
  Timer? _debounceTimer;
  bool _publishAuto = false;
  bool _publishing = false;
  bool _publishAgain = false;

  // A remote state being applied: the player is not reported while it settles
  String? _applyId;
  bool _applyPlaying = false;
  DateTime? _applyStartedAt;
  Timer? _applyTimer;

  /// The Sync switch on the home screen.
  bool get enabled => _enabled;

  /// False while the server cannot be reached.
  bool get connected => _connected;

  bool get _publishPending => (_debounceTimer?.isActive ?? false) || _publishing;

  /// Starts reporting this device's playback and, if sync was left on, following. Safe to call repeatedly.
  Future<void> start() async {
    if (_attached) return;
    _attached = true;
    _player.addListener(_onPlayerChanged);
    _lastSongId = _player.currentSong?.id;
    _lastPlaying = _player.isPlaying;
    _rebaseline();
    _deviceId ??= await _store.getDeviceId();
    final bool saved = await _store.isEnabled();
    if (!_attached) return;
    _enabled = saved;
    if (_enabled && !_following) _beginFollowing();
    notifyListeners();
  }

  /// Stops watching and polling, keeping the saved on/off choice.
  void stop() {
    _playerInstance?.removeListener(_onPlayerChanged);
    _attached = false;
    _endFollowing();
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _endApply(settled: false);
  }

  /// After logout: stops everything and switches sync off for the next account.
  void reset() {
    stop();
    _enabled = false;
    _appliedSeq = 0;
    unawaited(_store.setEnabled(false));
    notifyListeners();
  }

  /// Returns a message when sync could not be switched on, else `null`.
  Future<String?> setEnabled(bool on) async {
    if (on) {
      if (_isBlocked()) return 'Leave your listening room first to sync your devices.';
      if (!_attached) await start();
    }
    _enabled = on;
    await _store.setEnabled(on);
    if (on && !_following) {
      _beginFollowing();
    } else if (!on) {
      _endFollowing();
    }
    notifyListeners();
    return null;
  }

  /// Catches up right away when the app comes back to the foreground.
  void setAppForeground(bool foreground) {
    _inForeground = foreground;
    if (!_following) return;
    if (foreground) {
      poll().whenComplete(_schedule);
    } else {
      _schedule();
    }
  }

  void _markActivity() {
    _lastActivityAt = _now();
  }

  /// Fast while something plays or changed in the last minute, slow when idle, to save requests.
  Duration _nextInterval() {
    final DateTime? last = _lastActivityAt;
    final bool recent = last != null && _now().difference(last) < _busyWindow;
    final bool busy = _serverPlaying || recent || (_playerInstance?.isPlaying ?? false);
    if (!busy) return _idleInterval;
    return _inForeground ? _pollInterval : _backgroundInterval;
  }

  // following
  void _beginFollowing() {
    _following = true;
    _appliedSeq = 0;
    _adoptFirst = true;
    _connected = true;
    _markActivity();
    _player.setKeepAlive(true);
    poll().whenComplete(_schedule);
  }

  void _endFollowing() {
    _following = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _playerInstance?.setKeepAlive(false);
  }

  void _schedule() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_following) return;
    _pollTimer = Timer(_nextInterval(), () async {
      await poll();
      _schedule();
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    notifyListeners();
  }

  Future<void> poll() async {
    if (!_following || _polling || _isBlocked()) return;
    _polling = true;
    try {
      final DateTime sentAt = _now();
      final DeviceSyncState state = await _repository.getState();
      final DateTime receivedAt = _now();
      _rttMs = receivedAt.difference(sentAt).inMilliseconds.clamp(0, 5000).toInt();
      _setConnected(true);
      await _onServerState(state, receivedAt);
    } on ApiException catch (e) {
      // Signed out or token expired: stop until the app restarts.
      if (e.statusCode == 401 || e.statusCode == 403) {
        _endFollowing();
      } else {
        _setConnected(false);
      }
    } catch (_) {
      _setConnected(false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _onServerState(DeviceSyncState state, DateTime receivedAt) async {
    if (!_following) return;
    if (state.seq < _appliedSeq) return;
    // Our own newer change is on its way, and the latest report wins.
    if (_publishPending) return;

    final bool first = _adoptFirst;
    _adoptFirst = false;
    final bool isNew = state.seq > _appliedSeq;
    final bool fromMe = state.updatedByDeviceId != null && state.updatedByDeviceId == _deviceId;
    _appliedSeq = state.seq;
    _serverPlaying = state.isPlaying;
    if (isNew) _markActivity();

    if (first) {
      _adoptOnEnable(state, receivedAt, fromMe);
      return;
    }
    if (state.song == null || fromMe) return;
    if (isNew) {
      _applyRemote(state, receivedAt);
    } else {
      _correctDrift(state, receivedAt);
    }
  }

  /// First state after switching on: follow what the account is playing, unless
  /// only this device is playing, in which case it becomes the source.
  void _adoptOnEnable(DeviceSyncState state, DateTime receivedAt, bool fromMe) {
    final bool localPlaying = _player.currentSong != null && _player.isPlaying;
    if (state.song == null || fromMe) {
      if (localPlaying) _schedulePublish(auto: false);
      return;
    }
    if (state.isPlaying || (!localPlaying && !state.isEnded)) {
      _applyRemote(state, receivedAt);
    } else if (localPlaying) {
      _schedulePublish(auto: false);
    }
  }

  /// Same song and same seq, but this device slid away from the shared position.
  void _correctDrift(DeviceSyncState state, DateTime receivedAt) {
    final DeviceSyncSongModel? remoteSong = state.song;
    final SongModel? local = _player.currentSong;
    if (remoteSong == null || local == null || !state.isPlaying) return;
    if (_applyId != null || _publishPending) return;
    if (local.id != remoteSong.songId || !_player.isPlaying || _player.isBuffering) return;

    final int expected =
        state.positionMs + _now().difference(receivedAt).inMilliseconds + _rttMs ~/ 2;
    final int limit = remoteSong.durationSeconds * 1000;
    if (limit > 0 && expected > limit) return;
    final int driftMs = (_player.position.inMilliseconds - expected).abs();
    if (driftMs < driftThresholdMs) return;
    _applyRemote(state, receivedAt);
  }

  /// Another device changed something: copy it here without reporting it back.
  void _applyRemote(DeviceSyncState state, DateTime receivedAt) {
    final DeviceSyncSongModel? remoteSong = state.song;
    if (remoteSong == null || remoteSong.songId.isEmpty) return;
    final bool playing = state.isPlaying;
    final int halfRtt = _rttMs ~/ 2;
    final int limit = remoteSong.durationSeconds * 1000;

    Duration target() {
      int ms = state.positionMs;
      if (playing) ms += _now().difference(receivedAt).inMilliseconds + halfRtt;
      if (limit > 0 && ms > limit) ms = limit;
      return Duration(milliseconds: ms < 0 ? 0 : ms);
    }

    _beginApply(remoteSong.songId, playing);
    unawaited(_runApply(remoteSong.toSongModel(), playing, target));
  }

  Future<void> _runApply(SongModel song, bool playing, Duration Function() target) async {
    try {
      await _player.applySyncedState(song, playing: playing, position: target);
    } catch (_) {
      // The player could not load it; the next poll tries again.
    }
  }

  // applying a remote state
  void _beginApply(String songId, bool playing) {
    _applyId = songId;
    _applyPlaying = playing;
    _applyStartedAt = _now();
    _applyTimer?.cancel();
    _applyTimer = Timer.periodic(const Duration(milliseconds: 400), (_) => _checkSettle());
  }

  void _checkSettle() {
    final String? target = _applyId;
    if (target == null) return;
    final SyncPlayer player = _player;
    final Duration age = _now().difference(_applyStartedAt ?? _now());
    if (player.currentSong?.id != target) {
      // The user picked something else meanwhile: that is a real change to report.
      _endApply(settled: false);
      return;
    }
    if (player.isBuffering) {
      if (age > _applyDeadline) _endApply(settled: true);
      return;
    }
    if (player.isPlaying == _applyPlaying || age > _applyMismatchGrace) {
      _endApply(settled: true);
    }
  }

  void _endApply({required bool settled}) {
    _applyTimer?.cancel();
    _applyTimer = null;
    _applyId = null;
    _applyStartedAt = null;
    if (!settled || !_attached) return;
    final SyncPlayer player = _player;
    _lastSongId = player.currentSong?.id;
    _lastPlaying = player.isPlaying;
    _rebaseline();
    _rebaseOnNextTick = false;
    _quietUntil = _now().add(_quietAfterApply);
  }

  // reporting local changes
  void _rebaseline() {
    _basePosMs = _playerInstance?.position.inMilliseconds ?? 0;
    _baseAt = _now();
  }

  int _expectedPositionMs() {
    final DateTime? at = _baseAt;
    if (at == null || !_lastPlaying) return _basePosMs;
    return _basePosMs + _now().difference(at).inMilliseconds;
  }

  bool _endedNaturally(SongModel? song, int expectedMs) {
    if (song == null || song.duration <= 0) return false;
    return expectedMs >= song.duration * 1000 - 2500;
  }

  /// Runs on every player tick, so it only compares a few values.
  void _onPlayerChanged() {
    if (!_attached) return;
    final SyncPlayer player = _player;

    if (_applyId != null) {
      _checkSettle();
      if (_applyId != null) return;
    }
    if (player.isBuffering) {
      _rebaseOnNextTick = true;
      return;
    }

    final SongModel? song = player.currentSong;
    final String? id = song?.id;
    final bool playing = player.isPlaying;

    // In a listening room the room decides what plays.
    if (_isBlocked()) {
      _lastSongId = id;
      _lastPlaying = playing;
      _rebaseline();
      return;
    }

    if (id != _lastSongId || playing != _lastPlaying) {
      final String? previousId = _lastSongId;
      final int expected = _expectedPositionMs();
      final bool wasPlaying = _lastPlaying;
      _lastSongId = id;
      _lastPlaying = playing;
      _rebaseline();
      _rebaseOnNextTick = false;
      if (_following) {
        _markActivity();
        _schedule(); // leave the slow idle rhythm right away
      }
      if (id == null || id.isEmpty) return;
      final bool songChanged = id != previousId;
      // A restored or failed song that is not playing is not worth sharing.
      if (songChanged && !playing) return;
      // The song ran out; whatever comes next is reported on its own.
      if (!songChanged && wasPlaying && !playing && _endedNaturally(song, expected)) return;
      _schedulePublish(auto: player.isAutoAdvancing);
      return;
    }

    if (_rebaseOnNextTick) {
      _rebaseOnNextTick = false;
      _rebaseline();
      return;
    }
    final DateTime? quiet = _quietUntil;
    if (quiet != null && _now().isBefore(quiet)) {
      _rebaseline();
      return;
    }
    final int driftMs = (player.position.inMilliseconds - _expectedPositionMs()).abs();
    if (driftMs > seekThresholdMs) {
      _rebaseline();
      _schedulePublish(auto: false);
    }
  }

  void _schedulePublish({required bool auto}) {
    _publishAuto = auto;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_publish()));
  }

  Future<void> _publish() async {
    if (!_attached) return;
    if (_publishing) {
      _publishAgain = true;
      return;
    }
    final SongModel? song = _player.currentSong;
    if (song == null || song.id.isEmpty) return;

    _publishing = true;
    final bool auto = _publishAuto;
    try {
      final String deviceId = _deviceId ??= await _store.getDeviceId();
      final bool playing = _player.isPlaying;
      int positionMs = _player.position.inMilliseconds;
      if (playing) positionMs += _rttMs ~/ 2;

      final DateTime sentAt = _now();
      final DeviceSyncPutResult result = await _repository.putState(
        deviceId: deviceId,
        song: song,
        isPlaying: playing,
        positionMs: positionMs,
        auto: auto,
        // Only a device that polls knows the latest seq.
        expectedSeq: (auto && _following) ? _appliedSeq : null,
      );
      _rttMs = _now().difference(sentAt).inMilliseconds.clamp(0, 5000).toInt();

      final DeviceSyncState state = result.state;
      final bool behind = state.seq > _appliedSeq;
      if (behind) _appliedSeq = state.seq;
      // Not applied and another device moved first: follow it.
      if (!result.applied &&
          behind &&
          _following &&
          state.song != null &&
          state.updatedByDeviceId != deviceId) {
        _applyRemote(state, _now());
      }
    } catch (_) {
      // Offline: the change stays local and the next one is reported.
    } finally {
      _publishing = false;
      if (_publishAgain) {
        _publishAgain = false;
        unawaited(_publish());
      }
    }
  }
}
