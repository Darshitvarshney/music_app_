import 'dart:convert';
import '../../features/search/model/song_model.dart';

/// Playback eligibility and DRM status evaluated by the recommendation engine
class PlaybackEligibilityModel {
  final bool isEligible;
  final String reason;
  final String? playbackUrl;
  final bool isDrm;
  final bool isPreview;

  const PlaybackEligibilityModel({
    required this.isEligible,
    required this.reason,
    this.playbackUrl,
    required this.isDrm,
    required this.isPreview,
  });

  factory PlaybackEligibilityModel.fromMap(Map<String, dynamic> map) {
    return PlaybackEligibilityModel(
      isEligible: map['isEligible'] == true,
      reason: map['reason']?.toString() ?? 'UNKNOWN',
      playbackUrl: map['playbackUrl']?.toString(),
      isDrm: map['isDrm'] == true,
      isPreview: map['isPreview'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEligible': isEligible,
      'reason': reason,
      'playbackUrl': playbackUrl,
      'isDrm': isDrm,
      'isPreview': isPreview,
    };
  }
}

/// Recommended Song Model returned by POST /api/recommend
class RecommendedSongModel {
  final String id;
  final String song;
  final String album;
  final String primaryArtists;
  final String singers;
  final int duration;
  final String image;
  final String mediaUrl;
  final String mediaPreviewUrl;
  final String language;
  final String year;
  final double recommendationScore;
  final String explanation;
  final List<String> matchingGenres;
  final List<String> matchingMoods;
  final PlaybackEligibilityModel playbackEligibility;
  final double metadataConfidence;

  const RecommendedSongModel({
    required this.id,
    required this.song,
    required this.album,
    required this.primaryArtists,
    required this.singers,
    required this.duration,
    required this.image,
    required this.mediaUrl,
    required this.mediaPreviewUrl,
    required this.language,
    required this.year,
    required this.recommendationScore,
    required this.explanation,
    required this.matchingGenres,
    required this.matchingMoods,
    required this.playbackEligibility,
    required this.metadataConfidence,
  });

  String get displayArtist {
    if (primaryArtists.trim().isNotEmpty) return primaryArtists.trim();
    if (singers.trim().isNotEmpty) return singers.trim();
    return 'Unknown Artist';
  }

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory RecommendedSongModel.fromMap(Map<String, dynamic> map) {
    final eligibilityMap = map['playbackEligibility'] is Map<String, dynamic>
        ? map['playbackEligibility'] as Map<String, dynamic>
        : <String, dynamic>{};

    return RecommendedSongModel(
      id: map['id']?.toString() ?? '',
      song: map['song']?.toString() ?? map['title']?.toString() ?? 'Unknown Song',
      album: map['album']?.toString() ?? '',
      primaryArtists: map['primary_artists']?.toString() ?? map['artist']?.toString() ?? '',
      singers: map['singers']?.toString() ?? '',
      duration: (map['duration'] is num) ? (map['duration'] as num).toInt() : (int.tryParse(map['duration']?.toString() ?? '0') ?? 0),
      image: map['image']?.toString() ?? '',
      mediaUrl: map['media_url']?.toString() ?? map['mediaUrl']?.toString() ?? eligibilityMap['playbackUrl']?.toString() ?? '',
      mediaPreviewUrl: map['media_preview_url']?.toString() ?? map['mediaPreviewUrl']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      recommendationScore: (map['recommendationScore'] is num) ? (map['recommendationScore'] as num).toDouble() : 0.0,
      explanation: map['explanation']?.toString() ?? 'Recommended for you',
      matchingGenres: (map['matchingGenres'] is List)
          ? (map['matchingGenres'] as List).map((e) => e.toString()).toList()
          : (map['matchingGenres'] is String && (map['matchingGenres'] as String).isNotEmpty)
              ? (map['matchingGenres'] as String).split(RegExp(r'[, ]+')).where((s) => s.isNotEmpty).toList()
              : [],
      matchingMoods: (map['matchingMoods'] is List)
          ? (map['matchingMoods'] as List).map((e) => e.toString()).toList()
          : (map['matchingMoods'] is String && (map['matchingMoods'] as String).isNotEmpty)
              ? (map['matchingMoods'] as String).split(RegExp(r'[, ]+')).where((s) => s.isNotEmpty).toList()
              : [],
      playbackEligibility: PlaybackEligibilityModel.fromMap(eligibilityMap),
      metadataConfidence: (map['metadataConfidence'] is num) ? (map['metadataConfidence'] as num).toDouble() : 0.8,
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
      'language': language,
      'year': year,
      'recommendationScore': recommendationScore,
      'explanation': explanation,
      'matchingGenres': matchingGenres,
      'matchingMoods': matchingMoods,
      'playbackEligibility': playbackEligibility.toMap(),
      'metadataConfidence': metadataConfidence,
    };
  }

  /// Converts recommended song to standard SongModel map for the Flutter audio player
  Map<String, dynamic> toPlayerSongMap() {
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
      'has_lyrics': false,
    };
  }

  SongModel toSongModel() => SongModel.fromMap(toPlayerSongMap());

  String toJson() => jsonEncode(toMap());
  factory RecommendedSongModel.fromJson(String source) =>
      RecommendedSongModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Recommendation Response Envelope
class RecommendationResponseModel {
  final String status;
  final String mode;
  final int totalCandidatesEvaluated;
  final int returnedCount;
  final List<RecommendedSongModel> recommendations;

  const RecommendationResponseModel({
    required this.status,
    required this.mode,
    required this.totalCandidatesEvaluated,
    required this.returnedCount,
    required this.recommendations,
  });

  factory RecommendationResponseModel.fromMap(Map<String, dynamic> map) {
    final list = (map['recommendations'] ?? map['similarSongs']) as List<dynamic>? ?? [];
    return RecommendationResponseModel(
      status: map['status']?.toString() ?? 'success',
      mode: map['mode']?.toString() ?? 'autoplay',
      totalCandidatesEvaluated: map['totalCandidatesEvaluated'] is int ? map['totalCandidatesEvaluated'] : 0,
      returnedCount: map['returnedCount'] is int ? map['returnedCount'] : list.length,
      recommendations: list
          .whereType<Map<String, dynamic>>()
          .map((m) => RecommendedSongModel.fromMap(m))
          .toList(),
    );
  }

  factory RecommendationResponseModel.fromJson(String source) =>
      RecommendationResponseModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Listening Event Model
class ListeningEventModel {
  final String userId;
  final String songId;
  final String eventType; // 'played' | 'completed' | 'skipped' | 'replayed'
  final int timestamp;
  final int duration;
  final Map<String, dynamic>? songMetadata;

  const ListeningEventModel({
    required this.userId,
    required this.songId,
    required this.eventType,
    required this.timestamp,
    this.duration = 0,
    this.songMetadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'songId': songId,
      'eventType': eventType,
      'timestamp': timestamp,
      'duration': duration,
      if (songMetadata != null) 'songMetadata': songMetadata,
    };
  }

  String toJson() => jsonEncode(toMap());
}

/// User Preference Profile Model
class UserPreferenceProfileModel {
  final String userId;
  final Map<String, double> genres;
  final Map<String, double> subgenres;
  final Map<String, double> moods;
  final Map<String, double> artists;
  final Map<String, double> languages;
  final int totalEvents;

  const UserPreferenceProfileModel({
    required this.userId,
    required this.genres,
    required this.subgenres,
    required this.moods,
    required this.artists,
    required this.languages,
    required this.totalEvents,
  });

  factory UserPreferenceProfileModel.fromMap(Map<String, dynamic> map) {
    Map<String, double> parseDoubleMap(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), (v is num) ? v.toDouble() : 0.0));
    }

    return UserPreferenceProfileModel(
      userId: map['userId']?.toString() ?? '',
      genres: parseDoubleMap(map['genres']),
      subgenres: parseDoubleMap(map['subgenres']),
      moods: parseDoubleMap(map['moods']),
      artists: parseDoubleMap(map['artists']),
      languages: parseDoubleMap(map['languages']),
      totalEvents: map['totalEvents'] is int ? map['totalEvents'] : 0,
    );
  }
}

/// Homepage Section Model returned by GET /api/homepage
class HomepageSectionModel {
  final String id;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? seedSong;
  final List<RecommendedSongModel> songs;

  const HomepageSectionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.seedSong,
    required this.songs,
  });

  factory HomepageSectionModel.fromMap(Map<String, dynamic> map) {
    final rawSongs = map['songs'] as List<dynamic>? ?? [];
    return HomepageSectionModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Recommended For You',
      subtitle: map['subtitle']?.toString() ?? '',
      seedSong: map['seedSong'] is Map<String, dynamic> ? map['seedSong'] as Map<String, dynamic> : null,
      songs: rawSongs
          .whereType<Map<String, dynamic>>()
          .map((s) => RecommendedSongModel.fromMap(s))
          .toList(),
    );
  }
}

/// Homepage Full Recommendation Response Model
class HomepageResponseModel {
  final String status;
  final String userId;
  final String source;
  final int favoritesCount;
  final List<Map<String, dynamic>> recentFavorites;
  final Map<String, List<String>> topTaste;
  final List<HomepageSectionModel> sections;

  const HomepageResponseModel({
    required this.status,
    required this.userId,
    required this.source,
    required this.favoritesCount,
    required this.recentFavorites,
    required this.topTaste,
    required this.sections,
  });

  factory HomepageResponseModel.fromMap(Map<String, dynamic> map) {
    final rawSections = map['sections'] as List<dynamic>? ?? [];
    final rawFavs = map['recentFavorites'] as List<dynamic>? ?? [];

    final topTasteMap = <String, List<String>>{};
    if (map['topTaste'] is Map<String, dynamic>) {
      final tt = map['topTaste'] as Map<String, dynamic>;
      if (tt['topGenres'] is List) {
        topTasteMap['topGenres'] = (tt['topGenres'] as List).map((e) => e.toString()).toList();
      }
      if (tt['topMoods'] is List) {
        topTasteMap['topMoods'] = (tt['topMoods'] as List).map((e) => e.toString()).toList();
      }
    }

    return HomepageResponseModel(
      status: map['status']?.toString() ?? 'success',
      userId: map['userId']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      favoritesCount: map['favoritesCount'] is int ? map['favoritesCount'] as int : 0,
      recentFavorites: rawFavs.whereType<Map<String, dynamic>>().toList(),
      topTaste: topTasteMap,
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map((sec) => HomepageSectionModel.fromMap(sec))
          .toList(),
    );
  }
}

/// One ranked entry of the Music DNA (e.g. "Bollywood" at 42%)
class MusicDnaItemModel {
  final String name;
  final int percent;

  const MusicDnaItemModel({required this.name, required this.percent});

  factory MusicDnaItemModel.fromMap(Map<String, dynamic> map) {
    final rawPercent = map['percent'];
    return MusicDnaItemModel(
      name: map['name']?.toString() ?? '',
      percent: rawPercent is num ? rawPercent.round() : 0,
    );
  }
}

/// "Your Music DNA" returned by GET /api/music-dna (generated once, cached for 1 day by the server)
class MusicDnaModel {
  final bool hasData;
  final String summary;
  final int totalEvents;
  final int favoritesCount;
  final List<MusicDnaItemModel> topGenres;
  final List<MusicDnaItemModel> topSubgenres;
  final List<MusicDnaItemModel> topMoods;
  final List<MusicDnaItemModel> topArtists;
  final List<MusicDnaItemModel> topLanguages;
  final DateTime? generatedAt;
  final DateTime? expiresAt;
  final bool cached;

  const MusicDnaModel({
    required this.hasData,
    required this.summary,
    required this.totalEvents,
    required this.favoritesCount,
    required this.topGenres,
    required this.topSubgenres,
    required this.topMoods,
    required this.topArtists,
    required this.topLanguages,
    this.generatedAt,
    this.expiresAt,
    this.cached = false,
  });

  factory MusicDnaModel.fromMap(Map<String, dynamic> map) {
    List<MusicDnaItemModel> parseItems(dynamic raw) {
      if (raw is! List) return <MusicDnaItemModel>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => MusicDnaItemModel.fromMap(m))
          .where((item) => item.name.isNotEmpty)
          .toList();
    }

    return MusicDnaModel(
      hasData: map['hasData'] == true,
      summary: map['summary']?.toString() ?? '',
      totalEvents: map['totalEvents'] is num ? (map['totalEvents'] as num).toInt() : 0,
      favoritesCount: map['favoritesCount'] is num ? (map['favoritesCount'] as num).toInt() : 0,
      topGenres: parseItems(map['topGenres']),
      topSubgenres: parseItems(map['topSubgenres']),
      topMoods: parseItems(map['topMoods']),
      topArtists: parseItems(map['topArtists']),
      topLanguages: parseItems(map['topLanguages']),
      generatedAt: DateTime.tryParse(map['generatedAt']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? ''),
      cached: map['cached'] == true,
    );
  }
}
