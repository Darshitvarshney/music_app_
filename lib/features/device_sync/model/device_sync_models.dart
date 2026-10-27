import '../../search/model/song_model.dart';

/// The song of the shared account-wide playback state.
class DeviceSyncSongModel {
  final Map<String, dynamic> _map;
  final String songId;
  final int durationSeconds;

  DeviceSyncSongModel._(this._map, this.songId, this.durationSeconds);

  factory DeviceSyncSongModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawDuration = map['duration'];
    final int seconds = rawDuration is int
        ? rawDuration
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;
    return DeviceSyncSongModel._(
      Map<String, dynamic>.from(map),
      map['song_id']?.toString() ?? '',
      seconds,
    );
  }

  /// Playable model for the local player (it resolves a fresh stream URL itself).
  SongModel toSongModel() => SongModel.fromMap(_map);
}

/// What this account is playing: the song, whether it is playing and where it is.
class DeviceSyncState {
  final int seq;
  final DeviceSyncSongModel? song;
  final bool isPlaying;

  /// Already moved forward to the moment the server answered.
  final int positionMs;
  final String? updatedByDeviceId;

  const DeviceSyncState({
    required this.seq,
    required this.isPlaying,
    required this.positionMs,
    this.song,
    this.updatedByDeviceId,
  });

  factory DeviceSyncState.fromMap(Map<String, dynamic> map) {
    final dynamic rawSong = map['song'];
    final dynamic rawSeq = map['seq'];
    final dynamic rawPosition = map['position_ms'];
    return DeviceSyncState(
      seq: rawSeq is int ? rawSeq : int.tryParse('$rawSeq') ?? 0,
      song: rawSong is Map<String, dynamic> ? DeviceSyncSongModel.fromMap(rawSong) : null,
      isPlaying: map['is_playing'] == true,
      positionMs: rawPosition is num ? rawPosition.toInt() : 0,
      updatedByDeviceId: map['updated_by_device_id']?.toString(),
    );
  }

  /// True when the song has played to its end and nothing moved on.
  bool get isEnded {
    final DeviceSyncSongModel? current = song;
    if (current == null || current.durationSeconds <= 0) return false;
    return !isPlaying && positionMs >= current.durationSeconds * 1000 - 2000;
  }
}

/// Response of PUT /device-sync/state. [applied] is false when nothing changed
/// (same state already stored, or another device advanced first).
class DeviceSyncPutResult {
  final bool applied;
  final DeviceSyncState state;

  const DeviceSyncPutResult({required this.applied, required this.state});
}
