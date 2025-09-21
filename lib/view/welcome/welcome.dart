import 'package:flutter/material.dart';
import 'package:client/static/onboarding_data.dart';
import 'package:client/view/welcome/on_boarding_card.dart';
import 'package:client/view/welcome/pill_dots.dart';

/// ---------------------------------------------------------------------------
/// WelcomeScreen
///
/// The entry screen for new users.
/// Shows a paginated onboarding carousel with:
///  • Branded top bar and “Skip” button
///  • Swipeable [OnboardCard] pages
///  • Animated [IndicatorDots]
///  • Sign-in / Next / Get started controls
///
/// Onboarding data comes from [onboardingData].
/// ---------------------------------------------------------------------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // -------------------------------------------------------------------------
  // State & Controllers
  // -------------------------------------------------------------------------
  late final PageController _controller;
  int _currentPage = 0;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------
  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToAuth();
    }
  }

  void _skip() => _goToAuth();

  void _goToAuth() {
    Navigator.pushReplacementNamed(context, "/register");
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.55),
              cs.surfaceContainerHighest.withValues(alpha: 0.60),
              cs.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // -----------------------------------------------------------------
              // Top bar with app name & Skip
              // -----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: Row(
                  children: [
                    Text(
                      "ServeMe",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: cs.onSurface.withValues(alpha: 0.90),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Text(
                        "Skip",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // -----------------------------------------------------------------
              // Onboarding pages
              // -----------------------------------------------------------------
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    final item = onboardingData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: OnboardCard(
                        imagePath: item["image"]!,
                        title: item["title"]!,
                        text: item["text"]!,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // -----------------------------------------------------------------
              // Indicator dots
              // -----------------------------------------------------------------
              IndicatorDots(count: onboardingData.length, index: _currentPage),
              const SizedBox(height: 16),

              // -----------------------------------------------------------------
              // Bottom controls: Sign in / Next / Get started
              // -----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, "/login"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Sign in",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _nextPage,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == onboardingData.length - 1
                              ? "Get started"
                              : "Next",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}