import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsStore
///
/// Lightweight, device-local persistence for user settings used by
/// Notifications and Privacy screens. This keeps the new screens functional
/// end-to-end for the MVP. In a future iteration, mirror these to the backend.
class SettingsStore {
  // Keys
  static const _kPush = 'settings.pushEnabled';
  static const _kEmail = 'settings.emailEnabled';
  static const _kSms = 'settings.smsEnabled';

  static const _kCatBookings = 'settings.cat.bookings';
  static const _kCatMessages = 'settings.cat.messages';
  static const _kCatPromos = 'settings.cat.promos';

  static const _kDndEnabled = 'settings.dnd.enabled';
  static const _kDndStartH = 'settings.dnd.start.h';
  static const _kDndStartM = 'settings.dnd.start.m';
  static const _kDndEndH = 'settings.dnd.end.h';
  static const _kDndEndM = 'settings.dnd.end.m';

  static const _kShowLastSeen = 'settings.privacy.lastSeen';
  static const _kReadReceipts = 'settings.privacy.readReceipts';
  static const _kShowProfilePhoto = 'settings.privacy.showPhoto';
  static const _kAnalyticsOptIn = 'settings.privacy.analytics';

  SettingsStore._(this._prefs);
  final SharedPreferences _prefs;

  // Channel toggles (defaults optimized for engagement)
  bool pushEnabled = true;
  bool emailEnabled = true;
  bool smsEnabled = false;

  // Categories (defaults on for core flows, promos off by default)
  bool catBookings = true;
  bool catMessages = true;
  bool catPromos = false;

  // Do Not Disturb window (default 22:00-07:00 off)
  bool dndEnabled = false;
  TimeOfDay dndStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay dndEnd = const TimeOfDay(hour: 7, minute: 0);

  // Privacy toggles
  bool showLastSeen = true;
  bool readReceipts = true;
  bool showProfilePhoto = true;
  bool analyticsOptIn = true;

  static Future<SettingsStore> instance() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore._(prefs);
    await store._load();
    return store;
    }

  Future<void> _load() async {
    pushEnabled = _prefs.getBool(_kPush) ?? pushEnabled;
    emailEnabled = _prefs.getBool(_kEmail) ?? emailEnabled;
    smsEnabled = _prefs.getBool(_kSms) ?? smsEnabled;

    catBookings = _prefs.getBool(_kCatBookings) ?? catBookings;
    catMessages = _prefs.getBool(_kCatMessages) ?? catMessages;
    catPromos = _prefs.getBool(_kCatPromos) ?? catPromos;

    dndEnabled = _prefs.getBool(_kDndEnabled) ?? dndEnabled;
    final sh = _prefs.getInt(_kDndStartH);
    final sm = _prefs.getInt(_kDndStartM);
    final eh = _prefs.getInt(_kDndEndH);
    final em = _prefs.getInt(_kDndEndM);
    if (sh != null && sm != null) {
      dndStart = TimeOfDay(hour: sh, minute: sm);
    }
    if (eh != null && em != null) {
      dndEnd = TimeOfDay(hour: eh, minute: em);
    }

    showLastSeen = _prefs.getBool(_kShowLastSeen) ?? showLastSeen;
    readReceipts = _prefs.getBool(_kReadReceipts) ?? readReceipts;
    showProfilePhoto = _prefs.getBool(_kShowProfilePhoto) ?? showProfilePhoto;
    analyticsOptIn = _prefs.getBool(_kAnalyticsOptIn) ?? analyticsOptIn;
  }

  Future<void> save() async {
    await _prefs.setBool(_kPush, pushEnabled);
    await _prefs.setBool(_kEmail, emailEnabled);
    await _prefs.setBool(_kSms, smsEnabled);

    await _prefs.setBool(_kCatBookings, catBookings);
    await _prefs.setBool(_kCatMessages, catMessages);
    await _prefs.setBool(_kCatPromos, catPromos);

    await _prefs.setBool(_kDndEnabled, dndEnabled);
    await _prefs.setInt(_kDndStartH, dndStart.hour);
    await _prefs.setInt(_kDndStartM, dndStart.minute);
    await _prefs.setInt(_kDndEndH, dndEnd.hour);
    await _prefs.setInt(_kDndEndM, dndEnd.minute);

    await _prefs.setBool(_kShowLastSeen, showLastSeen);
    await _prefs.setBool(_kReadReceipts, readReceipts);
    await _prefs.setBool(_kShowProfilePhoto, showProfilePhoto);
    await _prefs.setBool(_kAnalyticsOptIn, analyticsOptIn);
  }
}
