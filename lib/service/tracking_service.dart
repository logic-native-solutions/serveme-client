import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Live Tracking Service (Client-side)
/// ----------------------------------
/// Purpose
///  - Provides a simple, swappable interface to receive provider location
///    updates for the currently active job.
///  - In this MVP we mock a moving provider using a timer so the UI is verifiable
///    without backend integration.
///
/// Integration notes
///  - Replace [_MockProviderTracker] with a WebSocket/Firebase/HTTP polling
///    implementation wired to your backend once ready.
///  - Expose a method to bind by jobId once jobs are integrated end-to-end.
///  - All public methods are documented with clear contracts for easy swapping.
class TrackingService extends ChangeNotifier {
  TrackingService._();
  static final TrackingService I = TrackingService._();

  /// Current client coordinate (used for distance/ETA calculations on UI).
  /// In a real app, you would hydrate this from the device location service
  /// after permission. For safety, we default to a Johannesburg CBD-ish spot.
  LatLng _client = const LatLng(-26.2041, 28.0473);

  /// Latest known provider coordinate for the active job.
  LatLng? _provider;

  /// Stream subscription driving mock updates.
  StreamSubscription<LatLng>? _sub;

  /// Public getters
  LatLng get client => _client;
  LatLng? get provider => _provider;

  /// Update client's live location (e.g., from location plugin callback).
  void setClient(LatLng c) {
    _client = c;
    notifyListeners();
  }

  /// Bind to provider updates for a job.
  /// - jobId: server identifier of the current booking/job.
  /// - startFrom: optional starting coordinate for mock/demo.
  void bindToJob({required String jobId, LatLng? startFrom}) {
    // Clean any previous stream
    _sub?.cancel();

    // For MVP: start mock tracker.
    _sub = _MockProviderTracker(startFrom: startFrom ?? _client).stream.listen((pos) {
      _provider = pos;
      notifyListeners();
    });
  }

  /// Stop listening to provider location updates.
  Future<void> unbind() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Compute the straight-line distance (in km) between client and provider.
  /// For a production ETA, use a routing API (e.g., Google Directions API).
  double? distanceKm() {
    final p = _provider;
    if (p == null) return null;
    return _haversine(client.latitude, client.longitude, p.latitude, p.longitude) / 1000.0;
  }

  /// Very rough ETA assuming 35 km/h average city speed.
  Duration? eta({double avgSpeedKmh = 35}) {
    final dKm = distanceKm();
    if (dKm == null) return null;
    final hours = dKm / max(1e-6, avgSpeedKmh);
    return Duration(minutes: (hours * 60).round());
  }
}

/// A tiny mock that produces a circular path around the start position.
class _MockProviderTracker {
  final StreamController<LatLng> _ctrl = StreamController.broadcast();
  late final Timer _timer;
  final LatLng startFrom;
  double _t = 0;

  _MockProviderTracker({required this.startFrom}) {
    // 1Hz updates
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _t += 0.02; // slower circle
      final radiusMeters = 1200.0; // ~1.2km circle
      final earthRadius = 6378137.0;

      final dLat = (radiusMeters / earthRadius) * sin(_t);
      final dLng = (radiusMeters / (earthRadius * cos(pi * startFrom.latitude / 180))) * cos(_t);

      final lat = startFrom.latitude + (dLat * 180 / pi);
      final lng = startFrom.longitude + (dLng * 180 / pi);

      _ctrl.add(LatLng(lat, lng));
    });
  }

  Stream<LatLng> get stream => _ctrl.stream;

  void dispose() {
    _timer.cancel();
    _ctrl.close();
  }
}

// --- Math helpers -----------------------------------------------------------

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0; // meters
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a =
      (sin(dLat / 2) * sin(dLat / 2)) + cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degToRad(double deg) => deg * (pi / 180.0);
