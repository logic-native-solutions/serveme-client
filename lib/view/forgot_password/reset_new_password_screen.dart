import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:client/static/load_env.dart';

class ResetNewPasswordScreen extends StatefulWidget {
  final String resetSession;
  const ResetNewPasswordScreen({super.key, required this.resetSession});

  @override
  State<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends State<ResetNewPasswordScreen> {
  final codeCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;
  bool obscure1 = true;
  bool obscure2 = true;

  double textSize = 16;
  final textFontWeight = FontWeight.w400;

  void _showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.errorContainer : scheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  void dispose() {
    codeCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse('${Env.httpsServer}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'resetSession': widget.resetSession,
          'code': codeCtrl.text.trim(),
          'newPassword': passCtrl.text,
        }),
      );

      if (res.statusCode == 200) {
        if (context.mounted) {
          _showSnack('Password reset successfully');
          if(!mounted) return;
          Navigator.of(context).pop();
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        final data = jsonDecode(res.body);
        if (context.mounted) _showSnack(data['message'] ?? 'Failed to reset password', isError: true);
      }
    } catch (e) {
      if (context.mounted) _showSnack('Network error', isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Headline that picks up typography from theme
                Text(
                  'Reset your password',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800
                  ),

                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code from your email and choose a new password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                // Code
                TextFormField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Email code',
                    hintText: '123456',
                    labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length != 6) return 'Enter the 6-digit code';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New password
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscure1,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                    suffixIcon: IconButton(
                      tooltip: obscure1 ? 'Show password' : 'Hide password',
                      icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscure1 = !obscure1),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '');
                    if (s.length < 8) return 'Use at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Confirm password
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscure2,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  style: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    labelStyle: TextStyle(fontSize: textSize, fontWeight: textFontWeight),
                    suffixIcon: IconButton(
                      tooltip: obscure2 ? 'Show password' : 'Hide password',
                      icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscure2 = !obscure2),
                    ),
                  ),
                  validator: (v) {
                    if (v != passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: loading ? null : _reset,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(
                      loading ? 'Saving…' : 'Save password',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
