import 'package:client/auth/auth_store.dart';
import 'package:flutter/material.dart';
import 'package:client/custom/social_media_buttons.dart';
import 'package:client/static/load_env.dart';
import 'package:client/service/login_user.dart';
import 'package:client/global/toast_message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ---------------------------------------------------------------------------
/// LoginForm
///
/// A clean Material 3 login form that:
///  • Validates email & password locally
///  • Submits credentials to [LoginUserService]
///  • Stores auth token via [AuthStore] on success
///  • Navigates to '/home'
/// Server-side errors are mapped back to fields and also shown as a global
/// message banner when applicable.
/// ---------------------------------------------------------------------------
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

/// Internal constants & configuration
const double _kFieldSpacing = 12.0;
const String _kRememberMeKey = 'remember_me';
const String _kRememberedEmailKey = 'remembered_email';
const String _kRememberPasswordKey = 'remember_password';
const String _kSecPasswordKey = 'sec_login_password';

class _LoginFormState extends State<LoginForm> {
  // ===========================================================================
  // Form State & Services
  // ===========================================================================
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Server-mapped errors / messages
  String? token;
  String? emailError;
  String? passwordError;
  String? errorMessage;

  // UI State
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false; // prevents double submits, disables inputs
  double textSize = 16;
  final textFontWeight = FontWeight.w400;

  final _secure = const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadEnv(); // ensure .env is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRememberedCredentials());
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberMeKey) ?? true; // default true
      final savedEmail = prefs.getString(_kRememberedEmailKey) ?? '';
      if (!mounted) return;
      setState(() {
        _rememberMe = remember;
        if (remember && savedEmail.isNotEmpty) {
          emailController.text = savedEmail;
        }
      });
      // Load remembered password (optional, stored securely). If the dedicated
      // flag is missing, default it to the same value as the email flag so the
      // single checkbox controls both.
      final rememberPwd = prefs.getBool(_kRememberPasswordKey) ?? remember;
      String? savedPwd;
      if (rememberPwd) {
        try {
          savedPwd = await _secure.read(key: _kSecPasswordKey);
        } catch (e) {
          debugPrint('[secure_storage] read error: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        if (rememberPwd && (savedPwd ?? '').isNotEmpty) {
          passwordController.text = savedPwd!;
        }
      });
    } on PlatformException catch (e) {
      // Happens after hot restart when plugins are not yet registered on iOS
      debugPrint('[shared_preferences] platform exception: $e');
      // Use defaults and continue without crashing
      if (!mounted) return;
      setState(() => _rememberMe = true);
    } catch (e) {
      debugPrint('[shared_preferences] generic error: $e');
      if (!mounted) return;
      setState(() => _rememberMe = true);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Validators (pure, no side-effects)
  // ===========================================================================
  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ===========================================================================
  // Actions
  // ===========================================================================
  /// Attempts login, updates field errors, persists token, and navigates on success.
  Future<void> _onLogin() async {
    if (_isLoading) return; // guard: user is already submitting
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      emailError = null;
      passwordError = null;
      errorMessage = null;
    });

    final handler = LoginUserService(
      email: emailController.text.trim(),
      password: passwordController.text,
      serverPort: Env.httpsServer,
    );

    final result = await handler.submitFormDataToServer();
    if (!mounted) return;

    if (result.success) {
      token = result.token ?? '';
      await AuthStore.saveToken(token!);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kRememberMeKey, _rememberMe);
        if (_rememberMe) {
          await prefs.setString(_kRememberedEmailKey, emailController.text.trim());
        } else {
          await prefs.remove(_kRememberedEmailKey);
        }
        try {
          // Single checkbox controls both email & password persistence
          await prefs.setBool(_kRememberPasswordKey, _rememberMe);
          if (_rememberMe) {
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

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } else {
      setState(() {
        emailError = result.emailError;
        passwordError = result.passwordError;
        errorMessage = result.message;
      });
    }

    if (errorMessage != null) {
      showToastMessage(errorMessage!, context);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Placeholder for a future recovery flow (email link / OTP, etc.).
  Future<void> _forgotPassword() async {
    if (_isLoading) return;
    final controller = TextEditingController(text: emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: Form(
                key: formKey,
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
                    final ok = formKey.currentState?.validate() ?? false;
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

    if(!mounted) return;
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${Env.httpsServer}/api/auth/send-forget-password-code');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        showToastMessage('If that email exists, a reset link has been sent.', context);
      } else {
        final msg = resp.body.isNotEmpty ? resp.body : 'Failed to send reset link.';
        showToastMessage(msg, context);
      }
    } catch (e) {
      if (mounted) showToastMessage('Network error. Please try again.', context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // Sub-widgets (focused, testable builders)
  // ===========================================================================

  Widget _emailField() => TextFormField(
        controller: emailController,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
        enabled: !_isLoading,
        style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
        decoration: InputDecoration(
          labelText: 'Email',
          hintText: 'john.doe@example.com',
          labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
          prefixIcon: const Icon(Icons.email, size: 20),
          errorText: emailError,
        ),
        validator: _validateEmail,
      );

  Widget _passwordField() => TextFormField(
        controller: passwordController,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        obscureText: _obscurePassword,
        enabled: !_isLoading,
        style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
        decoration: InputDecoration(
          labelText: 'Password',
          hintText: 'Minimum 8 chars, upper, lower, number, symbol',
          errorText: passwordError,
          labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
          // prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon:
                Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: _isLoading
                ? null
                : () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: _validatePassword,
        onFieldSubmitted: (_) => _onLogin(),
      );

  Widget _rememberForgotRow() => Row(
        children: [
          Checkbox(
            value: _rememberMe,
            onChanged: _isLoading
                ? null
                : (b) {
                    final val = b ?? false;
                    setState(() {
                      _rememberMe = val;
                    });
                  },
          ),
          Text(
            'Remember me',
            style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isLoading ? null : _forgotPassword,
            child: const Text('Forgot password?'),
          ),
        ],
      );

  Widget _continueButton() => FilledButton(
        onPressed: _isLoading ? null : _onLogin,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Continue', style: TextStyle(fontSize: textSize, fontWeight: textFontWeight)),
      );

  Widget _registerLink() => Align(
        alignment: Alignment.center,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("Don't have an account? "),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pushNamed(context, '/register'),
              child: const Text('Register'),
            ),
          ],
        ),
      );

  Widget _socialDivider() => Row(
        children: const [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('or continue with'),
          ),
          Expanded(child: Divider()),
        ],
      );

  Widget _socialButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SocialBox(
            onTap: () {}, // add loading guard if needed
            child: Image.asset('assets/images/google.png', height: 26, width: 26),
          ),
          const SizedBox(width: 16),
          SocialBox(
            onTap: () {},
            child: const Icon(Icons.apple, size: 26),
          ),
        ],
      );

  // ===========================================================================
  // Build
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final _ = Theme.of(context).colorScheme; // reserved for future theming

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // const SizedBox(height: 9),
            _emailField(),
            const SizedBox(height: _kFieldSpacing),
            _passwordField(),
            const SizedBox(height: 8),
            _rememberForgotRow(),
            const SizedBox(height: _kFieldSpacing),
            _continueButton(),
            const SizedBox(height: _kFieldSpacing),
            _registerLink(),
            const SizedBox(height: _kFieldSpacing),
            _socialDivider(),
            const SizedBox(height: _kFieldSpacing),
            _socialButtons(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}