import 'dart:async';

import 'package:client/auth/auth_gate.dart';
import 'package:client/auth/auth_store.dart';
import 'package:client/static/load_env.dart';
import 'package:client/view/forgot_password/reset_new_password_screen.dart';
import 'package:client/view/home/all_services.dart';
import 'package:client/view/home/home_shell.dart';
import 'package:client/view/message/message_screen.dart';
import 'package:client/view/otp/otp.dart';
import 'package:client/view/profile/profile_screen.dart';
import 'package:client/view/booking/booking_screen.dart';
import 'package:client/view/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:client/view/login/login.dart';
import 'package:client/view/register/register.dart';
import 'auth/api_client.dart';
import 'package:client/static/theme_data.dart';
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
  await AuthStore.init();
  await ApiClient.init(Env.httpsServer);

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
        '/booking': (_) => const BookingScreen(),
        '/wallet':(_) => const WalletScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/all-services': (_) => const AllServicesScreen(),
        '/reset': (_) => ResetNewPasswordScreen(resetSession: session)
      },
      onGenerateRoute: (settings) {
        switch(settings.name) {
          case '/otp':
            final args =
            (settings.arguments ?? const <String, dynamic>{}) as Map<String, dynamic>;

            final email = (args['email'] ?? '') as String;
            final phone = (args['phone'] ?? '') as String;
            final sessionId = (args['sessionId'] ?? '') as String;
            final backendBaseUrl = (args['backendBaseUrl'] ?? '') as String;

            // ---------------------------------------------------------------------------
            // Build and return the route
            // ---------------------------------------------------------------------------
            return MaterialPageRoute(
              builder: (_) => OtpScreen(
                email: email,
                phone: phone,
                sessionId: sessionId,
                backendBaseUrl: backendBaseUrl,
              ),
              settings: settings,
            );
          default:  return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Route not found')),
            ),
          );
        }
      }
    );
  }

}
