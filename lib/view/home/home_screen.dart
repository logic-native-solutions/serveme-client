import 'dart:async';

import 'package:client/auth/api_client.dart';
import 'package:client/custom/loader.dart';
import 'package:client/global/greet_user.dart';
import 'package:client/view/home/provider_section.dart';
import 'package:client/view/home/search_service.dart';
import 'package:client/view/home/serive_section.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'advert_section.dart';
import 'current_user.dart';
import 'greet_header.dart';
import 'header_actions.dart';

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
  /// Human-friendly greeting based on local time (e.g., "Good evening").
  final String _greet = greetingMessage();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // -- Session Bootstrap ------------------------------------------------------

  /// Performs initial data load and handles auth/session errors.
  void _bootstrap() {
    unawaited(() async {
      try {
        await CurrentUserStore.I.load();
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401) {
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
    }());
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

  // -- Build ------------------------------------------------------------------

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
                final user = store.user;
                final isLoading = store.isLoading;

                final name = (user?['firstName'] ?? '').toString().trim();
                final city = (user?['city'] ?? user?['address']?['city'] ?? user?['location'] ?? '').toString().trim();
                final country = (user?['country'] ?? user?['address']?['country'] ?? '').toString().trim();
                final locationText = [city, country].where((s) => s.isNotEmpty).join(', ');

                if (isLoading || user == null) {
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

                return AnimatedSwitcher(
                  duration: kHomeAnimDuration,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topLeft,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('content'),
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
                                onTapLocation: () => Navigator.of(context).pushNamed('/location-picker'),
                              ),
                            ),
                            HeaderActions(user: user),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
