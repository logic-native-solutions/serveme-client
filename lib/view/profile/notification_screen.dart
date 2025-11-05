import 'package:flutter/material.dart';
import 'package:client/service/settings_store.dart';

/// Notification preferences screen for ServeMe
///
/// Built to match the app theme (Material 3, AnonymousPro) and adapt to
/// light/dark modes automatically via ThemeData.
///
/// This screen persists user choices locally using [SettingsStore]. On a later
/// stage, these values can be synced with the backend user profile.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late SettingsStore _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _store = await SettingsStore.instance();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(label: 'Channels'),
                _Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive alerts on this device'),
                        value: _store.pushEnabled,
                        onChanged: (v) async {
                          setState(() => _store.pushEnabled = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('Email Updates'),
                        subtitle: const Text('Booking updates and announcements'),
                        value: _store.emailEnabled,
                        onChanged: (v) async {
                          setState(() => _store.emailEnabled = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('SMS Alerts'),
                        subtitle: const Text('Time-critical alerts to your phone'),
                        value: _store.smsEnabled,
                        onChanged: (v) async {
                          setState(() => _store.smsEnabled = v);
                          await _store.save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _SectionHeader(label: 'Categories'),
                _Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Bookings'),
                        subtitle: const Text('Requests, acceptances, changes'),
                        value: _store.catBookings,
                        onChanged: (v) async {
                          setState(() => _store.catBookings = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('Messages'),
                        subtitle: const Text('New messages and replies'),
                        value: _store.catMessages,
                        onChanged: (v) async {
                          setState(() => _store.catMessages = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('Promotions'),
                        subtitle: const Text('Occasional offers and tips'),
                        value: _store.catPromos,
                        onChanged: (v) async {
                          setState(() => _store.catPromos = v);
                          await _store.save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _SectionHeader(label: 'Do Not Disturb'),
                _Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Enable quiet hours'),
                        subtitle: Text(_dndSubtitle()),
                        value: _store.dndEnabled,
                        onChanged: (v) async {
                          setState(() => _store.dndEnabled = v);
                          await _store.save();
                        },
                      ),
                      if (_store.dndEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Start time'),
                          subtitle: Text(_formatTime(_store.dndStart)),
                          onTap: () => _pickTime(isStart: true),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('End time'),
                          subtitle: Text(_formatTime(_store.dndEnd)),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Small live preview indicating how notifications will look
                _SectionHeader(label: 'Preview'),
                _NotificationPreview(scheme: scheme),
                const SizedBox(height: 24),

                Text(
                  'Your preferences are stored on this device. We’ll sync them to your account in a future update.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  String _dndSubtitle() {
    if (!_store.dndEnabled) return 'Off';
    return '${_formatTime(_store.dndStart)} → ${_formatTime(_store.dndEnd)}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final mm = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$mm $suffix';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _store.dndStart : _store.dndEnd,
      helpText: isStart ? 'Select quiet hours start' : 'Select quiet hours end',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _store.dndStart = picked;
        } else {
          _store.dndEnd = picked;
        }
      });
      await _store.save();
    }
  }
}

/// Simple section header text matching app typography
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
    );
  }
}

/// Card wrapper using theme card styles
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

/// Lightweight visual preview for a notification tile using current theme
class _NotificationPreview extends StatelessWidget {
  final ColorScheme scheme;
  const _NotificationPreview({required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: const Icon(Icons.notifications),
        ),
        title: const Text('Booking confirmed'),
        subtitle: Text(
          'Your cleaner arrives tomorrow at 9:00 AM',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
