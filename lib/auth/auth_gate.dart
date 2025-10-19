import 'dart:async';

import 'package:client/auth/auth_store.dart';
import 'package:client/custom/loader.dart';
import 'package:client/view/home/home_shell.dart';
import 'package:client/view/welcome/welcome.dart';
import 'package:flutter/material.dart';
// Role resolution dependencies must be imported at the top to satisfy Dart's
// directive ordering rules (imports before any declarations).
import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_router.dart';
import 'package:client/view/provider/dashboard_screen.dart';
import 'package:dio/dio.dart';

/// ---------------------------------------------------------------------------
/// AuthGate
/// A minimal route guard that checks persisted auth state *once* on startup and
/// decides which shell to display:
///   • Logged in  → [HomeShell]
///   • Logged out → [WelcomeScreen]
///
/// Design notes
/// ------------
/// • Uses a memoized Future so we do not rerun the check on every rebuild.
/// • Adds a short timeout to avoid indefinite hangs when secure storage stalls.
/// • Presents a small loading indicator while checking and a friendly retry
///   screen if an unexpected error occurs.
/// ---------------------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  late Future<bool> _loginFuture;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loginFuture = _checkLoginOnce();
  }

  // ---------------------------------------------------------------------------
  // Auth check
  // ---------------------------------------------------------------------------
  Future<bool> _checkLoginOnce() async {
    try {
      // Keep startup snappy; treat timeouts as logged-out so the app remains usable.
      return await AuthStore.isLoggedIn().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return false;
    } catch (_) {
      // Any unexpected error → fall back to logged-out UX.
      return false;
    }
  }

  void _retry() {
    setState(() {
      _loginFuture = _checkLoginOnce();
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loginFuture,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return _buildLoading();
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.hasError) return _buildError();
            final loggedIn = snapshot.data ?? false;
            return loggedIn ? const _RoleResolveScreen() : const WelcomeScreen();
        }
      },
    );
  }

  /// Lightweight splash while we probe local auth state.
  Widget _buildLoading() {
    return Scaffold(
      body: Center(child: SizedBox(height: 48, width: 48, child: FittedBox(child: SizedBox(child:
          // Reuse existing custom loader to remain consistent with app visuals.
          // `appLoader` is assumed to be a widget exported from custom/loader.dart
          // and sized internally; we wrap in SizedBox to avoid layout jank.
          // ignore: prefer_const_constructors
          Padding(padding: const EdgeInsets.all(0), child:
            // Using the same variable from your code base
            // This line is intentionally verbose to ensure no const issues.
            // ignore: unnecessary_parenthesis
            (appLoader)
          )
        ))),
    )
    );
  }

  /// Friendly fallback with an explicit retry action.
  Widget _buildError() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn’t check login state."),
            const SizedBox(height: 8),
            FilledButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// _RoleResolveScreen
/// ----------------------------------------------------------------------------
/// When a user is logged in, we resolve their effective role from the backend
/// and then render the correct dashboard. We keep this local to AuthGate to
/// avoid scattering boot-time logic across the app.

class _RoleResolveScreen extends StatefulWidget {
  const _RoleResolveScreen();

  @override
  State<_RoleResolveScreen> createState() => _RoleResolveScreenState();
}

class _RoleResolveScreenState extends State<_RoleResolveScreen> {
  late Future<_ResolveResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<_ResolveResult> _resolve() async {
    try {
      final roleRouter = RoleRouter(ApiClient.I.dio);
      final res = await roleRouter.fetchRedirect();
      return _ResolveResult.ok(role: res['role']!, target: res['target']!);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401) {
        // Unauthenticated → clear token and go to login screen.
        await ApiClient.logout(callServer: false);
        return const _ResolveResult.unauthenticated();
      }
      // For 403 or network issues, present a retry path.
      return _ResolveResult.error(message: 'Failed to resolve dashboard (${e.message}).');
    } catch (e) {
      return _ResolveResult.error(message: 'Unexpected error: $e');
    }
  }

  void _retry() {
    setState(() {
      _future = _resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolveResult>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        if (data.isUnauthenticated) {
          // Go to login/welcome
          return const WelcomeScreen();
        }
        if (data.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.message ?? 'Could not resolve dashboard'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        // Map backend targets to app routes/screens.
        final target = data.target ?? '/dashboard';
        switch (target) {
          case '/dashboard/provider':
            return const ProviderDashboardScreen();
          case '/dashboard/client':
          case '/dashboard':
          default:
            return const HomeShell();
        }
      },
    );
  }
}

class _ResolveResult {
  final String? role;
  final String? target;
  final bool isUnauthenticated;
  final String? message;

  const _ResolveResult._({this.role, this.target, this.isUnauthenticated = false, this.message});
  const _ResolveResult.unauthenticated() : this._(isUnauthenticated: true);
  const _ResolveResult.error({String? message}) : this._(message: message);
  const _ResolveResult.ok({required String role, required String target}) : this._(role: role, target: target);

  // Convenience flag used by the UI to render an error-and-retry state.
  bool get hasError => message != null && !isUnauthenticated;
}
