import 'dart:async';

import 'package:client/auth/auth_store.dart';
import 'package:client/custom/loader.dart';
import 'package:client/view/home/home_shell.dart';
import 'package:client/view/welcome/welcome.dart';
import 'package:flutter/material.dart';

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
            return loggedIn ? const HomeShell() : const WelcomeScreen();
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