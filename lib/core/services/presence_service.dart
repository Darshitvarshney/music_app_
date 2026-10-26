import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/presence/repositories/presence_repository.dart';

/// Pings the backend in the foreground so friends see a green circle. The server counts
/// 5 min after the last ping as online; we ping every 3 min.
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;

  /// Must stay comfortably below the server's 5 minute online window.
  static const Duration heartbeatInterval = Duration(minutes: 3);

  final PresenceRepository _repository;
  final Duration _interval;
  Timer? _timer;

  PresenceService._internal({PresenceRepository? repository})
      : _repository = repository ?? PresenceRepository(),
        _interval = heartbeatInterval;

  @visibleForTesting
  PresenceService.test(this._repository, {Duration interval = heartbeatInterval})
      : _interval = interval;

  bool get isRunning => _timer != null;

  /// Sends a ping now and then every [heartbeatInterval]. Safe to call repeatedly.
  void start() {
    if (_timer != null) return;
    _repository.sendHeartbeat();
    _timer = Timer.periodic(_interval, (_) => _repository.sendHeartbeat());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
