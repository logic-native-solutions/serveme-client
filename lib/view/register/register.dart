import 'package:flutter/material.dart';
import 'package:client/view/register/register_form.dart';

/// ---------------------------------------------------------------------------
/// RegisterScreen
///
/// Presents the registration form inside a scrollable, keyboard-safe layout.
/// Responsibilities:
///  • Scaffold that shifts content when the keyboard appears
///  • Tap-to-dismiss keyboard gesture
///  • Centers content and constrains max width on large screens
/// ---------------------------------------------------------------------------
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      resizeToAvoidBottomInset: true, // body slides up with keyboard
      body: SafeArea(child: _RegisterBody()),
    );
  }
}

/// ---------------------------------------------------------------------------
/// _RegisterBody
///
/// Internal body for [RegisterScreen]. Handles padding, scrolling, and layout.
/// ---------------------------------------------------------------------------
class _RegisterBody extends StatelessWidget {
  const _RegisterBody();

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
              bottomInset + 16,  // space for keyboard
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    Text(
                      'Register',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Subtitle
                    const Text(
                      'Please fill in the fields below to create account.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Registration form
                    const RegisterForm(),
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