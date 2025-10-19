import 'package:flutter/foundation.dart';

/// LocationStore
/// --------------
/// Very small shared store to hold the user's currently selected address
/// (e.g., from the AddressScreen). This lets multiple screens (Client Home,
/// Provider Dashboard, etc.) display the same chosen address in their header
/// chips without having to pass the value through route arguments.
///
/// Backend note:
/// - When you wire the AddressScreen to persist the primary address to your
///   backend, you can also hydrate this store from the CurrentUserStore (e.g.,
///   user.locationText) so it survives app restarts.
class LocationStore extends ChangeNotifier {
  LocationStore._();
  static final LocationStore I = LocationStore._();

  String? _address; // Human-friendly address label (e.g., "123 Main St, Pretoria")

  String? get address => _address;

  /// Set the current address and notify listeners. Whitespace is trimmed; empty
  /// strings are normalized to null.
  set address(String? value) {
    final v = (value ?? '').trim();
    final normalized = v.isEmpty ? null : v;
    if (_address == normalized) return;
    _address = normalized;
    notifyListeners();
  }
}
