import 'dart:async';

import 'package:client/auth/auth_gate.dart';
import 'package:client/auth/auth_store.dart';
import 'package:client/static/load_env.dart';
import 'package:client/view/forgot_password/reset_new_password_screen.dart';
import 'package:client/view/home/home_shell.dart';
import 'package:client/view/message/message_screen.dart';
import 'package:client/view/profile/profile_screen.dart';
import 'package:client/view/search/search_screen.dart';
import 'package:client/view/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:client/view/login/login.dart';
import 'package:client/view/register/register.dart';
import 'auth/api_client.dart';
import 'package:client/static/theme_data.dart';
import 'package:client/route/handle_routes.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

/// ---------------------------------------------------------------------------
/// main.dart
///
/// Application entry point for ServeMe.
/// Responsibilities:
///  • Initialize bindings and environment
///  • Set up the API client
///  • Launch the [App] widget wrapped in [Phoenix] for hot-restart support
/// ---------------------------------------------------------------------------

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // -------------------------------------------------------------------------
  // App initialization
  // -------------------------------------------------------------------------
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnv();
  await ApiClient.init(Env.httpsServer);
  await AuthStore.init();

  runApp(
    Phoenix(
      child: const App(),
    ),
  );
}

/// ---------------------------------------------------------------------------
/// App
///
/// Root widget that builds the [MaterialApp] with:
///  • Light and dark color schemes (seeded)
///  • Theming from [themed()]
///  • Top-level routes and route generators
/// ---------------------------------------------------------------------------
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String session = '';

  void _loadSession() {
    setState(() {
      session = AuthStore.token ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  Widget build(BuildContext context) {
    final seed = HexColor("#203d2c");
    final light = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final dark  = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: themed(light),
      darkTheme: themed(dark),
      themeMode: ThemeMode.system,
      home: AuthGate(),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeShell(),
        '/message': (_) => const MessageScreen(),
        '/search': (_) => const SearchScreen(),
        '/wallet':(_) => const WalletScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/reset': (_) => ResetNewPasswordScreen(resetSession: session)
      },
      onGenerateRoute: (settings) => handleOtpRoute(settings),
    );
  }

}
