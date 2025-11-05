import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../service/tracking_service.dart';

/// TrackingMapScreen
/// ------------------
/// Full-screen live tracking map showing:
///  - Client location (blue dot marker)
///  - Provider location (primary pin)
///  - A light polyline placeholder between them (straight line)
///
/// Notes
///  - This MVP uses a mock stream from [TrackingService]. Replace it with
///    real backend updates when ready. The UI and state hooks already exist.
class TrackingMapScreen extends StatefulWidget {
  static const String route = '/tracking';

  const TrackingMapScreen({super.key});

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  GoogleMapController? _mapCtrl;
  StreamSubscription? _debounceFit;

  @override
  void initState() {
    super.initState();
    // Ensure we are bound; summary does it, but this is safe.
    TrackingService.I.addListener(_onTick);
  }

  @override
  void dispose() {
    _debounceFit?.cancel();
    TrackingService.I.removeListener(_onTick);
    _mapCtrl?.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    _scheduleFitBounds();
  }

  void _scheduleFitBounds() {
    _debounceFit?.cancel();
    _debounceFit = Stream<void>.periodic(const Duration(milliseconds: 300)).take(1).listen((_) async {
      final c = TrackingService.I.client;
      final p = TrackingService.I.provider;
      if (_mapCtrl == null || p == null) return;
      final bounds = LatLngBounds(
        southwest: LatLng(
          _min(c.latitude, p.latitude),
          _min(c.longitude, p.longitude),
        ),
        northeast: LatLng(
          _max(c.latitude, p.latitude),
          _max(c.longitude, p.longitude),
        ),
      );
      try {
        await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } catch (_) {
        // If map not ready for bounds update, ignore.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = TrackingService.I.client;
    final provider = TrackingService.I.provider;
    final distanceKm = TrackingService.I.distanceKm();
    final eta = TrackingService.I.eta();

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('client'),
        position: client,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ),
    };
    if (provider != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('provider'),
          position: provider,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Provider'),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (provider != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('straight-line'),
          points: [client, provider],
          width: 4,
          color: theme.colorScheme.primary.withOpacity(0.6),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: client, zoom: 13),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                _mapCtrl = c;
                _scheduleFitBounds();
              },
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
          // Bottom status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_walk, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusText(distanceKm, eta),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Future: open in external maps or share link.
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(double? dKm, Duration? eta) {
    final dText = dKm == null ? 'Waiting for provider…' : '${dKm.toStringAsFixed(1)} km away';
    final eText = eta == null ? '' : ' • ETA ~ ${_fmtDuration(eta)}';
    return dText + eText;
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m} mins';
  }
}

// Small helpers to avoid importing dart:math here
double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
