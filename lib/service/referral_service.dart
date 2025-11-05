import 'dart:math';

import 'package:client/static/load_env.dart';
import 'package:client/view/home/current_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// ReferralService
/// ----------------
/// Builds a user-scoped referral link and launches the native share sheet.
///
/// Goals for MVP:
/// - No backend dependency required.
/// - Deterministic code derived from the current user when available; random fallback otherwise.
/// - The URL uses the already-configured HTTPS_SERVER as base, so future backend
///   can recognize and attribute the referral using the `ref` query parameter.
/// - Friendly share text that matches the app tone; dark mode unaffected (share sheet is native).
class ReferralService {
  ReferralService._();

  /// Share the Invite-a-Friend message using a dependency-free approach.
  /// Strategy:
  /// 1) Try to open a prefilled email using mailto: via url_launcher.
  /// 2) If that fails, copy the referral link to the clipboard and show a snackbar.
  /// Note: We intentionally avoid share_plus here due to build resolution issues.
  static Future<void> shareInvite(BuildContext context) async {
    final code = _referralCode();
    final link = _referralLink(code);

    final subject = Uri.encodeComponent('Join me on ServeMe');
    final body = Uri.encodeComponent(
      "I'm using ServeMe to book trusted home services. Use my link to sign up and we'll both get credit:\n\n$link",
    );
    final mailto = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // fallthrough to clipboard copy
    }

    // Fallback: copy link to clipboard
    try {
      await Clipboard.setData(ClipboardData(text: link.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral link copied to clipboard')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share referral link')),
        );
      }
    }
  }

  /// Build a stable referral code from current user id when available.
  /// If user is not loaded, fallback to a short random string to still let users share.
  static String _referralCode() {
    final u = CurrentUserStore.I.user;
    final id = (u?.id ?? '').trim();
    if (id.isNotEmpty) {
      // Simple, readable code: SRV + last 6 of user id (alnum only).
      final compact = id.replaceAll(RegExp('[^A-Za-z0-9]'), '');
      final tail = compact.length <= 6 ? compact : compact.substring(compact.length - 6);
      return 'SRV$tail'.toUpperCase();
    }
    // Fallback: random 6 chars
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Build the HTTPS referral link using the configured server base.
  static Uri _referralLink(String code) {
    final base = Uri.parse(Env.httpsServer);
    // Path is `/invite`, query `ref` for code so backend can attribute in future.
    final url = base.resolve('/invite');
    return url.replace(queryParameters: {
      ...url.queryParameters,
      'ref': code,
    });
  }
}
