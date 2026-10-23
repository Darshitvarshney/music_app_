import 'dart:convert';

class SongModel {
  final String id;
  final String song;
  final String album;
  final String primaryArtists;
  final String singers;
  final int duration;
  final String image;
  final String mediaUrl;
  final String mediaPreviewUrl;
  final String year;
  final String language;
  final String permaUrl;
  final bool hasLyrics;
  final dynamic lyrics;

  const SongModel({
    required this.id,
    required this.song,
    required this.album,
    required this.primaryArtists,
    required this.singers,
    required this.duration,
    required this.image,
    required this.mediaUrl,
    required this.mediaPreviewUrl,
    required this.year,
    required this.language,
    this.permaUrl = '',
    required this.hasLyrics,
    this.lyrics,
  });

  String get displayArtist {
    if (primaryArtists.trim().isNotEmpty) {
      return primaryArtists.trim();
    }
    if (singers.trim().isNotEmpty) {
      return singers.trim();
    }
    return 'Unknown Artist';
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    int parsedDuration = 0;
    final rawDuration = map['duration'];
    if (rawDuration is int) {
      parsedDuration = rawDuration;
    } else if (rawDuration is String) {
      parsedDuration = int.tryParse(rawDuration) ?? 0;
    }

    return SongModel(
      id: (map['song_id'] ?? map['id'])?.toString() ?? '',
      song: (map['title'] ?? map['song'])?.toString() ?? 'Unknown Song',
      album: map['album']?.toString() ?? '',
      primaryArtists: (map['artist'] ?? map['primary_artists'])?.toString() ?? '',
      singers: map['singers']?.toString() ?? '',
      duration: parsedDuration,
      image: (map['image_url'] ?? map['image'])?.toString() ?? '',
      mediaUrl: map['media_url']?.toString() ?? '',
      mediaPreviewUrl: map['media_preview_url']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      permaUrl: map['perma_url']?.toString() ?? '',
      hasLyrics: map['has_lyrics']?.toString().toLowerCase() == 'true',
      lyrics: map['lyrics'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song': song,
      'album': album,
      'primary_artists': primaryArtists,
      'singers': singers,
      'duration': duration,
      'image': image,
      'media_url': mediaUrl,
      'media_preview_url': mediaPreviewUrl,
      'year': year,
      'language': language,
      'perma_url': permaUrl,
      'has_lyrics': hasLyrics,
      'lyrics': lyrics,
    };
  }

  Map<String, dynamic> toFavoritePayload() {
    return {
      'song_id': id,
      'perma_url': permaUrl.isNotEmpty
          ? permaUrl
          : 'https://www.jiosaavn.com/song/$id',
      'title': song,
      'artist': displayArtist,
      'album': album,
      'image_url': image,
      'duration': duration.toString(),
      'language': language,
      'year': year,
    };
  }

  SongModel copyWith({
    String? id,
    String? song,
    String? album,
    String? primaryArtists,
    String? singers,
    int? duration,
    String? image,
    String? mediaUrl,
    String? mediaPreviewUrl,
    String? year,
    String? language,
    String? permaUrl,
    bool? hasLyrics,
    dynamic lyrics,
  }) {
    return SongModel(
      id: id ?? this.id,
      song: song ?? this.song,
      album: album ?? this.album,
      primaryArtists: primaryArtists ?? this.primaryArtists,
      singers: singers ?? this.singers,
      duration: duration ?? this.duration,
      image: image ?? this.image,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaPreviewUrl: mediaPreviewUrl ?? this.mediaPreviewUrl,
      year: year ?? this.year,
      language: language ?? this.language,
      permaUrl: permaUrl ?? this.permaUrl,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SongModel.fromJson(String source) =>
      SongModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'SongModel(id: $id, song: $song, mediaUrl: $mediaUrl)';
}
