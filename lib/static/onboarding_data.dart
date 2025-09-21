/// ---------------------------------------------------------------------------
/// Onboarding Data
///
/// Centralized content for the app’s onboarding flow. Each item contains:
///  • `title`  – short heading shown on the screen
///  • `text`   – supporting description
///  • `image`  – asset path for an illustration
///
/// Keeping this in a single file makes it easy to localize or modify later.
/// ---------------------------------------------------------------------------
library;

/// A constant list of onboarding slides displayed by the `OnboardingScreen`.
const List<Map<String, String>> onboardingData = [
  // -------------------------------------------------------------------------
  // Slide 1: Intro / Value Proposition
  // -------------------------------------------------------------------------
  {
    'title': 'Welcome to ServeMe',
    'text':
        'Your all-in-one platform for trusted help, right when you need it — from home cleaning to skilled repairs, always just a tap away.',
    'image': 'assets/images/all_category.png',
  },

  // -------------------------------------------------------------------------
  // Slide 2: How it Works
  // -------------------------------------------------------------------------
  {
    'title': 'How it Works',
    'text':
        'Connect with trusted helpers for everyday needs — cleaning, repairs, babysitting, and more.',
    'image': 'assets/images/requester.png',
  },

  // -------------------------------------------------------------------------
  // Slide 3: Safety & Convenience
  // -------------------------------------------------------------------------
  {
    'title': 'Safe. Reliable. Convenient.',
    'text':
        'All helpers are verified for your safety. Pay securely and track services in real-time.',
    'image': 'assets/images/safety.png',
  },
];