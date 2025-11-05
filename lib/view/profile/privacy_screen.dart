import 'package:flutter/material.dart';
import 'package:client/service/settings_store.dart';
import 'package:url_launcher/url_launcher.dart';

/// Privacy controls for ServeMe
///
/// Matches app theming and supports dark mode. Values persist locally via
/// [SettingsStore] and can later be mirrored to the backend.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
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
        title: const Text('Privacy'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader('Profile visibility'),
                _Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Show profile photo'),
                        subtitle: const Text('Visible to people you interact with'),
                        value: _store.showProfilePhoto,
                        onChanged: (v) async {
                          setState(() => _store.showProfilePhoto = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('Show last seen'),
                        subtitle: const Text('When you were last active'),
                        value: _store.showLastSeen,
                        onChanged: (v) async {
                          setState(() => _store.showLastSeen = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: const Text('Read receipts'),
                        subtitle: const Text('Let others see when you’ve read messages'),
                        value: _store.readReceipts,
                        onChanged: (v) async {
                          setState(() => _store.readReceipts = v);
                          await _store.save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _SectionHeader('Data & preferences'),
                _Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Analytics & improvements'),
                        subtitle: const Text('Help us improve the app by sharing anonymous usage data'),
                        value: _store.analyticsOptIn,
                        onChanged: (v) async {
                          setState(() => _store.analyticsOptIn = v);
                          await _store.save();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        subtitle: Text('Read how we protect your data', style: TextStyle(color: scheme.onSurfaceVariant)),
                        onTap: () => _openUrl('https://serveme.app/privacy'),
                        trailing: const Icon(Icons.open_in_new),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'These settings apply on this device. Some options may also be enforced by your account or local laws.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
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
