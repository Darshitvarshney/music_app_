import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/friends/model/friend_models.dart';
import '../../features/friends/repositories/friends_repository.dart';

/// Friends list + incoming requests for the home screen. No websockets: polls while
/// the friends section is visible (see [startPolling] and [stopPolling]).
class FriendsService extends ChangeNotifier {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;

  static const Duration pollInterval = Duration(seconds: 45);

  /// Re-opening the home tab sooner than this after a refresh does not trigger another request.
  static const Duration minRefreshGap = Duration(seconds: 15);

  final FriendsRepository _repository;
  final Duration _pollInterval;

  FriendsService._internal({FriendsRepository? repository})
      : _repository = repository ?? FriendsRepository(),
        _pollInterval = pollInterval;

  @visibleForTesting
  FriendsService.test(this._repository, {Duration interval = pollInterval})
      : _pollInterval = interval;

  List<FriendActivityModel> _friends = [];
  List<FriendRequestModel> _incoming = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  Timer? _timer;
  DateTime? _lastRefresh;
  bool _isRefreshing = false;
  bool _refreshAgain = false;

  List<FriendActivityModel> get friends => List.unmodifiable(_friends);
  List<FriendRequestModel> get incomingRequests => List.unmodifiable(_incoming);

  /// True only for the very first load (so the UI can show a spinner once, not on every poll).
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  bool get isPolling => _timer != null;

  Future<void> refresh() async {
    if (_isRefreshing) {
      _refreshAgain = true; // run once more when the current request ends
      return;
    }
    _isRefreshing = true;
    if (!_hasLoaded) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait<Object>([
        _repository.getActivity(),
        _repository.getRequests(),
      ]);
      _friends = results[0] as List<FriendActivityModel>;
      _incoming = (results[1] as FriendRequestsModel).incoming;
      _errorMessage = null;
      _hasLoaded = true;
    } catch (_) {
      // Keep showing whatever we already had; only the first load shows an error state.
      _errorMessage = 'Could not load your friends.';
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      _lastRefresh = DateTime.now();
      notifyListeners();
    }

    if (_refreshAgain) {
      _refreshAgain = false;
      await refresh();
    }
  }

  void startPolling() {
    if (_timer != null) return;
    final last = _lastRefresh;
    if (last == null || DateTime.now().difference(last) >= minRefreshGap) {
      refresh();
    }
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Sends a friend request by username and returns the server's message.
  /// Throws [ApiException] (e.g. `username_required`, `user_not_found`) so the UI can react.
  Future<String> sendRequest(String username) async {
    final result = await _repository.sendRequest(username);
    refresh();
    return result.message;
  }

  Future<String> acceptRequest(FriendRequestModel request) async {
    final result = await _repository.acceptRequest(request.id);
    _incoming = _incoming.where((r) => r.id != request.id).toList();
    notifyListeners();
    refresh();
    return result.message;
  }

  Future<void> declineRequest(FriendRequestModel request) async {
    await _repository.declineRequest(request.id);
    _incoming = _incoming.where((r) => r.id != request.id).toList();
    notifyListeners();
  }

  /// Drops everything, e.g. on logout.
  void reset() {
    stopPolling();
    _friends = [];
    _incoming = [];
    _hasLoaded = false;
    _isLoading = false;
    _errorMessage = null;
    _lastRefresh = null;
    notifyListeners();
  }
}
