import '../../search/model/song_model.dart';

class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final int songCount;
  final List<String> coverImages;
  final DateTime? updatedAt;

  const PlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    this.songCount = 0,
    this.coverImages = const [],
    this.updatedAt,
  });

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawCount = map['song_count'];
    final dynamic rawCovers = map['cover_images'];
    return PlaylistModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled playlist',
      description: map['description']?.toString() ?? '',
      songCount: rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0,
      coverImages: rawCovers is List
          ? rawCovers
              .map((dynamic e) => e?.toString() ?? '')
              .where((String e) => e.isNotEmpty)
              .toList()
          : <String>[],
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  String get subtitle =>
      'Playlist • $songCount ${songCount == 1 ? 'song' : 'songs'}';
}

/// A playlist together with its songs in play order.
class PlaylistDetailModel {
  final PlaylistModel playlist;
  final List<SongModel> songs;

  const PlaylistDetailModel({required this.playlist, required this.songs});

  factory PlaylistDetailModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawSongs = map['songs'];
    return PlaylistDetailModel(
      playlist: PlaylistModel.fromMap(map),
      songs: rawSongs is List
          ? rawSongs
              .whereType<Map<String, dynamic>>()
              .map(SongModel.fromMap)
              .toList()
          : <SongModel>[],
    );
  }
}
