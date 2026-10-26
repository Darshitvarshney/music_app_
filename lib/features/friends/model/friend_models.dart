String? _optionalString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.trim().isEmpty ? null : text;
}

/// The song a friend is (or was last) playing, as returned by GET /friends/activity.
class FriendSongModel {
  final String songId;
  final String title;
  final String? artist;
  final String? album;
  final String? imageUrl;
  final String? permaUrl;

  const FriendSongModel({
    required this.songId,
    required this.title,
    this.artist,
    this.album,
    this.imageUrl,
    this.permaUrl,
  });

  factory FriendSongModel.fromMap(Map<String, dynamic> map) {
    return FriendSongModel(
      songId: map['song_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: _optionalString(map['artist']),
      album: _optionalString(map['album']),
      imageUrl: _optionalString(map['image_url']),
      permaUrl: _optionalString(map['perma_url']),
    );
  }
}

/// One friend's presence. [status] is listening | paused | recent | idle | online.
/// [online] drives the green circle; [song] is null when the friend hides it or has nothing recent.
class FriendActivityModel {
  final String username;
  final String name;
  final String status;
  final bool online;
  final FriendSongModel? song;
  final int? secondsAgo;

  const FriendActivityModel({
    required this.username,
    required this.name,
    required this.status,
    required this.online,
    this.song,
    this.secondsAgo,
  });

  bool get isListening => status == 'listening';

  factory FriendActivityModel.fromMap(Map<String, dynamic> map) {
    final rawSong = map['song'];
    final rawSeconds = map['seconds_ago'];
    return FriendActivityModel(
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'idle',
      online: map['online'] == true,
      song: rawSong is Map<String, dynamic> ? FriendSongModel.fromMap(rawSong) : null,
      secondsAgo: rawSeconds is num ? rawSeconds.toInt() : null,
    );
  }
}

/// A pending friend request.
class FriendRequestModel {
  final String id;
  final String username;
  final String name;

  const FriendRequestModel({
    required this.id,
    required this.username,
    required this.name,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> map) {
    return FriendRequestModel(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}

class FriendRequestsModel {
  final List<FriendRequestModel> incoming;
  final List<FriendRequestModel> outgoing;

  const FriendRequestsModel({required this.incoming, required this.outgoing});

  factory FriendRequestsModel.fromMap(Map<String, dynamic> map) {
    List<FriendRequestModel> parse(dynamic raw) {
      if (raw is! List) return <FriendRequestModel>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => FriendRequestModel.fromMap(m))
          .where((r) => r.id.isNotEmpty)
          .toList();
    }

    return FriendRequestsModel(
      incoming: parse(map['incoming']),
      outgoing: parse(map['outgoing']),
    );
  }
}

/// Answer to sending / accepting a request. [status] is pending | accepted | none.
class FriendRequestResult {
  final String message;
  final String status;

  const FriendRequestResult({required this.message, required this.status});

  factory FriendRequestResult.fromMap(Map<String, dynamic> map) {
    return FriendRequestResult(
      message: map['message']?.toString() ?? '',
      status: map['status']?.toString() ?? 'none',
    );
  }
}
