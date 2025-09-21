import 'dart:async';

import 'package:client/auth/api_client.dart';
import 'package:client/global/greet_user.dart';
import 'package:client/custom/loader.dart';
import 'package:client/view/home/search_service.dart';
import 'package:client/view/home/greeting_header.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'header_actions.dart';

// ============================================================================
// Home Screen (Refactored)
// ----------------------------------------------------------------------------
// This file renders the Home screen header with a personalized greeting,
// avatar + notifications actions, and provides a small in-memory store to
// fetch/cache the current user. Code is grouped by concern:
//   1) Constants & Utilities
//   2) UI Widgets (Header, Actions)
//   3) State Store (CurrentUserStore)
//   4) Screen Widgets (HomeScreen, _HomeScreenHelper)
// All sections use consistent, concise documentation and M3 theme styles.
// ============================================================================

// == 1) CONSTANTS & UTILITIES =================================================

/// Default page padding for this screen.
const EdgeInsets _kPagePadding = EdgeInsets.all(15);

/// Animation duration used for small transitions on this screen.
const Duration _kAnimDuration = Duration(milliseconds: 250);

/// Backend path for the current-user details endpoint.
const String _kUserDetailsPath = '/api/v1/home/user-details';

/// A very small ChangeNotifier-backed store that fetches and caches
/// the current user. It advertises loading state and a simple TTL-based
/// freshness check.
class CurrentUserStore extends ChangeNotifier {
  /// Global instance. This keeps the API surface minimal and avoids plumbing.
  static final CurrentUserStore I = CurrentUserStore._();
  CurrentUserStore._();

  Map<String, dynamic>? _user;
  DateTime? _fetchedAt;

  /// Freshness window for cached user data (defaults to 15 minutes).
  Duration ttl = const Duration(minutes: 15);

  bool _isLoading = false;

  /// Whether a fetch is in progress.
  bool get isLoading => _isLoading;

  /// Latest cached user data (may be null).
  Map<String, dynamic>? get user => _user;

  /// Whether the cached user data is still considered fresh by [ttl].
  bool get hasFreshData {
    if (_user == null || _fetchedAt == null) return false;
    return DateTime.now().difference(_fetchedAt!) < ttl;
  }

  /// Loads current user from `/api/v1/user-details` using [ApiClient].
  ///
  /// If [force] is false and the cache is fresh, the cached value is returned
  /// without performing a network call. Emits loading state transitions and
  /// notifies listeners on data changes.
  Future<Map<String, dynamic>?> load({bool force = false}) async {
    if (_isLoading) return _user;
    _isLoading = true;
    notifyListeners();

    if (!force && hasFreshData) {
      _isLoading = false;
      return _user;
    }

    try {
      final res = await ApiClient.I.dio.get(_kUserDetailsPath);
      _user = Map<String, dynamic>.from(res.data as Map);
      _fetchedAt = DateTime.now();
      return _user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears cached user data and freshness timestamp.
  void clear() {
    _user = null;
    _fetchedAt = null;
    notifyListeners();
  }
}

// == 4) SCREEN WIDGETS ========================================================

/// Public HomeScreen route wrapper that hosts the stateful helper.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: _HomeScreenHelper()),
    );
  }
}

class AdvertSection extends StatelessWidget {
  const AdvertSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: const DecorationImage(
          image: AssetImage('assets/images/cleaning_ad.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.75), // darker top
              Colors.black.withValues(alpha: 0.5),  // lighter middle
              Colors.black.withValues(alpha: 0.75), // darker bottom
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Special Offer!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Get 20% off your first booking.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _LocationChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful HomeScreen implementation that:
///  • Kicks off current-user fetch on mount
///  • Handles 401 by logging out, clearing store, and navigating to /login
///  • Renders a loader while fetching and the header once data is available
class _HomeScreenHelper extends StatefulWidget {
  const _HomeScreenHelper();

  @override
  State<_HomeScreenHelper> createState() => _HomeScreenHelperState();
}

class _HomeScreenHelperState extends State<_HomeScreenHelper> {
  /// Human-friendly greeting based on local time (e.g., "Good evening").
  final String greet = greetingMessage();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Performs initial data load and handles auth/session errors.
  void _bootstrap() {
    () async {
      try {
        await CurrentUserStore.I.load();
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401) {
          // First, try a soft recovery in case the request raced the token attach
          final recovered = await _retryOnceOn401();
          if (recovered) return;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please log in again.')),
            );
          }
          // Hard logout only if recovery failed
          await ApiClient.logout();
          CurrentUserStore.I.clear();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load user: ${e.message}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unexpected error: $e')),
          );
        }
      }
    }();
  }

  /// Try one forced reload after a brief delay in case the token wasn't
  /// attached yet (race condition right after login). Returns true if
  /// recovery succeeded.
  Future<bool> _retryOnceOn401() async {
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      final u = await CurrentUserStore.I.load(force: true);
      if (u != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session restored.')),
          );
        }
        return true;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return false; // still unauthorized
      }
      rethrow; // surface other errors
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kPagePadding,
      child: Column(
        crossAxisAlignment:  CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: CurrentUserStore.I,
              builder: (context, _) {
                final user = CurrentUserStore.I.user;
                final isLoading = CurrentUserStore.I.isLoading;
                final name = (user?['firstName'] ?? '').toString().trim();
                final city = (user?['city'] ?? user?['address']?['city'] ?? user?['location'] ?? '').toString().trim();
                final country = (user?['country'] ?? user?['address']?['country'] ?? '').toString().trim();
                final locationText = [city, country].where((s) => s.isNotEmpty).join(', ');

                if (isLoading || user == null) {
                  return Center(
                    child: AnimatedSwitcher(
                      duration: _kAnimDuration,
                      child: SizedBox(
                        key: const ValueKey('loading'),
                        height: 120,
                        child: appLoader,
                      ),
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: _kAnimDuration,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topLeft,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: SingleChildScrollView(
                    key: const ValueKey('content'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(child: GreetingHeader(name: name, greet: greet)),
                            HeaderActions(user: CurrentUserStore.I.user),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (locationText.isNotEmpty)
                          _LocationChip(
                            label: locationText,
                            onTap: null, // TODO: wire to a location picker page
                          )
                        else
                          _LocationChip(
                            label: 'Set location',
                            onTap: null, // TODO: wire to a location picker page
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Flexible(child: SearchCategory()),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const AdvertSection(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
