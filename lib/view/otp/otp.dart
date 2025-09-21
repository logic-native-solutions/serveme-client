import 'dart:async';
import 'dart:convert';
import 'package:client/auth/auth_store.dart';
import 'package:client/view/otp/section_card.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:client/static/load_env.dart';

/// ---------------------------------------------------------------------------
/// OTP Screen & Service
///
/// A fully self-contained screen that handles two-step verification (EMAIL → SMS)
/// with a minimal network layer. The flow enforces verifying Email *before* SMS.
///
/// Responsibilities
///  • Send OTPs (email and SMS), verify codes, and update destinations
///  • Guard concurrent requests and show user-friendly toast messages
///  • Scroll the SMS section into view when focusing or when keyboard opens
///  • Persist auth token after both verifications succeed (`/api/auth/save-user`)
/// ---------------------------------------------------------------------------

// ────────────────────────────────────────────────────────────────────────────
// TYPES & SIMPLE HELPERS
// ────────────────────────────────────────────────────────────────────────────

enum Channel { email, sms }

extension ChannelX on Channel {
  String get label => this == Channel.email ? 'EMAIL' : 'SMS';
  String get pretty => this == Channel.email ? 'Email' : 'SMS';
}

class VerifyResponse {
  /// e.g. "PENDING" or "VERIFIED"
  final String status;
  /// Example payload: { "EMAIL": true/false, "SMS": true/false }
  final Map<String, bool> isAuthorized;

  VerifyResponse({required this.status, required this.isAuthorized});

  factory VerifyResponse.fromJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Root is not an object');
    }
    final map = Map<String, dynamic>.from(decoded);
    final status = map['status'] as String?;
    final authRaw = map['isAuthorized'];
    if (status == null || authRaw is! Map) {
      throw const FormatException('Missing fields');
    }
    final isAuth = Map<String, bool>.fromEntries(
      authRaw.entries.map((e) => MapEntry(e.key.toString().toUpperCase(), e.value == true)),
    );
    return VerifyResponse(status: status, isAuthorized: isAuth);
  }
}

/// Masks an email like `johndoe@example.com` → `jo***@example.com`.
String maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return email;
  final name = parts[0];
  final domain = parts[1];
  final maskedName = name.length <= 2 ? '${name[0]}*' : '${name.substring(0, 2)}***';
  return '$maskedName@$domain';
}

/// Masks a phone number to leave only the last 4 digits visible.
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return phone;
  return phone.replaceRange(0, digits.length - 4, '*' * (digits.length - 4));
}

// ────────────────────────────────────────────────────────────────────────────
// NETWORK LAYER (single place for API calls)
// ────────────────────────────────────────────────────────────────────────────

class _OtpService {
  _OtpService(this.baseUrl, [http.Client? client]) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 15);

  Uri _u(String path) => Env.apiUri(path);

  /// Sends an OTP to the given [destination] for the [channel].
  Future<void> sendOtp({
    required String sessionId,
    required Channel channel,
    required String destination,
  }) async {
    final res = await _client
        .post(
          _u('/api/auth/otp/send'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'sessionId': sessionId,
            'channel': channel.label, // "EMAIL" | "SMS"
            'destination': destination, // email or phone
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to send ${channel.pretty} OTP (HTTP ${res.statusCode})');
    }
  }

  /// Verifies a code for [channel].
  Future<VerifyResponse> verify({
    required String sessionId,
    required Channel channel,
    required String code,
  }) async {
    final res = await _client
        .post(
          _u('/api/auth/otp/verify'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'sessionId': sessionId,
            'channel': channel.label,
            'code': code,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Server error: ${res.statusCode}');
    }
    return VerifyResponse.fromJson(res.body);
  }

  /// Updates the destination value (email/phone) for the given [channel].
  Future<bool> updateDestination({
    required String sessionId,
    required Channel channel,
    required String value,
  }) async {
    final res = await _client
        .post(
          _u('/api/auth/otp/update-destination'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'sessionId': sessionId,
            'channel': channel.label,
            'destination': value,
          }),
        )
        .timeout(_timeout);

    return res.statusCode == 200;
  }

  /// Finalizes the user after verification and returns a JSON map.
  Future<Map<String, dynamic>> saveUser({required String status}) async {
    final res = await _client
        .post(
          _u('/api/auth/save-user'),
          headers: _jsonHeaders,
          body: jsonEncode({'status': status}),
        )
        .timeout(_timeout);

    if (res.statusCode != 201) {
      throw Exception('Unexpected status: ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) throw const FormatException('Bad body');
    return data;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN
// ────────────────────────────────────────────────────────────────────────────

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.phone,
    required this.backendBaseUrl,
    required this.sessionId,
  });

  final String email;
  final String phone;
  final String sessionId;
  final String backendBaseUrl;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with WidgetsBindingObserver {
  // ── STATE ────────────────────────────────────────────────────────────────
  late String _email;
  late String _phone;
  late final _OtpService _svc;

  final _emailOtpCtrl = TextEditingController();
  final _smsOtpCtrl = TextEditingController();

  // Scrolling & focus helpers
  final _scrollCtrl = ScrollController();
  final _emailFocus = FocusNode();
  final _smsFocus = FocusNode();
  final _smsSectionKey = GlobalKey();

  // Verification flags
  bool _emailVerified = false;
  bool _smsVerified = false;
  String? _serverStatus;

  // In-flight guards
  bool _verifyingEmail = false;
  bool _verifyingSms = false;

  // Resend cooldowns
  final Map<Channel, int> _cooldown = {Channel.email: 0, Channel.sms: 0};
  final Map<Channel, Timer?> _timers = {Channel.email: null, Channel.sms: null};

  // ── LIFECYCLE ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _email = widget.email;
    _phone = widget.phone;
    _svc = _OtpService(widget.backendBaseUrl);

    // When SMS field gets focus, ensure it’s visible
    _smsFocus.addListener(() {
      if (_smsFocus.hasFocus) _scrollToSms();
    });

    _sendOtp(Channel.email); // kick off email OTP
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _timers.values) {
      t?.cancel();
    }
    _emailOtpCtrl.dispose();
    _smsOtpCtrl.dispose();
    _emailFocus.dispose();
    _smsFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// React to keyboard opening/closing
  @override
  void didChangeMetrics() {
    // When the keyboard opens, push SMS section into view if SMS has focus
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (bottom > 0 && _smsFocus.hasFocus) {
      _scrollToSms();
    }
  }

  // ── INTENTS (user-driven actions) ────────────────────────────────────────

  Future<void> _sendOtp(Channel channel) async {
    try {
      final destination = channel == Channel.email ? _email : _phone;
      await _svc.sendOtp(
        sessionId: widget.sessionId,
        channel: channel,
        destination: destination,
      );
      _startCooldown(channel, 30);
      _toast('${channel.pretty} code sent');
    } on TimeoutException {
      _error('Request timed out while sending ${channel.pretty} OTP');
    } catch (_) {
      _error('Network error while sending ${channel.pretty} OTP');
    }
  }

  Future<void> _verify(Channel channel, String code) async {
    // Enforce order: email before SMS
    if (channel == Channel.sms && !_emailVerified) {
      _error('Please verify your email first.');
      return;
    }
    if (code.length < 6) {
      _error('Enter the full 6-digit code');
      return;
    }
    // In-flight guard
    if ((channel == Channel.email && _verifyingEmail) ||
        (channel == Channel.sms && _verifyingSms)) {
      return;
    }
    setState(() {
      if (channel == Channel.email) _verifyingEmail = true;
      if (channel == Channel.sms) _verifyingSms = true;
    });

    try {
      final resp = await _svc.verify(
        sessionId: widget.sessionId,
        channel: channel,
        code: code,
      );

      final emailOk = resp.isAuthorized['EMAIL'] ?? false;
      final smsOk = resp.isAuthorized['SMS'] ?? false;

      if (!mounted) return;

      if (channel == Channel.email) {
        if (emailOk && resp.status == 'PENDING') {
          setState(() => _emailVerified = true);
          _toast('Email verified successfully');
          if (!_smsVerified) {
            _sendOtp(Channel.sms);
            // Auto-focus SMS after a moment, then scroll into view
            await Future.delayed(const Duration(milliseconds: 150));
            if (mounted) {
              _smsFocus.requestFocus();
              _scrollToSms();
            }
          }
          return;
        }
        if (!emailOk && resp.status == 'PENDING') {
          _toast('Incorrect email OTP');
          return;
        }
      }

      if (channel == Channel.sms) {
        if (smsOk && (resp.status == 'PENDING' || resp.status == 'VERIFIED')) {
          setState(() {
            _smsVerified = true;
            _serverStatus = resp.status;
          });
          _toast('SMS verified successfully');
          return;
        }
        if (!smsOk && resp.status == 'PENDING') {
          _toast('Incorrect SMS OTP');
          return;
        }
      }

      _error('Unexpected server state: ${resp.status}');
    } on FormatException {
      _error('Bad response from server (invalid JSON)');
    } on TimeoutException {
      _error('Request timed out while verifying ${channel.pretty}');
    } catch (_) {
      _error('Network error while verifying ${channel.pretty}');
    } finally {
      // if (!mounted) return;
      setState(() {
        if (channel == Channel.email) _verifyingEmail = false;
        if (channel == Channel.sms) _verifyingSms = false;
      });
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = await _promptText(
      title: 'Change Email',
      initial: _email,
      hint: 'Enter new email',
      keyboard: TextInputType.emailAddress,
    );
    if (newEmail == null || newEmail.isEmpty) return;

    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(newEmail);
    if (!ok) {
      _error('Invalid email address');
      return;
    }

    final updated = await _svc.updateDestination(
      sessionId: widget.sessionId,
      channel: Channel.email,
      value: newEmail,
    );
    // Proceed client-side even if backend declined binding
    setState(() {
      _email = newEmail;
      _emailVerified = false;
      _emailOtpCtrl.clear();
    });
    _sendOtp(Channel.email);
    if (!updated) _toast('Email changed locally; server not updated');
  }

  Future<void> _changePhone() async {
    final newPhone = await _promptText(
      title: 'Change Phone',
      initial: _phone,
      hint: 'Enter new phone (e.g. +27 82 123 4567)',
      keyboard: TextInputType.phone,
    );
    if (newPhone == null || newPhone.isEmpty) return;

    final ok = RegExp(r'^\+?\d[\d\s\-]{5,}$').hasMatch(newPhone);
    if (!ok) {
      _error('Invalid phone number');
      return;
    }

    final updated = await _svc.updateDestination(
      sessionId: widget.sessionId,
      channel: Channel.sms,
      value: newPhone,
    );
    setState(() {
      _phone = newPhone;
      _smsVerified = false;
      _smsOtpCtrl.clear();
    });
    _sendOtp(Channel.sms);
    if (!updated) _toast('Phone changed locally; server not updated');
  }

  Future<void> _onVerified() async {
    // Called when both email & sms verified
    try {
      final data = await _svc.saveUser(status: _serverStatus ?? 'PENDING');
      final token = (data['body'] as Map?)?['token'] as String?;
      if (token == null) {
        _error('Token missing in response');
        return;
      }
      await AuthStore.saveToken(token);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (_) {
      _error('Internal server error, Please try again later');
    }
  }

  // ── UI HELPERS ───────────────────────────────────────────────────────────
  void _startCooldown(Channel c, int seconds) {
    _timers[c]?.cancel();
    setState(() => _cooldown[c] = seconds);
    _timers[c] = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = (_cooldown[c] ?? 0) - 1;
      setState(() => _cooldown[c] = next <= 0 ? 0 : next);
      if (next <= 0) t.cancel();
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _error(String msg) => _toast(msg);

  Future<String?> _promptText({
    required String title,
    required String initial,
    required String hint,
    required TextInputType keyboard,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            decoration: InputDecoration(hintText: hint),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );
  }

  Future<void> _scrollToSms() async {
    // Tiny delay so layout settles after keyboard animation starts
    await Future.delayed(const Duration(milliseconds: 50));
    final ctx = _smsSectionKey.currentContext;
    if (ctx == null) return;
    if (!ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.2, // keep a bit above center (stays clear of keyboard)
      curve: Curves.easeOut,
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canContinue = _emailVerified && _smsVerified;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: cs.surface,
      body: SafeArea(
        // Tap anywhere to dismiss keyboard
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify details',
                  style: const TextStyle(
                    fontFamily: 'AnonymousPro',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Please confirm that the details below exist.',
                  style: TextStyle(
                    fontFamily: 'AnonymousPro',
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),

                // EMAIL SECTION
                SectionCard(
                  title: 'Email verification',
                  subtitle: maskEmail(_email),
                  onEdit: _changeEmail,
                  input: TextField(
                    focusNode: _emailFocus,
                    controller: _emailOtpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      hintText: 'Enter email code',
                      counterText: '',
                    ),
                  ),
                  primaryActionLabel: _emailVerified ? 'Verified' : 'Verify',
                  primaryActionEnabled: !_emailVerified && !_verifyingEmail,
                  onPrimaryAction: () => _verify(Channel.email, _emailOtpCtrl.text.trim()),
                  secondaryActionLabel:
                      _cooldown[Channel.email]! > 0 ? 'Resend in ${_cooldown[Channel.email]}s' : 'Resend',
                  secondaryActionEnabled: _cooldown[Channel.email] == 0 && !_emailVerified,
                  onSecondaryAction: () => _sendOtp(Channel.email),
                ),

                const SizedBox(height: 16),

                // SMS SECTION (keyed so we can ensureVisible)
                KeyedSubtree(
                  key: _smsSectionKey,
                  child: SectionCard(
                    title: 'SMS verification',
                    subtitle: maskPhone(_phone),
                    onEdit: _emailVerified ? _changePhone : null,
                    input: TextField(
                      focusNode: _smsFocus,
                      controller: _smsOtpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      enabled: _emailVerified,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        hintText: 'Enter SMS code',
                        counterText: '',
                      ),
                    ),
                    primaryActionLabel: _smsVerified ? 'Verified' : 'Verify',
                    primaryActionEnabled: !_smsVerified && _emailVerified && !_verifyingSms,
                    onPrimaryAction: () => _verify(Channel.sms, _smsOtpCtrl.text.trim()),
                    secondaryActionLabel: !_emailVerified
                        ? 'Verify email first'
                        : (_cooldown[Channel.sms]! > 0 ? 'Resend in ${_cooldown[Channel.sms]}s' : 'Resend'),
                    secondaryActionEnabled: _cooldown[Channel.sms] == 0 && !_smsVerified && _emailVerified,
                    onSecondaryAction: () => _sendOtp(Channel.sms),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canContinue ? _onVerified : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}