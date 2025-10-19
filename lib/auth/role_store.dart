/// RoleStore
/// ----------
/// In-memory cache of the current authenticated user's role as returned by
/// the backend dashboard director endpoint.
///
/// Values:
///  - 'provider' → Provider-only areas allowed
///  - 'client'   → Client-only areas allowed
///  - 'user'     → Generic authenticated user (no specific role)
///
/// Notes:
///  - We intentionally keep this in-memory only to avoid stale role state.
///  - Revalidation happens on app start and can happen on-demand after
///    navigation attempts into protected areas.
class RoleStore {
  RoleStore._();

  static String? _role; // 'provider' | 'client' | 'user'

  /// Read the cached role. May be null if not fetched yet.
  static String? get role => _role;

  /// True if the cached role is exactly 'provider'.
  static bool get isProvider => _role == 'provider';

  /// True if the cached role is exactly 'client'.
  static bool get isClient => _role == 'client';

  /// Update the cached role.
  static void setRole(String? newRole) {
    _role = newRole;
  }

  /// Clears the cached role (e.g., on logout).
  static void clear() {
    _role = null;
  }
}
