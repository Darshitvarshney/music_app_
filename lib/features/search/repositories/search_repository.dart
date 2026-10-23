import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/song_model.dart';

class SearchRepository {
  final http.Client _client;

  SearchRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<SongModel>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final uri = Uri.parse(
      'https://song-api-nine.vercel.app/result/?query=${Uri.encodeComponent(trimmed)}&lyrics=true',
    );

    try {
      final response = await _client.get(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((map) => SongModel.fromMap(map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to search songs: $e');
    }
  }

  Future<SongModel?> fetchSongDetails(String queryOrPermaUrl) async {
    final trimmed = queryOrPermaUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://song-api-nine.vercel.app/song/?query=${Uri.encodeComponent(trimmed)}',
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] == null) {
          return SongModel.fromMap(decoded);
        } else if (decoded is List && decoded.isNotEmpty) {
          for (final item in decoded) {
            if (item is Map<String, dynamic> &&
                (item['media_url']?.toString().trim().isNotEmpty ?? false)) {
              return SongModel.fromMap(item);
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SongModel?> resolvePlayableSong(SongModel song) async {
    if (song.mediaUrl.trim().isNotEmpty) {
      return song;
    }

    // 1. Try perma_url if it looks like a valid canonical JioSaavn link with slug
    final perma = song.permaUrl.trim();
    if (perma.startsWith('http') &&
        perma.contains('/song/') &&
        !perma.endsWith('/${song.id}')) {
      final fromPerma = await fetchSongDetails(perma);
      if (fromPerma != null && fromPerma.mediaUrl.trim().isNotEmpty) {
        return fromPerma;
      }
    }

    // 2. Search using "${song.song} ${song.displayArtist}" via /result/?query=...
    final artistClean = (song.displayArtist.isEmpty || song.displayArtist == 'Unknown Artist')
        ? ''
        : song.displayArtist;
    final searchTerms = [
      if (artistClean.isNotEmpty) '${song.song} $artistClean',
      song.song,
    ];

    for (final term in searchTerms) {
      final results = await searchSongs(term);
      if (results.isNotEmpty) {
        // Try exact match on ID first
        final exactMatch = results.firstWhere(
          (s) => s.id == song.id && s.mediaUrl.trim().isNotEmpty,
          orElse: () => results.firstWhere(
            (s) => s.mediaUrl.trim().isNotEmpty,
            orElse: () => results.first,
          ),
        );
        if (exactMatch.mediaUrl.trim().isNotEmpty) {
          return exactMatch;
        }
      }
    }

    return null;
  }
}
