import 'package:flutter/material.dart';

import '../../auth/api_client.dart';
import 'home_screen.dart';

/// Very small ChangeNotifier store that fetches and caches the current user.
class CurrentUserStore extends ChangeNotifier {
  CurrentUserStore._();

  /// Global instance to avoid wiring through widget trees.
  static final CurrentUserStore I = CurrentUserStore._();

  Map<String, dynamic>? _user;
  DateTime? _fetchedAt;
  bool _isLoading = false;

  /// Freshness window for cached user data.
  Duration ttl = const Duration(minutes: 15);

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;

  /// Whether the cached user data is still considered fresh.
  bool get _hasFreshData {
    if (_user == null || _fetchedAt == null) return false;
    return DateTime.now().difference(_fetchedAt!) < ttl;
  }

  /// Loads current user from [kUserDetailsPath] via [ApiClient].
  ///
  /// If [force] is false and the cache is fresh, the cached value is returned
  /// without performing a network call. Emits loading transitions and notifies
  /// listeners when data changes.
  Future<Map<String, dynamic>?> load({bool force = false}) async {
    if (_isLoading) return _user;
    _isLoading = true;
    notifyListeners();

    if (!force && _hasFreshData) {
      _isLoading = false;
      return _user;
    }

    try {
      final res = await ApiClient.I.dio.get(kUserDetailsPath);
      _user = Map<String, dynamic>.from(res.data as Map);
      _fetchedAt = DateTime.now();
      return _user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the in-memory cache and freshness timestamp.
  void clear() {
    _user = null;
    _fetchedAt = null;
    notifyListeners();
  }
}