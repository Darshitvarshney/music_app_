import '../../search/model/song_model.dart';

class FavoritesPageResult {
  final int total;
  final int page;
  final int limit;
  final List<SongModel> items;

  const FavoritesPageResult({
    required this.total,
    required this.page,
    required this.limit,
    required this.items,
  });

  factory FavoritesPageResult.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    List<SongModel> songs = [];
    if (rawItems is List) {
      songs = rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => SongModel.fromMap(item))
          .toList();
    }

    return FavoritesPageResult(
      total: (map['total'] as num?)?.toInt() ?? songs.length,
      page: (map['page'] as num?)?.toInt() ?? 1,
      limit: (map['limit'] as num?)?.toInt() ?? (songs.isEmpty ? 20 : songs.length),
      items: songs,
    );
  }
}
