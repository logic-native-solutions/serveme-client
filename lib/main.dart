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
import 'package:client/view/booking/waiting_for_provider.dart';
import 'package:client/view/wallet/wallet_screen.dart';
import 'package:client/view/wallet/add_payment_method_screen.dart' as client_wallet;
import 'package:client/view/provider/dashboard_screen.dart';
import 'package:client/view/provider/analytics_screen.dart';
import 'package:client/view/provider/availability_screen.dart';
import 'package:client/view/provider/payouts_screen.dart';
import 'package:client/view/provider/withdraw_screen.dart';
import 'package:client/view/provider/manage_payment_methods_screen.dart';
import 'package:client/view/wallet/client_payment_methods_screen.dart';
import 'package:client/view/provider/jobs_screen.dart';
import 'package:client/view/provider/wallet_screen.dart';
import 'package:client/view/provider/provider_guard.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:client/view/login/login.dart';
import 'package:client/view/register/register.dart';
import 'auth/api_client.dart';
import 'package:client/static/theme_data.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:client/service/push_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:client/view/provider/job_offer_screen.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/service/paystack_sdk.dart';

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

  // Register background handler for FCM data messages (job_offer).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

  // Initialize Paystack SDK using the public key from the server (if available).
  // This prepares the app for in-app card tokenization (Bolt/Uber style).
  Future<void> _initPaystackSdk() async {
    try {
      final key = await PaystackApi.I.getPaystackPublicKey();
      if (key != null && key.isNotEmpty) {
        await PaystackSdkService.I.initOnce(key);
      }
    } catch (_) {
      // Non-fatal: If SDK init fails or key not available, we fall back to redirect flow.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSession();
    // Initialize push messaging (FCM) for job offer fan-out handling.
    // This will request permissions, get token, and handle navigation for job_offer payloads.
    unawaited(PushMessaging.I.init(navigatorKey));
    // Initialize Paystack SDK (if public key is configured on server). Non-blocking.
    unawaited(_initPaystackSdk());
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
        // Client routes
        '/client/payment-methods': (_) => const ClientPaymentMethodsScreen(),
        client_wallet.ClientAddPaymentMethodScreen.route: (_) => const client_wallet.ClientAddPaymentMethodScreen(),
        // '/profile': (_) => const ProfileScreen(),
        '/all-services': (_) => const AllServicesScreen(),
        '/reset': (_) => ResetNewPasswordScreen(resetSession: session),
        // Provider routes
        '/provider/dashboard': (_) => const ProviderGuard(child: ProviderDashboardScreen()),
        '/provider/analytics': (_) => const ProviderGuard(child: ProviderAnalyticsScreen()),
        '/provider/availability': (_) => const ProviderGuard(child: ProviderAvailabilityScreen()),
        '/provider/payouts': (_) => const ProviderGuard(child: ProviderPayoutsScreen()),
        '/provider/payouts/withdraw': (_) => const ProviderGuard(child: WithdrawFundsScreen()),
        '/provider/payouts/methods': (_) => const ProviderGuard(child: ManagePaymentMethodsScreen()),
        '/provider/payouts/methods/add': (_) => const ProviderGuard(child: AddPaymentMethodScreen()),
        '/provider/jobs': (_) => const ProviderGuard(child: ProviderJobsScreen()),
        '/provider/wallet': (_) => const ProviderGuard(child: ProviderWalletScreen()),
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
          case WaitingForProviderScreen.route:
            final jobId = (settings.arguments ?? '') as String;
            return MaterialPageRoute(
              builder: (_) => WaitingForProviderScreen(jobId: jobId),
              settings: settings,
            );
          case ProviderJobOfferScreen.route:
            final jobId = (settings.arguments ?? '') as String;
            return MaterialPageRoute(
              builder: (_) => ProviderGuard(child: ProviderJobOfferScreen(jobId: jobId)),
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
