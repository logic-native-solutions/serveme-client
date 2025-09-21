import 'package:flutter/material.dart';
import 'package:client/view/login/login_form.dart';

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