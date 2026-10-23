import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../features/auth/repositories/auth_local_repository.dart';
import '../../features/favorites/repositories/favorites_repository.dart';
import '../../features/search/model/song_model.dart';
import 'recommendation_service.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;

  final FavoritesRepository _repository;

  FavoritesService._internal({FavoritesRepository? repository})
      : _repository = repository ?? FavoritesRepository();

  @visibleForTesting
  FavoritesService.test(this._repository);

  final Set<String> _likedSongIds = {};
  final List<SongModel> _likedSongs = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _total = 0;
  int _currentPage = 1;
  bool _hasMore = true;

  Set<String> get likedSongIds => Set.unmodifiable(_likedSongIds);
  List<SongModel> get likedSongs => List.unmodifiable(_likedSongs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalLikedCount => _total;
  bool get hasMore => _hasMore;

  bool isLiked(String? songId) {
    if (songId == null || songId.isEmpty) return false;
    return _likedSongIds.contains(songId);
  }

  Future<void> fetchLikedSongs({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getFavorites(page: _currentPage, limit: 50);

      if (refresh) {
        _likedSongs.clear();
      }

      for (final song in result.items) {
        _likedSongIds.add(song.id);
        if (!_likedSongs.any((s) => s.id == song.id)) {
          _likedSongs.add(song);
        }
      }

      _total = result.total;
      _hasMore = _likedSongs.length < _total;
      if (_hasMore) {
        _currentPage++;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkBatchStatus(List<String> songIds) async {
    final validIds = songIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (validIds.isEmpty) return;

    try {
      final likedIds = await _repository.checkBatchStatus(validIds);
      bool changed = false;
      for (final id in likedIds) {
        if (_likedSongIds.add(id)) {
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {
      // Non-blocking background batch status failure
    }
  }

  Future<bool> toggleLike(SongModel song) async {
    if (song.id.isEmpty) return false;

    final wasLiked = isLiked(song.id);
    final previousTotal = _total;

    // 1. Optimistic Update
    if (wasLiked) {
      _likedSongIds.remove(song.id);
      _likedSongs.removeWhere((s) => s.id == song.id);
      _total = max(0, _total - 1);
    } else {
      _likedSongIds.add(song.id);
      if (!_likedSongs.any((s) => s.id == song.id)) {
        _likedSongs.insert(0, song);
      }
      _total += 1;
    }
    notifyListeners();

    // 2. Perform Network Call
    try {
      if (wasLiked) {
        await _repository.removeFavorite(song.id);
      } else {
        await _repository.addFavorite(song);
      }

      // Fire-and-forget recommendation telemetry feedback
      unawaited(() async {
        try {
          final userId = await AuthLocalRepository().getEffectiveUserId();
          await RecommendationService().sendFeedback(
            userId: userId,
            songId: song.id,
            action: wasLiked ? 'dislike' : 'like',
            songMetadata: song.toMap(),
          );
        } catch (_) {}
      }());

      return true;
    } catch (e) {
      // 3. Rollback on failure
      if (wasLiked) {
        _likedSongIds.add(song.id);
        if (!_likedSongs.any((s) => s.id == song.id)) {
          _likedSongs.insert(0, song);
        }
      } else {
        _likedSongIds.remove(song.id);
        _likedSongs.removeWhere((s) => s.id == song.id);
      }
      _total = previousTotal;
      _errorMessage = 'Failed to update favorite status. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearLocal() {
    _likedSongIds.clear();
    _likedSongs.clear();
    _total = 0;
    _currentPage = 1;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();
  }
}
