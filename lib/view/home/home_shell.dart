import 'package:client/view/home/home_screen.dart';
import 'package:client/view/message/message_screen.dart';
import 'package:client/view/profile/profile_screen.dart';
import 'package:client/view/booking/booking_screen.dart';
import 'package:client/view/wallet/wallet_screen.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// HomeShell
///
/// The main shell that hosts the app's bottom navigation and page stack.
///
/// Responsibilities
///  • Own the selected tab index and update it on user selection
///  • Host each tab inside an IndexedStack to preserve state per tab
///  • Elevate the NavigationBar when the current tab has scrolled content
/// ---------------------------------------------------------------------------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------
  int _index = 0;
  bool _elevated = false; // toggled by scroll

  // -------------------------------------------------------------------------
  // Configuration & Constants
  // -------------------------------------------------------------------------
  static const Duration _kBarAnim = Duration(milliseconds: 160);
  static const Duration _kIconAnim = Duration(milliseconds: 180);
  static const Curve _kEase = Curves.easeOut;

  // Pages for each tab. Using const widgets where possible preserves rebuilds.
  final List<Widget> _pages = const <Widget>[
    HomeScreen(),
    MessageScreen(),
    BookingScreen(),
    WalletScreen(),
    ProfileScreen()
  ];

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            final shouldElevate = n.metrics.extentBefore > 0;
            if (shouldElevate != _elevated) {
              setState(() => _elevated = shouldElevate);
            }
            return false;
          },
          child: IndexedStack(index: _index, children: _pages),
        ),
      ),

      // ---------------------------------------------------------------------
      // Bottom Navigation
      // ---------------------------------------------------------------------
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin divider that fades in once the active tab has scrolled
          AnimatedOpacity(
            opacity: _elevated ? 1 : 0,
            duration: _kBarAnim,
            child: Divider(height: 1, thickness: 1, color: cs.outlineVariant),
          ),

          // Subtle elevation shadow when content is scrolled
          AnimatedPhysicalModel(
            duration: _kBarAnim,
            curve: _kEase,
            elevation: _elevated ? 8 : 0,
            color: cs.surface,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            shape: BoxShape.rectangle,
            child: NavigationBar(
              backgroundColor: cs.surface,
              indicatorColor: cs.primaryContainer,
              selectedIndex: _index,
              onDestinationSelected: (i) {
                setState(() {
                  _index = i;
                  _elevated = false; // reset when switching tabs
                });
              },
              // Not const so `_index` can drive the animated icons
              destinations: [
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    selected: _index == 0,
                    duration: _kIconAnim,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    selected: _index == 1,
                    duration: _kIconAnim,
                  ),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    icon: Icons.calendar_today_outlined,
                    selectedIcon: Icons.calendar_month,
                    selected: _index == 2,
                    duration: _kIconAnim,
                  ),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    selectedIcon: Icons.account_balance_wallet_sharp,
                    selected: _index == 3,
                    duration: _kIconAnim,
                  ),
                  label: 'Wallet',
                ),
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    selected: _index == 4,
                    duration: _kIconAnim,
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// _AnimatedNavIcon
///
/// Scales the icon up a bit when selected, then eases back. Icon colors
/// are derived from the NavigationBar's IconTheme, so no manual color is set.
/// ---------------------------------------------------------------------------
class _AnimatedNavIcon extends StatelessWidget {
  const _AnimatedNavIcon({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    this.duration = const Duration(milliseconds: 180),
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final glyph = selected ? selectedIcon : icon;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 1.0, // base scale
        end: selected ? 1.15 : 1.0, // slight pop on select
      ),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(glyph),
    );
  }
}