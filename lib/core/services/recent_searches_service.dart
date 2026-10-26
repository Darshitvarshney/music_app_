import 'package:flutter/foundation.dart';
import '../../features/search/model/recent_search_model.dart';
import '../../features/search/repositories/recent_searches_repository.dart';

/// Shared, observable recent-search history (search page + library page stay in sync).
class RecentSearchesService extends ChangeNotifier {
  static final RecentSearchesService _instance =
      RecentSearchesService._internal();
  factory RecentSearchesService() => _instance;

  final RecentSearchesRepository _repository;

  RecentSearchesService._internal({RecentSearchesRepository? repository})
      : _repository = repository ?? RecentSearchesRepository();

  @visibleForTesting
  RecentSearchesService.test(this._repository);

  final List<RecentSearchModel> _searches = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RecentSearchModel> get searches => List.unmodifiable(_searches);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetch() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getRecentSearches();
      _searches
        ..clear()
        ..addAll(result);
    } catch (_) {
      _errorMessage = 'Could not load your recent searches.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fire-and-forget friendly: never throws, so a failed save can't break searching.
  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final saved = await _repository.saveSearch(trimmed);
      _searches.removeWhere(
        (s) => s.id == saved.id || _sameQuery(s.query, saved.query),
      );
      _searches.insert(0, saved);
      notifyListeners();
    } catch (_) {
      // Not signed in or offline: history just isn't recorded.
    }
  }

  Future<void> remove(RecentSearchModel search) async {
    final index = _searches.indexWhere((s) => s.id == search.id);
    if (index == -1) return;
    final removed = _searches.removeAt(index);
    notifyListeners();

    try {
      await _repository.deleteSearch(search.id);
    } catch (_) {
      final restoreAt = index > _searches.length ? _searches.length : index;
      _searches.insert(restoreAt, removed);
      _errorMessage = 'Could not remove that search.';
      notifyListeners();
    }
  }

  Future<void> clear() async {
    final backup = List<RecentSearchModel>.from(_searches);
    _searches.clear();
    notifyListeners();

    try {
      await _repository.clearAll();
    } catch (_) {
      _searches.addAll(backup);
      _errorMessage = 'Could not clear your search history.';
      notifyListeners();
    }
  }

  /// Drop in-memory history, e.g. on logout.
  void reset() {
    _searches.clear();
    _errorMessage = null;
    notifyListeners();
  }

  static bool _sameQuery(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
