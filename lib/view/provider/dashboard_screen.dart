import 'dart:async';
import 'package:flutter/material.dart';
import 'package:client/view/provider/jobs_screen.dart';
import 'package:client/view/provider/provider_profile_screen.dart';
import 'package:client/view/provider/wallet_screen.dart';
import 'package:client/api/stripe_connect_api.dart';
import 'package:client/api/paystack_api.dart';
import 'package:client/api/earning_goal_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
// Mirror the client home header (greeting + date + location chip)
import 'package:client/view/home/greet_header.dart';
import 'package:client/global/greet_user.dart';
import 'package:client/view/profile/address_screen.dart';
import 'package:client/view/home/location_store.dart';
import 'package:client/view/home/current_user.dart';

/// ProviderDashboardScreen
/// ------------------------
/// This is a presentational template for the Service Provider dashboard.
/// It follows the existing project theming (Material 3, seeded color scheme,
/// AnonymousPro headings as seen in other screens) and mirrors the provided
/// structure from the design image. Data shown here is mocked so the template
/// can be dropped in and later wired to live API/state.
///
/// Key sections implemented:
///  • Welcome header with avatar + bell icon
///  • Earnings card (period selector, amount, delta, progress to goal)
///  • Two stat tiles: Upcoming Jobs and Rating
///  • Next Job card with title, client, time, and location
///  • Manage list tiles (Analytics, Availability) leading to TODO routes
///  • Bottom navigation dedicated to provider: Dashboard, Jobs, Messages, Profile
///
/// NOTE: Meaningful comments are included to help future contributors wire this
/// up with real data and navigation. Keep the styling consistent with the rest
/// of the app (spacing, colors, typography).
class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  static const String route = '/provider/dashboard';

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> with WidgetsBindingObserver {
  int _tabIndex = 0; // Bottom nav index

  // Selected/overridden location text from a location picker (optional)
  String? _selectedLocation; // When null or empty → show "Set location"

  // Provider metrics placeholders – keep until wired to backend endpoints.
  final double _earnings = 450.75; // TODO: replace with real provider earnings
  final double _deltaPct = 0.15; // TODO: compute vs previous period
  final int _upcomingJobs = 5; // TODO: fetch upcoming jobs count
  final double _rating = 4.9; // TODO: fetch provider rating

  // Earning goal state (replaces mocked _weeklyGoal)
  EarningGoal? _goal; // null when not set or not yet loaded
  bool _loadingGoal = false;
  String? _goalError;

  // Stripe Connect onboarding status for the provider; null until loaded.
  StripeStatus? _stripe;
  bool _loadingStripe = false;
  String? _stripeError;

  // Keep the last generated onboarding URL so we can offer a fallback "Copy link" if launch fails.
  String? _lastOnboardingUrl;

  // Cache the last snapshot sent to POST /onboarding to avoid redundant calls on every refresh.
  String? _lastSentAccountId;
  bool? _lastSentPayoutsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load current authenticated user so we can show real provider name/location.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CurrentUserStore.I.load();
      _refreshStripeStatus();
      _loadEarningGoal();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When the app returns to foreground, refresh Stripe status in case onboarding completed in browser.
      _refreshStripeStatus();
    }
  }

  /// Refreshes the provider's Paystack linkage status by calling the backend.
  Future<void> _refreshStripeStatus() async {
    setState(() {
      _loadingStripe = true;
      _stripeError = null;
    });
    if (kDebugMode) debugPrint('[PaystackOnboarding] Refreshing Paystack status…');
    try {
      final status = await PaystackApi.I.getPaystackStatus();
      if (!mounted) return;
      if (kDebugMode) debugPrint('[PaystackOnboarding] Status: linked=${status.linked}, payoutsEnabled=${status.payoutsEnabled}, subacct=${status.accountId ?? '-'}');
      setState(() {
        _stripe = status; // Reuse StripeStatus shape for UI compatibility
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _stripeError = 'Status check timed out — tap Refresh.';
      });
      if (kDebugMode) debugPrint('[PaystackOnboarding] Status check timed out');
    } catch (e) {
      if (!mounted) return;
      final msg = _mapDioError(e, fallback: 'Failed to load payouts status');
      setState(() {
        _stripeError = msg;
      });
      if (kDebugMode) debugPrint('[PaystackOnboarding] Status load failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingStripe = false;
        });
      }
    }
  }

  Future<void> _loadEarningGoal() async {
    setState(() {
      _loadingGoal = true;
      _goalError = null;
    });
    try {
      final g = await EarningGoalApi.I.getGoal();
      if (!mounted) return;
      setState(() {
        _goal = g; // null when not set
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _goalError = 'Earning goal request timed out — pull to refresh.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _goalError = _mapDioError(e, fallback: 'Failed to load earning goal');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGoal = false;
        });
      }
    }
  }

  Future<void> _showEditGoalSheet() async {
    // Allows providers to set or update their earning goal. Uses minor units on save.
    final amountController = TextEditingController(
      text: _goal != null ? (_goal!.amount / 100.0).toStringAsFixed(0) : '',
    );
    String period = _goal?.period == 'month' ? 'month' : 'week';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final text = theme.textTheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set earning goal', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '',
                  hintText: 'e.g., 600',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Period:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: period,
                    items: const [
                      DropdownMenuItem(value: 'week', child: Text('Per week')),
                      DropdownMenuItem(value: 'month', child: Text('Per month')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        period = v;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final raw = amountController.text.trim();
                        final amt = double.tryParse(raw);
                        if (amt == null || amt.isNaN || amt.isInfinite || amt < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Enter a valid goal amount')),
                          );
                          return;
                        }
                        try {
                          final saved = await EarningGoalApi.I.setGoal(
                            amountMinor: (amt * 100).round(),
                            currency: _goal?.currency ?? 'zar',
                            period: period,
                          );
                          if (!mounted) return;
                          setState(() {
                            _goal = saved;
                          });
                          if (context.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          final msg = _mapDioError(e, fallback: 'Failed to save goal');
                          if (context.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      // No-op: state already updated on save. If needed, re-fetch for consistency:
      // await _loadEarningGoal();
    }
  }

  /// Starts Paystack onboarding by collecting bank details and creating/updating a subaccount.
  Future<void> _startStripeOnboarding() async {
    // Note: We keep the method name for minimal refactor. Implementation now targets Paystack.
    setState(() {
      _stripeError = null;
    });

    final nameCtrl = TextEditingController();
    final acctCtrl = TextEditingController();
    // Commission percent is enforced by backend configuration (PaystackConfig.commissionPercent).
    // We fetch it for read-only display; the server will ignore any client-sent percentage.
    double? commission;
    try {
      commission = await PaystackApi.I.getCommissionPercent();
    } catch (_) {
      // Non-fatal: commission is purely informational; proceed without blocking the dialog.
      commission = null;
    }
    String? schedule; // auto|weekly|monthly|manual

    // Fetch SA banks list first to show a friendly bank name picker.
    // See: Features documents/paystack-sa-bank-auto-resolve.md
    List<String> saBanks = const [];
    try {
      saBanks = await PaystackApi.I.getSABanks();
    } catch (e) {
      // Non-fatal: we'll fall back to a free-text bank name input below.
      if (kDebugMode) debugPrint('[PaystackOnboarding] Failed to load SA banks: $e');
    }
    String? selectedBankName; // Human-readable bank selection (e.g., "FNB", "Standard Bank")

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set up payouts (Paystack)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Business/Display Name'),
                  textInputAction: TextInputAction.next,
                ),
                // Bank name picker: prefer dropdown from GET /providers/paystack/banks; fallback to text field.
                if (saBanks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBankName,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    items: saBanks
                        .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                        .toList(growable: false),
                    onChanged: (v) => selectedBankName = v,
                  )
                else
                  TextField(
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    onChanged: (v) => selectedBankName = v.trim(),
                    textInputAction: TextInputAction.next,
                  ),
                TextField(
                  controller: acctCtrl,
                  decoration: const InputDecoration(labelText: 'Account number'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                // Display backend-enforced platform commission (read-only)
                if (commission != null)
                  Text('Platform fee: ${commission.toStringAsFixed(0)}%', style: theme.textTheme.bodyMedium)
                else
                  Text('Platform fee is set by the platform', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('Optional settings', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                DropdownButtonFormField<String>(
                  initialValue: schedule,
                  decoration: const InputDecoration(labelText: 'Settlement schedule'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('auto')),
                    DropdownMenuItem(value: 'weekly', child: Text('weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('monthly')),
                    DropdownMenuItem(value: 'manual', child: Text('manual')),
                  ],
                  onChanged: (v) => schedule = v,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: Select your bank by name. The server will auto-resolve the correct Paystack bank code.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        );
      },
    );

    if (result != true) return;

    final businessName = nameCtrl.text.trim();
    final account = acctCtrl.text.trim();

    if (businessName.isEmpty || (selectedBankName == null || selectedBankName!.isEmpty) || account.isEmpty) {
      setState(() {
        _stripeError = 'All required fields must be filled (business name, bank name, account number).';
      });
      return;
    }

    setState(() {
      _loadingStripe = true;
    });
    try {
      await PaystackApi.I.upsertSubaccount(
        businessName: businessName,
        bankName: selectedBankName,
        accountNumber: account,
        settlementSchedule: schedule,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout details saved')));
      await _refreshStripeStatus();
    } catch (e) {
      if (!mounted) return;
      final msg = _mapDioError(e, fallback: 'Failed to save payout details');
      setState(() {
        _stripeError = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingStripe = false;
        });
      }
    }
  }

  // Maps Dio/network errors into brief, user-friendly messages for the payouts card.
  // Enhanced for Paystack upsert fix: backend may include `stage` and `upstream` fields.
  // See: Features documents/paystack-upsert-fix.md
  String _mapDioError(Object e, {required String fallback}) {
    if (e is TimeoutException) {
      return 'Request timed out — tap Refresh.';
    }
    if (e is DioException) {
      // Try to surface a helpful message coming from the backend, if any.
      String? serverMsg;
      String? stage;
      String? upstreamMsg;
      final data = e.response?.data;
      if (data is Map) {
        serverMsg = (data['message'] ?? data['error'] ?? data['detail'] ?? data['error_description'])?.toString();
        stage = data['stage']?.toString();
        final upstream = data['upstream'];
        if (upstream is Map) {
          upstreamMsg = (upstream['message'] ?? upstream['body'] ?? upstream['error'])?.toString();
        } else if (data['upstreamMessage'] != null) {
          upstreamMsg = data['upstreamMessage'].toString();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        serverMsg = data.trim();
      }
      // If server didn't provide a direct message, synthesize one from stage/upstream.
      if ((serverMsg == null || serverMsg.isEmpty) && (stage != null || (upstreamMsg != null && upstreamMsg.isNotEmpty))) {
        serverMsg = stage != null ? 'Failed at $stage: ${upstreamMsg ?? 'unexpected error'}' : upstreamMsg;
      }
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'No internet connection — check network and try again.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          // Auth-related errors: guide the user to re-authenticate
          if (code == 401) {
            return 'Your session expired — please log in again.';
          }
          if (code == 403) {
            return 'You do not have permission to perform this action.';
          }
          if (code == 409 || code == 422) {
            return serverMsg ?? fallback;
          }
          if (code == 503) {
            return 'Payouts service temporarily unavailable — try again later.';
          }
          if (code >= 500) {
            // Prefer server message if provided (e.g., Paystack upstream details)
            return serverMsg ?? 'Server error ($code) — try again shortly.';
          }
          return serverMsg ?? fallback;
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
        default:
          return serverMsg ?? fallback;
      }
    }
    return fallback;
  }

  /// Builds a Payouts status/onboarding card. Shown near the top of the dashboard.
  Widget _buildPayoutsCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final status = _stripe;

    // Loading state placeholder
    if (_loadingStripe && status == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text('Checking payouts status…', style: text.bodyMedium)),
            ],
          ),
        ),
      );
    }

    final bool linked = status?.linked == true;
    final bool enabled = status?.payoutsEnabled == true;

    if (linked && enabled) {
      // Per product requirement: Do not show the green "Payouts enabled" banner on the dashboard.
      // Wallet screen will continue to display payouts status. Keeping dashboard clean and focused.
      return const SizedBox.shrink();
    }

    // Not linked or not enabled → show CTA card
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cs.secondaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_wallet_outlined, color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Set up payouts to receive earnings', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              linked ? 'Finish verification to enable payouts.' : 'Add your Paystack payout details to get paid securely.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (_stripeError != null) ...[
              const SizedBox(height: 8),
              Text(_stripeError!, style: text.bodySmall?.copyWith(color: cs.error)),
            ],
            const SizedBox(height: 12),
            // Use Wrap instead of Row to avoid horizontal overflow on narrow devices (e.g., 320px width).
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadingStripe ? null : _startStripeOnboarding,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(linked ? 'Continue verification' : 'Set up payouts'),
                ),
                TextButton.icon(
                  onPressed: _loadingStripe ? null : _refreshStripeStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh status'),
                ),
                if (_lastOnboardingUrl != null)
                  TextButton.icon(
                    onPressed: _loadingStripe
                        ? null
                        : () async {
                            final url = _lastOnboardingUrl!;
                            await Clipboard.setData(ClipboardData(text: url));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Onboarding link copied')),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy link'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    // Derived presentation values
    final double? goalMajor = _goal != null ? (_goal!.amount / 100.0) : null;
    final progress = (goalMajor != null && goalMajor > 0)
        ? (_earnings / goalMajor).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        // Host all provider tabs inside an IndexedStack so the bottom
        // navigation persists across tabs (Dashboard, Jobs, Messages, Profile).
        child: IndexedStack(
          index: _tabIndex,
          children: [
            // ---------------------- Dashboard tab (index 0) ----------------------
            Padding(
              padding: const EdgeInsets.all(15), // matches Home page padding
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------------------------------------------------------
                    // Header (mirrors Client Home: greeting + date + Set location chip)
                    // -------------------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: CurrentUserStore.I,
                            builder: (context, _) {
                              final u = CurrentUserStore.I.user;
                              final displayName = u == null
                                  ? ''
                                  : [u.firstName].where((s) => (s).trim().isNotEmpty).join(' ');
                              return GreetingHeader(
                                name: displayName,
                                greet: greetingMessage(), // time-based greeting (Good morning/afternoon/evening)
                                // Prefer a globally stored address if available so the header
                                // reflects Primary Address chosen from Profile as well.
                                locationText: (_selectedLocation != null && _selectedLocation!.trim().isNotEmpty)
                                    ? _selectedLocation
                                    : (LocationStore.I.address?.isNotEmpty == true
                                        ? LocationStore.I.address
                                        : u?.locationText),
                                onPressed: () async {
                                  // Open the existing AddressScreen so the provider can set their address.
                                  // We expect AddressScreen to return a Map like { 'description': String, ... }
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AddressScreen()),
                                  );
                                  // If an address was selected, update the header chip text.
                                  if (!mounted) return;
                                  if (result is Map && result['description'] is String) {
                                    final picked = (result['description'] as String).trim();
                                    setState(() {
                                      _selectedLocation = picked;
                                    });
                                    // Also update shared store so client/provider headers stay in sync
                                    LocationStore.I.address = picked;
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        // Actions on the right: notifications + profile avatar (to mirror client header)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                // TODO: Navigate to a notifications screen when available
                                // For now, we can show a simple placeholder.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notifications coming soon')),
                                );
                              },
                              icon: const Icon(Icons.notifications_outlined),
                              tooltip: 'Notifications',
                            ),
                            const SizedBox(width: 6),
                            // Profile avatar button: switches to the Profile tab (index 3)
                            GestureDetector(
                              onTap: () {
                                setState(() => _tabIndex = 3);
                              },
                              child: AnimatedBuilder(
                                animation: CurrentUserStore.I,
                                builder: (context, _) {
                                  // Show provider initials inside the avatar (match client home icon style)
                                  final u = CurrentUserStore.I.user;
                                  String initials = 'U';
                                  if (u != null) {
                                    final f = (u.firstName).trim();
                                    final l = (u.lastName).trim();
                                    if (f.isEmpty && l.isEmpty) {
                                      initials = 'U';
                                    } else if (f.isNotEmpty && l.isNotEmpty) {
                                      initials = '${f[0]}${l[0]}'.toUpperCase();
                                    } else {
                                      final s = f.isNotEmpty ? f : l;
                                      initials = s[0].toUpperCase();
                                    }
                                  }
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: cs.primaryContainer,
                                    foregroundColor: cs.onPrimaryContainer,
                                    // Intentionally do not use backgroundImage so we always show initials on provider dashboard
                                    child: Text(
                                      initials,
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Payouts (Stripe Connect) status / onboarding
                    // -------------------------------------------------------------
                    _buildPayoutsCard(theme),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Earnings card
                    // -------------------------------------------------------------
                    _EarningsCard(
                      earnings: _earnings,
                      weeklyGoal: goalMajor,
                      deltaPct: _deltaPct,
                      loadingGoal: _loadingGoal,
                      goalError: _goalError,
                      onEditGoal: _showEditGoalSheet,
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Stats tiles (Upcoming jobs, Rating)
                    // -------------------------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.event_available_outlined,
                            label: 'Upcoming Jobs',
                            value: '$_upcomingJobs',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.star_border_rounded,
                            label: 'Rating',
                            value: _rating.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Next Job
                    // -------------------------------------------------------------
                    Text(
                      'Next Job',
                      style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    // TODO: Wire up to JobsApi.listJobs(role: 'provider') and select the soonest upcoming assigned job.
                    // For now, avoid showing dummy data and present a neutral placeholder.
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                              child: Icon(Icons.calendar_today_outlined, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('No upcoming jobs yet', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('New jobs you accept will appear here', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -------------------------------------------------------------
                    // Manage section
                    // -------------------------------------------------------------
                    Text(
                      'Manage',
                      style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _ManageTile(
                      icon: Icons.query_stats_outlined,
                      title: 'Analytics',
                      onTap: () {
                        // Navigate to the provider analytics screen template
                        Navigator.of(context).pushNamed('/provider/analytics');
                      },
                    ),
                    const SizedBox(height: 10),
                    _ManageTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Payouts',
                      onTap: () {
                        // Navigate to provider payouts screen template
                        Navigator.of(context).pushNamed('/provider/payouts');
                      },
                    ),
                    const SizedBox(height: 10),
                    _ManageTile(
                      icon: Icons.event_note_outlined,
                      title: 'My Availability',
                      onTap: () {
                        Navigator.of(context).pushNamed('/provider/availability');
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // ------------------------- Jobs tab (index 1) -------------------------
            const ProviderJobsScreen(),

            // ------------------------- Wallet tab (index 2) -----------------------
            const ProviderWalletScreen(),

            // ------------------------ Profile tab (index 3) -----------------------
            const ProviderProfileScreen(),
          ],
        ),
      ),

      // -----------------------------------------------------------------------
      // Provider bottom navigation
      // -----------------------------------------------------------------------
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          // Persist bottom navigation by switching tabs inside this screen
          // instead of pushing separate routes. This ensures the nav bar does
          // not disappear when opening Messages or other tabs.
          setState(() => _tabIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// Widgets
// ----------------------------------------------------------------------------

/// Earnings card showing the current period earnings and progress to goal.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.earnings,
    required this.deltaPct,
    this.weeklyGoal,
    this.loadingGoal = false,
    this.goalError,
    this.onEditGoal,
  });

  final double earnings;
  final double? weeklyGoal; // null when not set
  final bool loadingGoal;
  final String? goalError;
  final VoidCallback? onEditGoal;
  final double deltaPct; // positive or negative fraction (e.g., 0.15 = +15%)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;
    final progress = (weeklyGoal != null && weeklyGoal! > 0)
        ? (earnings / weeklyGoal!).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Earnings', style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
                ),
                // Period selector – static for now
                Row(
                  children: [
                    Text('This Week', style: text.bodyMedium),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '' // SOFT hint of currency; explicit $ may be localized later
              '${earnings.toStringAsFixed(2)}',
              style: text.displaySmall?.copyWith(
                fontFamily: 'AnonymousPro',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  deltaPct >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: deltaPct >= 0 ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(deltaPct.abs() * 100).toStringAsFixed(0)}% vs last week',
                  style: text.bodyMedium?.copyWith(color: deltaPct >= 0 ? Colors.green : Colors.red),
                )
              ],
            ),
            const SizedBox(height: 12),
            // Progress to weekly goal
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            if (loadingGoal)
              Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                  const SizedBox(width: 8),
                  Text('Loading goal…', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              )
            else if (goalError != null)
              Text(goalError!, style: text.bodySmall?.copyWith(color: cs.error))
            else if (weeklyGoal == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onEditGoal,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Set goal'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text('Weekly goal: ' '${weeklyGoal!.toStringAsFixed(0)}', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  if (onEditGoal != null)
                    TextButton.icon(
                      onPressed: onEditGoal,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple tile for stat value + icon used in the 2-up grid.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: cs.primary),
            const SizedBox(height: 10),
            Text(label, style: text.titleMedium?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(value, style: text.headlineSmall?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Card showing details for the next scheduled job.
class _NextJobCard extends StatelessWidget {
  const _NextJobCard({
    required this.title,
    required this.price,
    required this.clientName,
    required this.startsIn,
    required this.address,
  });

  final String title;
  final num price;
  final String clientName;
  final String startsIn;
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: text.titleLarge?.copyWith(fontFamily: 'AnonymousPro', fontWeight: FontWeight.w700),
                  ),
                ),
                Text('R' '${price.toString()}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(clientName, style: text.bodyLarge),
                Text(startsIn, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(address, style: text.bodyMedium),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// Simple list tile for the Manage section.
class _ManageTile extends StatelessWidget {
  const _ManageTile({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
