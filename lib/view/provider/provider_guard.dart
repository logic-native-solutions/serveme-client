import 'package:client/auth/role_store.dart';
import 'package:flutter/material.dart';

/// ProviderGuard
/// -------------
/// Lightweight guard widget that ensures only providers can access the wrapped
/// [child] content. If the current role is not 'provider', the guard shows a
/// friendly not-authorized message and a button to navigate back to a safe
/// route (default: '/home').
class ProviderGuard extends StatelessWidget {
  const ProviderGuard({super.key, required this.child, this.fallbackRoute = '/home'});

  final Widget child;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    if (RoleStore.isProvider) return child;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Not authorized')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'This area is for providers only. If you think this is a mistake, please try again later or contact support.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(fallbackRoute, (_) => false),
              child: const Text('Go back'),
            )
          ],
        ),
      ),
    );
  }
}
