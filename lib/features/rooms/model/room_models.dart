import '../../search/model/song_model.dart';

String? _optionalString(dynamic value) {
  if (value == null) return null;
  final String text = value.toString();
  return text.trim().isEmpty ? null : text;
}

/// The song currently shared with everyone in the room.
class RoomSongModel {
  final Map<String, dynamic> _map;
  final String songId;
  final String title;
  final String? artist;
  final String? imageUrl;

  RoomSongModel._(this._map, this.songId, this.title, this.artist, this.imageUrl);

  factory RoomSongModel.fromMap(Map<String, dynamic> map) {
    return RoomSongModel._(
      Map<String, dynamic>.from(map),
      map['song_id']?.toString() ?? '',
      map['title']?.toString() ?? 'Unknown Song',
      _optionalString(map['artist']),
      _optionalString(map['image_url']),
    );
  }

  /// Playable model for the local player (it resolves a fresh stream URL itself).
  SongModel toSongModel() => SongModel.fromMap(_map);
}

class RoomMemberModel {
  final String username;
  final String name;
  final bool isJoined;
  final bool online;
  final bool isMe;

  const RoomMemberModel({
    required this.username,
    required this.name,
    required this.isJoined,
    required this.online,
    required this.isMe,
  });

  factory RoomMemberModel.fromMap(Map<String, dynamic> map) {
    return RoomMemberModel(
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isJoined: map['status']?.toString() == 'joined',
      online: map['online'] == true,
      isMe: map['is_me'] == true,
    );
  }
}

class RoomModel {
  final String id;
  final int capacity;
  final int songSeq;
  final RoomSongModel? song;
  final String? songChangedBy;
  final List<RoomMemberModel> members;

  const RoomModel({
    required this.id,
    required this.capacity,
    required this.songSeq,
    required this.members,
    this.song,
    this.songChangedBy,
  });

  bool get isFull => members.length >= capacity;

  bool hasMember(String username) =>
      members.any((m) => m.username.toLowerCase() == username.toLowerCase());

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawSong = map['song'];
    final dynamic rawMembers = map['members'];
    final dynamic rawSeq = map['song_seq'];
    final dynamic rawCapacity = map['capacity'];
    return RoomModel(
      id: map['id']?.toString() ?? '',
      capacity: rawCapacity is int ? rawCapacity : 3,
      songSeq: rawSeq is int ? rawSeq : int.tryParse('$rawSeq') ?? 0,
      song: rawSong is Map<String, dynamic> ? RoomSongModel.fromMap(rawSong) : null,
      songChangedBy: _optionalString(map['song_changed_by']),
      members: rawMembers is List
          ? rawMembers
              .whereType<Map<String, dynamic>>()
              .map(RoomMemberModel.fromMap)
              .toList()
          : <RoomMemberModel>[],
    );
  }
}

class RoomInviteModel {
  final String roomId;
  final String invitedByName;
  final String invitedByUsername;
  final int memberCount;

  const RoomInviteModel({
    required this.roomId,
    required this.invitedByName,
    required this.invitedByUsername,
    required this.memberCount,
  });

  factory RoomInviteModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawCount = map['member_count'];
    return RoomInviteModel(
      roomId: map['room_id']?.toString() ?? '',
      invitedByName: map['invited_by_name']?.toString() ?? '',
      invitedByUsername: map['invited_by_username']?.toString() ?? '',
      memberCount: rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0,
    );
  }

  String get inviterLabel =>
      invitedByName.isNotEmpty ? invitedByName : (invitedByUsername.isNotEmpty ? invitedByUsername : 'A friend');
}

/// Response of GET /rooms/current: the user's room, or else their pending invites.
class CurrentRoomModel {
  final RoomModel? room;
  final List<RoomInviteModel> invites;

  const CurrentRoomModel({this.room, this.invites = const []});

  factory CurrentRoomModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawRoom = map['room'];
    final dynamic rawInvites = map['invites'];
    return CurrentRoomModel(
      room: rawRoom is Map<String, dynamic> ? RoomModel.fromMap(rawRoom) : null,
      invites: rawInvites is List
          ? rawInvites
              .whereType<Map<String, dynamic>>()
              .map(RoomInviteModel.fromMap)
              .toList()
          : <RoomInviteModel>[],
    );
  }
}

/// Response of PUT /rooms/{id}/song. [applied] is false when nothing changed
/// (same song already shared, or another phone moved the room on first).
class RoomSongResult {
  final bool applied;
  final RoomModel room;

  const RoomSongResult({required this.applied, required this.room});
}
