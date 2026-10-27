/// A song read from another service, before it is matched to our catalog.
class ImportTrack {
  final String title;
  final String? artist;

  const ImportTrack({required this.title, this.artist});

  factory ImportTrack.fromMap(Map<String, dynamic> map) {
    final String artist = map['artist']?.toString().trim() ?? '';
    return ImportTrack(
      title: map['title']?.toString() ?? '',
      artist: artist.isEmpty ? null : artist,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        if (artist != null) 'artist': artist,
      };

  String get label => artist == null ? title : '$title • $artist';
}

/// One page of songs from a playlist or file; [title] is only set on the first page.
class SourcePageModel {
  final String playlistId;
  final String? title;
  final int total;
  final List<ImportTrack> tracks;
  final String? nextPageToken;

  const SourcePageModel({
    required this.playlistId,
    required this.title,
    required this.total,
    required this.tracks,
    required this.nextPageToken,
  });

  factory SourcePageModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawTracks = map['tracks'];
    final dynamic rawTotal = map['total'];
    final String token = map['next_page_token']?.toString() ?? '';
    return SourcePageModel(
      playlistId: map['playlist_id']?.toString() ?? '',
      title: map['title']?.toString(),
      total: rawTotal is int ? rawTotal : int.tryParse('$rawTotal') ?? 0,
      tracks: rawTracks is List
          ? rawTracks
              .whereType<Map<String, dynamic>>()
              .map(ImportTrack.fromMap)
              .where((ImportTrack t) => t.title.isNotEmpty)
              .toList()
          : <ImportTrack>[],
      nextPageToken: token.isEmpty ? null : token,
    );
  }
}

/// One of the signed-in user's own YouTube playlists.
class MyPlaylistModel {
  final String id;
  final String title;
  final int count;

  const MyPlaylistModel({
    required this.id,
    required this.title,
    required this.count,
  });

  factory MyPlaylistModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawCount = map['count'];
    return MyPlaylistModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled playlist',
      count: rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0,
    );
  }
}

class MyPlaylistsPageModel {
  final List<MyPlaylistModel> items;
  final String? nextPageToken;

  const MyPlaylistsPageModel({required this.items, required this.nextPageToken});

  factory MyPlaylistsPageModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawItems = map['items'];
    final String token = map['next_page_token']?.toString() ?? '';
    return MyPlaylistsPageModel(
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(MyPlaylistModel.fromMap)
              .where((MyPlaylistModel p) => p.id.isNotEmpty)
              .toList()
          : <MyPlaylistModel>[],
      nextPageToken: token.isEmpty ? null : token,
    );
  }
}
