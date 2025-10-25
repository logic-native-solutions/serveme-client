import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:client/static/load_env.dart';
import 'package:client/global/toast_message.dart';
import 'package:client/auth/auth_store.dart';
import 'package:client/auth/api_client.dart';
import 'package:client/auth/role_store.dart';
import 'package:client/auth/auth_gate.dart';
import 'package:client/service/login_user.dart';
import 'package:client/model/login_model.dart';
import 'package:client/custom/social_media_buttons.dart';
import 'package:client/view/home/current_user.dart';

class LoginController extends ChangeNotifier {
  // UI constants for the View
  static const double kFieldSpacing = 12.0;

  // Form
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // UI & state
  bool obscurePassword = true;
  bool rememberMe = true;
  bool isLoading = false;
  double textSize = 16;
  final FontWeight textFontWeight = FontWeight.w400;

  // Errors & token
  final errors = LoginErrors();
  String? token;

  // Secure storage
  final _secure = const FlutterSecureStorage();

  // Keys for persistence
  static const String _kRememberMeKey = 'remember_me';
  static const String _kRememberedEmailKey = 'remembered_email';
  static const String _kRememberPasswordKey = 'remember_password';
  static const String _kSecPasswordKey = 'sec_login_password';

  // ---------------------------------------------------------------------------
  // Init / Dispose
  // ---------------------------------------------------------------------------
  void init(BuildContext context) {
    loadEnv(); // ensure .env is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRememberedCredentials());
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // View helpers
  // ---------------------------------------------------------------------------
  void toggleObscure() {
    obscurePassword = !obscurePassword;
  }

  void setRemember(bool v) {
    rememberMe = v;
  }

  List<Widget> socialButtons(BuildContext context) => [
    SocialBox(
      onTap: () {}, // TODO: Implement Google flow
      child: Image.asset('assets/images/google.png', height: 26, width: 26),
    ),
    const SizedBox(width: 16),
    SocialBox(
      onTap: () {}, // TODO: Implement Apple flow
      child: const Icon(Icons.apple, size: 26),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Validators
  // ---------------------------------------------------------------------------
  String? validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------
  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberMeKey) ?? true; // default true
      final savedEmail = prefs.getString(_kRememberedEmailKey) ?? '';

      rememberMe = remember;
      if (remember && savedEmail.isNotEmpty) {
        emailController.text = savedEmail;
      }

      final rememberPwd = prefs.getBool(_kRememberPasswordKey) ?? remember;
      if (rememberPwd) {
        try {
          final savedPwd = await _secure.read(key: _kSecPasswordKey);
          if ((savedPwd ?? '').isNotEmpty) {
            passwordController.text = savedPwd!;
          }
        } catch (e) {
          debugPrint('[secure_storage] read error: $e');
        }
      }
      notifyListeners();
    } on PlatformException catch (e) {
      // Happens after hot restart when plugins are not yet registered on iOS
      debugPrint('[shared_preferences] platform exception: $e');
      rememberMe = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[shared_preferences] generic error: $e');
      rememberMe = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> onLogin(BuildContext context) async {
    if (isLoading) return; // guard: user is already submitting
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading = true;
    errors.clear();
    notifyListeners();

    final handler = LoginUserService(
      email: emailController.text.trim(),
      password: passwordController.text,
      serverPort: Env.httpsServer,
    );

    // Ensure we start from a clean local session (no stale cookies/token)
    // BEFORE performing the login request so that cookies set by login are preserved.
    await ApiClient.logout(callServer: false);
    RoleStore.clear();
    try {
      CurrentUserStore.I.clear();
    } catch (_) {}

    final result = await handler.submitFormDataToServer();
    print(result.success);
    print(result.emailError);
    print(result.passwordError);
    if (result.success) {
      token = result.token ?? '';

      // Persist the freshly issued access token for this user.
      await AuthStore.saveToken(token!);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kRememberMeKey, rememberMe);
        if (rememberMe) {
          await prefs.setString(_kRememberedEmailKey, emailController.text.trim());
        } else {
          await prefs.remove(_kRememberedEmailKey);
        }
        try {
          await prefs.setBool(_kRememberPasswordKey, rememberMe);
          if (rememberMe) {
            await _secure.write(key: _kSecPasswordKey, value: passwordController.text);
          } else {
            await _secure.delete(key: _kSecPasswordKey);
          }
        } catch (e) {
          debugPrint('[secure_storage] write error: $e');
        }
      } catch (_) {
        // No-op: failing to save "remember me" should not block login
      }

      if (context.mounted) {
        // After saving token, route back through AuthGate so that role-based
        // redirect (/api/v1/dashboard/redirect) decides the correct dashboard.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } else {
      errors.emailError = result.emailError;
      errors.passwordError = result.passwordError;
      errors.message = result.message;

      if (context.mounted && errors.message != null) {
        showToastMessage(errors.message!, context);
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> forgotPassword(BuildContext context) async {
    if (isLoading) return;
    final controller = TextEditingController(text: emailController.text.trim());
    final dialogFormKey = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: Form(
                key: dialogFormKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                    return emailOk ? null : 'Enter a valid email address';
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final ok = dialogFormKey.currentState?.validate() ?? false;
                    if (ok) {
                      Navigator.of(ctx).pop(true);
                    } else {
                      setLocalState(() {});
                    }
                  },
                  child: const Text('Send code'),
                ),
              ],
            );
          },
        );
      },
    );
    if (send != true) return;
    final email = controller.text.trim();

    isLoading = true;
    notifyListeners();

    try {
      // Use shared Dio client to keep behavior consistent (cookies, baseUrl, etc.)
      final dio = ApiClient.I.dio;
      final path = normalizeApiPath(dio, '/api/auth/send-reset-password-code');
      final resp = await dio.post(path, data: {'email': email});

      if (context.mounted) {
        final code = resp.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          showToastMessage('If that email exists, a reset code has been sent.', context);
        } else {
          final msg = (resp.data is Map<String, dynamic>)
              ? ((resp.data['message'] as String?) ?? 'Failed to send reset code.')
              : 'Failed to send reset code.';
          showToastMessage(msg, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showToastMessage('Network error. Please try again.', context);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}