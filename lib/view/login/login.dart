import 'package:flutter/material.dart';
import 'package:client/controller/login_controller.dart';

/// ---------------------------------------------------------------------------
/// LoginScreen
///
/// A lightweight wrapper that hosts the login form inside a scrollable,
/// keyboard-safe layout. Provides:
///  • A Scaffold that shifts when the keyboard appears
///  • Tap-to-dismiss keyboard behavior
///  • Responsive max-width for large displays
/// ---------------------------------------------------------------------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      resizeToAvoidBottomInset: true, // body slides up when keyboard shows
      body: SafeArea(child: _LoginBody()),
    );
  }
}

/// ---------------------------------------------------------------------------
/// _LoginBody
///
/// Internal body widget for [LoginScreen]. Handles padding around the keyboard,
/// scalability, and general layout.
/// ---------------------------------------------------------------------------
class _LoginBody extends StatelessWidget {
  const _LoginBody();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(), // dismiss keyboard on tap
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              24,                // breathing room at top
              16,
              bottomInset + 16,  // reserve space for keyboard
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480), // limit width
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting text
                    Text(
                      'Welcome back!',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Subtitle / instructions
                    const Text(
                      'Please fill in the fields below to login.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // The login form itself
                    const LoginForm(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pure UI that delegates all state/logic to [LoginController].
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final LoginController controller;

  @override
  void initState() {
    super.initState();
    controller = LoginController()..init(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _emailField() => TextFormField(
    controller: controller.emailController,
    autofillHints: const [AutofillHints.username, AutofillHints.email],
    textInputAction: TextInputAction.next,
    keyboardType: TextInputType.emailAddress,
    enabled: !controller.isLoading,
    style: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      labelText: 'Email',
      hintText: 'john.doe@example.com',
      labelStyle: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight),
      prefixIcon: const Icon(Icons.email, size: 20),
      errorText: controller.errors.emailError,
    ),
    validator: controller.validateEmail,
  );

  Widget _passwordField() => TextFormField(
    controller: controller.passwordController,
    autofillHints: const [AutofillHints.password],
    textInputAction: TextInputAction.done,
    obscureText: controller.obscurePassword,
    enabled: !controller.isLoading,
    style: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight),
    decoration: InputDecoration(
      labelText: 'Password',
      hintText: 'Minimum 8 chars, upper, lower, number, symbol',
      errorText: controller.errors.passwordError,
      labelStyle: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight),
      suffixIcon: IconButton(
        icon: Icon(controller.obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
        onPressed: controller.isLoading ? null : () => setState(controller.toggleObscure),
      ),
    ),
    validator: controller.validatePassword,
    onFieldSubmitted: (_) => controller.onLogin(context),
  );

  Widget _rememberForgotRow() => Row(
    children: [
      Checkbox(
        value: controller.rememberMe,
        onChanged: controller.isLoading
            ? null
            : (b) => setState(() => controller.setRemember(b ?? false)),
      ),
      Text(
        'Remember me',
        style: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight),
      ),
      const Spacer(),
      TextButton(
        onPressed: controller.isLoading ? null : () => controller.forgotPassword(context),
        child: const Text('Forgot password?'),
      ),
    ],
  );

  Widget _continueButton() => FilledButton(
    onPressed: controller.isLoading ? null : () => controller.onLogin(context),
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: controller.isLoading
        ? const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    )
        : Text('Continue', style: TextStyle(fontSize: controller.textSize, fontWeight: controller.textFontWeight)),
  );

  Widget _registerLink() => Align(
    alignment: Alignment.center,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text("Don't have an account? "),
        TextButton(
          onPressed: controller.isLoading
              ? null
              : () => Navigator.pushNamed(context, '/register'),
          child: const Text('Register'),
        ),
      ],
    ),
  );

  Widget _socialDivider() => const Row(
    children: [
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
    children: controller.socialButtons(context),
  );

  @override
  Widget build(BuildContext context) {
    // Rebuild the form whenever the controller calls notifyListeners().
    // This ensures server-side validation errors show immediately after
    // pressing "Continue" (onLogin), without needing to refocus inputs.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return AutofillGroup(
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _emailField(),
                const SizedBox(height: LoginController.kFieldSpacing),
                _passwordField(),
                const SizedBox(height: 8),
                _rememberForgotRow(),
                const SizedBox(height: LoginController.kFieldSpacing),
                _continueButton(),
                const SizedBox(height: LoginController.kFieldSpacing),
                _registerLink(),
                const SizedBox(height: LoginController.kFieldSpacing),
                _socialDivider(),
                const SizedBox(height: LoginController.kFieldSpacing),
                _socialButtons(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}