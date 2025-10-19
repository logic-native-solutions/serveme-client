import 'dart:async';

import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_store.dart';
import 'package:client/custom/loader.dart';
import 'package:client/global/greet_user.dart';
import 'package:client/view/home/provider_section.dart';
import 'package:client/view/home/search_service.dart';
import 'package:client/view/home/service_section.dart';
import 'package:client/view/profile/address_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:client/model/user_model.dart';

import 'advert_section.dart';
import 'current_user.dart';
import 'greet_header.dart';
import 'header_actions.dart';
import 'location_store.dart';

// =============================================================================
//  Home: Header + Actions + Advert + CurrentUser store + Screen
// -----------------------------------------------------------------------------
//  Goals
//   • Clean structure grouped by domain (constants → utils → UI → store → screen)
//   • Professional, concise doc comments
//   • Consistent Material 3 styling and naming
//   • Safe session handling (401 → soft retry → logout)
//   • Loader centered and content animated in
// =============================================================================

/// Default page padding for this screen.
const EdgeInsets kHomePagePadding = EdgeInsets.all(15);

/// Animation duration for lightweight transitions.
const Duration kHomeAnimDuration = Duration(milliseconds: 250);

/// Backend path for the current-user details endpoint.
const String kUserDetailsPath = '/api/v1/home/user-details';

/// Global font family used for headings/subtext in this view.
const String kBrandFont = 'AnonymousPro';

/// Public HomeScreen route wrapper that hosts the stateful helper.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: _HomeScreenBody()),
    );
  }
}

/// Stateful HomeScreen implementation that:
///  • Kicks off current-user fetch on mount
///  • Handles 401 by soft retry, then logs out and takes user to /login
///  • Renders a loader while fetching and the header once data is available
class _HomeScreenBody extends StatefulWidget {
  const _HomeScreenBody();

  @override
  State<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<_HomeScreenBody> {
  final String _greet = greetingMessage();
  String? _selectedLocation; // set when user picks an address from AddressScreen

  @override
  void initState() {
    super.initState();
    // Defer bootstrap to after the first frame so any ChangeNotifier
    // notifications from stores won't collide with the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    unawaited(() async {
      await CurrentUserStore.I.load();
      final store = CurrentUserStore.I;

      if (mounted && (store.isUnauthorized || store.error == 'Session expired')) {
        // Only now do a clean logout/navigation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        await ApiClient.logout();
        // Clear role and any cached current-user profile to ensure next session starts clean.
        try { RoleStore.clear(); } catch (_) {}
        try { CurrentUserStore.I.clear(); } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } else if (mounted && store.user == null && store.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.error!)),
        );
      }
    }());
  }

  Future<void> _handleRefresh() async {
    try {
      await CurrentUserStore.I.load(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshed')),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refresh failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kHomePagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: CurrentUserStore.I,
              builder: (context, _) {
                final store = CurrentUserStore.I;
                final UserModel? user = store.user;
                final bool isLoading = store.isLoading;

                // Initial loading: show loader when we don't have user yet
                if (isLoading && user == null) {
                  return Center(
                    child: AnimatedSwitcher(
                      duration: kHomeAnimDuration,
                      child: SizedBox(
                        key: const ValueKey('loading'),
                        height: 120,
                        child: appLoader,
                      ),
                    ),
                  );
                }

                // Finished loading but no user: show error
                if (!isLoading && user == null) {
                  return Center(
                    child: Text(store.error ?? 'Failed to load user data.'),
                  );
                }

                // We have a user object: safely read typed fields
                final String name = (user?.firstName ?? '').trim();

                // Build a fallback location from available fields
                final String city = (user?.city ?? '').trim();
                final String country = (user?.country ?? '').trim();
                final String derivedLocation = [city, country].where((s) => s.isNotEmpty).join(', ');
                // Prefer a user-chosen address from AddressScreen or the shared store if present
                final String fromStore = (LocationStore.I.address ?? '').trim();
                final String overridden = (_selectedLocation ?? '').trim();
                final String locationText = overridden.isNotEmpty
                    ? overridden
                    : (fromStore.isNotEmpty ? fromStore : derivedLocation);

                return AnimatedSwitcher(
                  duration: kHomeAnimDuration,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topLeft,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: SingleChildScrollView(
                      key: const ValueKey('content'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: GreetingHeader(
                                  name: name,
                                  greet: _greet,
                                  locationText: locationText,
                                  onPressed: () async {
                                    // Open AddressScreen and capture the selected address.
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AddressScreen()),
                                    );
                                    if (!mounted) return;
                                    if (result is Map && result['description'] is String) {
                                      setState(() {
                                        _selectedLocation = (result['description'] as String).trim();
                                      });
                                      // Also update shared store so other headers can reflect this
                                      // selection (e.g., after returning from Profile → Address).
                                      LocationStore.I.address = _selectedLocation;
                                    }
                                  },
                                ),
                              ),
                              if (user != null) HeaderActions(user: user),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [Flexible(child: SearchCategory())],
                          ),
                          const SizedBox(height: 15),
                          const AdvertSection(),
                          const SizedBox(height: 16),
                          const ServicesSection(),
                          const SizedBox(height: 16),
                          const ProviderSection(),
                        ],
                      ),
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