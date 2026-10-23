import 'package:client/core/services/favorites_service.dart';
import 'package:client/features/favorites/model/favorites_page_result.dart';
import 'package:client/features/favorites/repositories/favorites_repository.dart';
import 'package:client/features/search/model/song_model.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFavoritesRepository implements FavoritesRepository {
  final Map<String, SongModel> favoritesDb = {};
  bool shouldThrowOnAdd = false;
  bool shouldThrowOnRemove = false;

  @override
  Future<bool> addFavorite(SongModel song) async {
    if (shouldThrowOnAdd) {
      throw Exception('Simulated network error');
    }
    favoritesDb[song.id] = song;
    return true;
  }

  @override
  Future<bool> removeFavorite(String songId) async {
    if (shouldThrowOnRemove) {
      throw Exception('Simulated network error');
    }
    favoritesDb.remove(songId);
    return true;
  }

  @override
  Future<FavoritesPageResult> getFavorites({int page = 1, int limit = 50}) async {
    final list = favoritesDb.values.toList();
    return FavoritesPageResult(
      total: list.length,
      page: page,
      limit: limit,
      items: list,
    );
  }

  @override
  Future<bool> checkFavoriteStatus(String songId) async {
    return favoritesDb.containsKey(songId);
  }

  @override
  Future<List<String>> checkBatchStatus(List<String> songIds) async {
    return songIds.where((id) => favoritesDb.containsKey(id)).toList();
  }
}

void main() {
  const song1 = SongModel(
    id: 'song1',
    song: 'Believer',
    album: 'Collection',
    primaryArtists: 'Aish',
    singers: 'Aish',
    duration: 144,
    image: 'https://example.com/img1.jpg',
    mediaUrl: 'https://example.com/audio1.mp4',
    mediaPreviewUrl: '',
    year: '2022',
    language: 'english',
    permaUrl: 'https://www.jiosaavn.com/song/believer/1',
    hasLyrics: false,
  );

  const song2 = SongModel(
    id: 'song2',
    song: 'Khat',
    album: 'Khat',
    primaryArtists: 'Navjot Ahuja',
    singers: 'Navjot Ahuja',
    duration: 296,
    image: 'https://example.com/img2.jpg',
    mediaUrl: 'https://example.com/audio2.mp4',
    mediaPreviewUrl: '',
    year: '2025',
    language: 'hindi',
    permaUrl: 'https://www.jiosaavn.com/song/khat/2',
    hasLyrics: false,
  );

  group('FavoritesService Tests', () {
    late FakeFavoritesRepository fakeRepo;
    late FavoritesService service;

    setUp(() {
      fakeRepo = FakeFavoritesRepository();
      service = FavoritesService.test(fakeRepo);
    });

    test('isLiked starts false for unknown song', () {
      expect(service.isLiked('song1'), isFalse);
      expect(service.likedSongs, isEmpty);
      expect(service.totalLikedCount, 0);
    });

    test('toggleLike optimistically likes song and updates database', () async {
      final success = await service.toggleLike(song1);
      expect(success, isTrue);
      expect(service.isLiked('song1'), isTrue);
      expect(service.likedSongs.length, 1);
      expect(service.likedSongs.first.id, 'song1');
      expect(fakeRepo.favoritesDb.containsKey('song1'), isTrue);

      // Toggling again unlikes the song
      final unlikedSuccess = await service.toggleLike(song1);
      expect(unlikedSuccess, isTrue);
      expect(service.isLiked('song1'), isFalse);
      expect(service.likedSongs, isEmpty);
      expect(fakeRepo.favoritesDb.containsKey('song1'), isFalse);
    });

    test('toggleLike rolls back state if addFavorite fails', () async {
      fakeRepo.shouldThrowOnAdd = true;

      final success = await service.toggleLike(song1);
      expect(success, isFalse);
      expect(service.isLiked('song1'), isFalse);
      expect(service.likedSongs, isEmpty);
      expect(service.errorMessage, isNotNull);
    });

    test('toggleLike rolls back state if removeFavorite fails', () async {
      // First like successfully
      await service.toggleLike(song1);
      expect(service.isLiked('song1'), isTrue);

      // Now configure remove to fail
      fakeRepo.shouldThrowOnRemove = true;
      final success = await service.toggleLike(song1);

      expect(success, isFalse);
      // Rolled back to liked
      expect(service.isLiked('song1'), isTrue);
      expect(service.likedSongs.length, 1);
    });

    test('checkBatchStatus accurately discovers liked songs', () async {
      fakeRepo.favoritesDb['song2'] = song2;

      await service.checkBatchStatus(['song1', 'song2']);
      expect(service.isLiked('song1'), isFalse);
      expect(service.isLiked('song2'), isTrue);
    });

    test('fetchLikedSongs populates library and in-memory set', () async {
      fakeRepo.favoritesDb['song1'] = song1;
      fakeRepo.favoritesDb['song2'] = song2;

      await service.fetchLikedSongs(refresh: true);

      expect(service.likedSongs.length, 2);
      expect(service.isLiked('song1'), isTrue);
      expect(service.isLiked('song2'), isTrue);
      expect(service.totalLikedCount, 2);
    });
  });
}
