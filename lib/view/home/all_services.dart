import 'package:flutter/material.dart';
import 'package:client/api/services_api.dart';
import 'package:client/api/jobs_api.dart';
import 'package:client/view/home/location_store.dart';
import 'package:client/view/booking/waiting_for_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Modern Services screen
/// - SliverAppBar with large title + subtle search bar
/// - Horizontal "Popular" carousel with gradient text overlay
/// - Filter chips (All / Popular / Trending / Nearby)
/// - Animated grid of services (2 cols) with soft cards
/// - Everything pulls styling from your app Theme
class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<AllServicesScreen> {
  // Opens a bottom sheet to create a service request for the selected service
  Future<void> _openRequestSheet(BuildContext context, Service s) async {
    final theme = Theme.of(context);
    final desc = TextEditingController();
    final scaffold = ScaffoldMessenger.of(context);
    // String? pmId; // optional, can be entered for test: pm_card_visa
    final Set<String> selectedAddOnIds = <String>{};
    bool submitting = false; // submission state to prevent double taps and show progress

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        // Local state used only within the sheet (kept minimal and commented)
        // Selected payment card (mocked for now, hook up to real wallet later)
        String? selectedPmId; // Will be sent as paymentMethodId
        String? selectedPmLabel; // Human-readable display (e.g., Visa •••• 1234)
        // Desired time: ASAP (default) or scheduled at a specific DateTime
        bool isAsap = true;
        DateTime? scheduledAt;
        // Photos selected by the user (limit to 4). We'll keep them client-side for now.
        final List<XFile> photos = <XFile>[];
        final ImagePicker picker = ImagePicker();
        // StateSetter reference from StatefulBuilder to update the sheet UI from helper functions
        StateSetter? setSheetStateRef;

        Future<void> pickPhotos() async {
          try {
            // Allow selecting multiple images; cap at 4 total
            final remaining = 4 - photos.length;
            if (remaining <= 0) return;
            final picked = await picker.pickMultiImage(limit: remaining);
            if (picked.isNotEmpty) {
              // Update within the sheet's state
              // ignore: invalid_use_of_visible_for_testing_member
              setSheetStateRef?.call(() {
                photos.addAll(picked.take(remaining));
              });
            }
          } catch (_) {
            // Silently ignore for now; could show a SnackBar
          }
        }

        Future<void> selectPaymentCard() async {
          // Minimal mock picker that mirrors Wallet cards; replace with real store/API when available
          final options = [
            {'id': 'pm_mock_visa_1234', 'label': 'Visa •••• 1234'},
            {'id': 'pm_mock_mc_8821', 'label': 'Mastercard •••• 8821'},
          ];
          final res = await showModalBottomSheet<Map<String, String>>(
            context: ctx,
            showDragHandle: true,
            builder: (ctx2) {
              return SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const ListTile(title: Text('Select payment card', style: TextStyle(fontWeight: FontWeight.w700))),
                    for (final o in options)
                      ListTile(
                        leading: const Icon(Icons.credit_card),
                        title: Text(o['label']!),
                        onTap: () => Navigator.of(ctx2).pop({'id': o['id']!, 'label': o['label']!}),
                      ),
                  ],
                ),
              );
            },
          );
          if (res != null) {
            setSheetStateRef?.call(() {
              selectedPmId = res['id'];
              selectedPmLabel = res['label'];
            });
          }
        }

        Future<void> pickScheduleDateTime() async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: ctx,
            firstDate: now,
            lastDate: now.add(const Duration(days: 30)),
            initialDate: scheduledAt ?? now,
          );
          if (date == null) return;
          if (!ctx.mounted) return;

          final time = await showTimePicker(
            context: ctx,
            initialTime: TimeOfDay.fromDateTime(scheduledAt ?? now.add(const Duration(hours: 2))),
          );
          if (time == null) return;
          final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          setSheetStateRef?.call(() { scheduledAt = at; });
        }

        // Use StatefulBuilder so chip selection & local state can update
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Capture the StateSetter so helper functions above can update the sheet
            setSheetStateRef = setSheetState;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request ${s.name}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Describe the issue',
                        hintText: 'e.g., Kitchen sink clogged',
                      ),
                    ),

                    // Add-ons
                    if (s.addOns.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Add-ons', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in s.addOns)
                            FilterChip(
                              label: Text(a.label),
                              selected: selectedAddOnIds.contains(a.id),
                              onSelected: (sel) {
                                setSheetState(() {
                                  if (sel) {
                                    selectedAddOnIds.add(a.id);
                                  } else {
                                    selectedAddOnIds.remove(a.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],

                    // Payment card picker
                    const SizedBox(height: 12),
                    Text('Payment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.credit_card, size: 22),
                      title: Text(selectedPmLabel ?? 'Select payment card'),
                      subtitle: selectedPmLabel == null ? const Text('Tap to choose a saved card') : null,
                      onTap: selectPaymentCard,
                      trailing: const Icon(Icons.chevron_right),
                    ),

                    // Photos
                    const SizedBox(height: 12),
                    Text('Photos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (photos.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < photos.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(photos[i].path),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: -10,
                                  top: -10,
                                  child: IconButton(
                                    icon: const Icon(Icons.cancel, size: 18),
                                    onPressed: () {
                                      setSheetState(() => photos.removeAt(i));
                                    },
                                  ),
                                )
                              ],
                            ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: photos.length >= 4 ? null : pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(photos.isEmpty ? 'Add photos (optional)' : 'Add more photos'),
                      ),
                    ),

                    // Address (as-is)
                    const SizedBox(height: 12),
                    Text('Address', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            LocationStore.I.address ?? 'Set location in header first',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Desired time
                    const SizedBox(height: 12),
                    Text('When do you need it?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: true, label: Text('ASAP'), icon: Icon(Icons.flash_on)),
                        ButtonSegment<bool>(value: false, label: Text('Schedule'), icon: Icon(Icons.event_available)),
                      ],
                      selected: {isAsap},
                      onSelectionChanged: (s) {
                        final v = s.first;
                        setSheetState(() => isAsap = v);
                      },
                    ),
                    if (!isAsap) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: Text(scheduledAt == null
                            ? 'Select date & time'
                            : '${MaterialLocalizations.of(context).formatFullDate(scheduledAt!)} · ${TimeOfDay.fromDateTime(scheduledAt!).format(context)}'),
                        onTap: pickScheduleDateTime,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                try {
                                  if (s.serviceTypeId == null || s.serviceTypeId!.isEmpty) {
                                    if (!mounted) return;
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Request unavailable'),
                                        content: const Text(
                                          'This is a preview service from a fallback list because the catalog failed to load.\n\n'
                                          'Please tap Retry at the top of the page to reload the services, then try again.'
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isAsap && scheduledAt == null) {
                                    // Require a date/time if Schedule is chosen
                                    scaffold.showSnackBar(const SnackBar(content: Text('Please select date & time')));
                                    return;
                                  }

                                  // Prevent duplicate taps while submitting
                                  setSheetState(() => submitting = true);

                                  final desired = isAsap
                                      ? const {'type': 'asap'}
                                      : {
                                          'type': 'scheduled',
                                          'at': scheduledAt!.toUtc().toIso8601String(),
                                        };

                                  final req = CreateJobRequest(
                                    serviceType: s.serviceTypeId!,
                                    description: desc.text.trim().isEmpty ? s.name : desc.text.trim(),
                                    desiredTime: desired,
                                    paymentMethodId: selectedPmId,
                                    addOnIds: selectedAddOnIds.toList(),
                                    currency: 'ZAR', // default currency expected by backend
                                  );

                                  // NOTE: Photo upload is not wired to backend in CreateJobRequest.
                                  // Keep photos local for now and upload to /jobs/{id}/attachments after job creation. TODO.

                                  final job = await JobsApi.I.createJob(req);
                                  // Attempt to proactively notify nearby providers about the new job.
                                  // Fire-and-forget with a short timeout so this never blocks navigation.
                                  // Some backends do this automatically; this call is a no-op if the endpoint is missing.
                                  // We intentionally ignore errors here and move the user to the waiting screen.
                                  JobsApi.I
                                      .broadcastJob(job.id)
                                      .timeout(const Duration(seconds: 3))
                                      .catchError((_) {});

                                  if (!ctx.mounted) return;
                                  // Close the bottom sheet using the sheet's own BuildContext (ctx),
                                  // not the outer page context. Using the wrong context can pop the
                                  // whole page or fail to close the sheet, leaving the UI stuck.
                                  Navigator.of(ctx).pop();
                                  // Navigate to waiting screen to poll for assignment using the outer context
                                  // (root navigator) once the sheet is closed.
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed(WaitingForProviderScreen.route, arguments: job.id);
                                } on DioException catch (e) {
                                  final code = e.response?.statusCode;
                                  String title = 'Request failed';
                                  String msg = 'Something went wrong. Please try again.';

                                  // Try to surface backend-provided validation messages for 400/422
                                  Map<String, dynamic>? data;
                                  try {
                                    final d = e.response?.data;
                                    if (d is Map<String, dynamic>) data = d;
                                  } catch (_) {}

                                  if (code == 422 || code == 400) {
                                    title = 'Check your details';
                                    final serverMsg = (data?['message'] as String?)?.trim();
                                    // Some backends return { errors: { field: 'message' } } or a list
                                    final errors = data?['errors'];
                                    String details = '';
                                    if (errors is Map) {
                                      details = errors.values
                                          .whereType<String>()
                                          .take(3)
                                          .join('\n');
                                    } else if (errors is List) {
                                      details = errors.whereType<String>().take(3).join('\n');
                                    }
                                    msg = [
                                      if (serverMsg != null && serverMsg.isNotEmpty) serverMsg,
                                      if (details.isNotEmpty) details,
                                      if ((serverMsg == null || serverMsg.isEmpty) && details.isEmpty)
                                        'Please review your description, add-ons, and payment method, then try again.'
                                    ].join('\n');

                                    // Log for debugging to help trace payload/validation problems
                                    // ignore: avoid_print
                                    print('[CreateJob] 400/422 validation error: ${e.response?.data}');
                                  } else if (code == 401) {
                                    title = 'Login required';
                                    msg = (data?['message'] as String?) ?? 'Your session has expired. Please log in to continue.';
                                  }

                                  if (!ctx.mounted) return;
                                  // Show a visible dialog above the sheet so users see the error
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(title),
                                      content: Text(msg),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                  if (!ctx.mounted) return;
                                  if (code == 401) {
                                    // Close the sheet and navigate to login for re-auth
                                    Navigator.of(context).pop();
                                    // Small delay to ensure sheet is dismissed before navigation
                                    await Future<void>.delayed(const Duration(milliseconds: 50));
                                    if (!context.mounted) return;
                                    Navigator.of(context).pushNamed('/login');
                                  }
                                } catch (_) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Request failed'),
                                      content: const Text('Something went wrong. Please try again.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                } finally {
                                  if (mounted) setSheetState(() => submitting = false);
                                }
                              },
                        child: submitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Submitting...'),
                                ],
                              )
                            : const Text('Request Now'),
                      ),
                    ),
                  ],
                    ),
                  ),
                ),
              );
          },
        );
      },
    );
  }

  // Backend: loaded services catalog (GET /api/v1/services)
  List<Service> _services = [];
  bool _loading = true;
  String? _error;

  // If navigated with a specific serviceTypeId from the Home screen, store it here
  String? _pendingServiceTypeToOpen;
  bool _didReadInitialArgs = false;

  @override
  void initState() {
    super.initState();
    // Defer reading route arguments until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didReadInitialArgs) {
        _didReadInitialArgs = true;
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['serviceTypeId'] is String) {
          _pendingServiceTypeToOpen = (args['serviceTypeId'] as String).trim();
          // If services already loaded, try open immediately
          if (!_loading) {
            _maybeOpenPendingService();
          }
        }
      }
    });
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      // Lazy import to avoid breaking builds if file moved; keep path stable
      // ignore: avoid_dynamic_calls
      final api = await Future.value(ServicesApi.I);
      final list = await api.fetchServices();
      setState(() {
        _services = list
            .map((s) => Service.withId(
                  serviceTypeId: s.id,
                  name: s.displayName,
                  icon: _iconForService(s.id),
                  imageAsset: _assetForService(s.id),
                  addOns: s.addOns.map((a) => AddOn(id: a.id, label: a.label)).toList(),
                ))
            .toList();
        _loading = false;
        _error = null;
      });
      // Attempt to auto-open the request sheet for a preselected service, if any
      if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenPendingService());
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load services';
        // Fallback to static demo list so UI remains usable
        _services = _fallbackServices;
      });
    }
  }
  void _maybeOpenPendingService() {
    if (!mounted) return;
    if (_pendingServiceTypeToOpen == null) return;
    final id = _pendingServiceTypeToOpen!.toLowerCase();
    final match = _services.firstWhere(
      (s) => (s.serviceTypeId ?? '').toLowerCase() == id,
      orElse: () => _services.firstWhere(
        // Try by normalized name as a fallback
        (s) => s.name.toLowerCase().replaceAll(' ', '_') == id,
        orElse: () => Service('^none^', Icons.help_outline),
      ),
    );
    if (match.name != '^none^') {
      // Clear so we won't open repeatedly on rebuilds
      _pendingServiceTypeToOpen = null;
      // Open the request creator for this service
      _openRequestSheet(context, match);
    }
  }

  final TextEditingController _search = TextEditingController();

  /// You can replace icons with your asset images if you prefer.
  // final List<_Service> _all = const [
  //   _Service('Home Cleaning', Icons.cleaning_services),
  //   _Service('Handyman', Icons.handyman),
  //   _Service('Plumbing', Icons.plumbing),
  //   _Service('Electrical', Icons.electrical_services),
  //   _Service('Interior Design', Icons.weekend),
  //   _Service('Painting', Icons.format_paint),
  //   _Service('Moving', Icons.local_shipping),
  //   _Service('Furniture Assembly', Icons.chair_alt),
  //   _Service('Smart Home Installation', Icons.device_hub),
  //   _Service('Appliance Repair', Icons.build_circle),
  //   _Service('Landscaping', Icons.yard),
  //   _Service('Pest Control', Icons.bug_report),
  // ];

  // final List<_Service> _popular = const [
  //   _Service('Interior Design', Icons.weekend),
  //   _Service('Home Cleaning', Icons.cleaning_services),
  //   _Service('Plumbing', Icons.plumbing),
  // ];

  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;

    final source = _services.isNotEmpty ? _services : _fallbackServices;
        final filtered = source.where((s) {
      final q = _search.text.trim().toLowerCase();
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      switch (_activeFilter) {
        // case 'Popular':
        //   return _popular.any((p) => p.name == s.name);
        case 'Trending':
        // placeholder rule; plug your analytics here
          return ['Painting', 'Electrical', 'Plumbing'].contains(s.name);
        case 'Nearby':
        // placeholder rule; plug your location logic here
          return ['Home Cleaning', 'Handyman', 'Pest Control'].contains(s.name);
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 120,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Services',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: onBg,
              ),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(controller: _search, onChanged: (_) {
                  setState(() {});
                }),
              ),
            ),
          ),

          // // Popular carousel
          // SliverToBoxAdapter(
          //   child: Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     child: _SectionHeader(title: 'Popular', action: 'See more', onTap: () {
          //       setState(() => _activeFilter = 'Popular');
          //     }),
          //   ),
          // ),
          // SliverToBoxAdapter(
          //   child: SizedBox(
          //     height: 160,
          //     child: ListView.separated(
          //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //       scrollDirection: Axis.horizontal,
          //       itemCount: _popular.length,
          //       separatorBuilder: (_, __) => const SizedBox(width: 12),
          //       itemBuilder: (context, i) {
          //         final p = _popular[i];
          //         return _PopularCard(service: p);
          //       },
          //     ),
          //   ),
          // ),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in const ['All', 'Popular', 'Trending', 'Nearby'])
                    _FilterChip(
                      label: f,
                      selected: _activeFilter == f,
                      onSelected: () => setState(() => _activeFilter = f),
                    ),
                ],
              ),
            ),
          ),

          // All services grid
          // Error banner + retry when services failed to load from backend
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
                  ),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Could not load services',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Showing a preview list. Request is disabled until the catalog loads. Tap Retry to try again.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _loadServices,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _GridHeader(title: 'All Services', count: filtered.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            sliver: SliverAnimatedListGrid(
              items: filtered,
              builder: (context, s) => _ServiceCard(service: s, onTap: () async {
                // If this is a preview (fallback) service without a backend ID,
                // disable the Request flow and guide the user to retry loading.
                if (s.serviceTypeId == null || s.serviceTypeId!.isEmpty) {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Service catalog unavailable'),
                      content: const Text(
                        'We could not load the services catalog from the server.\n\n'
                        'You are seeing a preview list — requesting is disabled until the catalog loads. '
                        'Please tap Retry at the top to reload and try again.'
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                      ],
                    ),
                  );
                  return;
                }
                _openRequestSheet(context, s);
              }),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// ---------- UI Pieces ----------

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _SearchField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search services...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: .3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: .2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}


class _GridHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GridHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: onBg,
            )),
        Text('$count results',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final Service service;
  final VoidCallback onTap;
  const _ServiceCard({required this.service, required this.onTap});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: .15),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.04),
                )
              ],
            ),
            // Full-bleed image with overlay title for a more appealing card
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.service.imageAsset != null)
                    Image.asset(
                      widget.service.imageAsset!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        widget.service.icon,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  // Bottom gradient to ensure text legibility over the image
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Service name placed on top of the image
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      widget.service.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated grid that fades + slides items in a 2-column layout.
class SliverAnimatedListGrid extends StatelessWidget {
  final List<Service> items;
  final Widget Function(BuildContext, Service) builder;

  const SliverAnimatedListGrid({
    super.key,
    required this.items,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // Staggered entrance animation
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 250 + (index * 30)),
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 10),
                    child: child,
                  ),
                ),
                child: builder(context, items[index]),
              );
            },
            childCount: items.length,
          ),
          // Tweak grid density: slightly tighter spacing and a wider aspect to reduce card height.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
        );
      },
    );
  }
}

/// ---------- Helpers & Models ----------
IconData _iconForService(String id) {
  switch (id.toLowerCase()) {
    case 'cleaner':
    case 'home_cleaning':
    case 'cleaning':
      return Icons.cleaning_services;
    case 'plumber':
      return Icons.plumbing;
    case 'electrician':
    case 'electrical':
      return Icons.electrical_services;
    case 'pest_control':
      return Icons.bug_report;
    case 'moving':
      return Icons.local_shipping;
    case 'painting':
      return Icons.format_paint;
    case 'landscaping':
      return Icons.yard;
    case 'handyman':
      return Icons.handyman;
    default:
      return Icons.build_circle;
  }
}

const List<Service> _fallbackServices = [
  Service('Home Cleaning', Icons.cleaning_services),
  Service('Handyman', Icons.handyman),
  Service('Plumbing', Icons.plumbing),
  Service('Electrical', Icons.electrical_services),
  Service('Interior Design', Icons.weekend),
  Service('Painting', Icons.format_paint),
  Service('Moving', Icons.local_shipping),
  Service('Furniture Assembly', Icons.chair_alt),
  Service('Smart Home Installation', Icons.device_hub),
  Service('Appliance Repair', Icons.build_circle),
  Service('Landscaping', Icons.yard),
  Service('Pest Control', Icons.bug_report),
];

class AddOn {
  final String id;
  final String label;
  const AddOn({required this.id, required this.label});
}

class Service {
  final String? serviceTypeId; // backend id like plumber, cleaner
  final String name; // display name
  final IconData icon;
  final String? imageAsset; // local asset to match the home screen visual for this service
  final List<AddOn> addOns; // available add-ons for this service (from catalog)
  const Service(this.name, this.icon, {this.imageAsset})
      : serviceTypeId = null,
        addOns = const [];
  const Service.withId({required this.serviceTypeId, required this.name, required this.icon, this.imageAsset, this.addOns = const []});
}

/// Map backend service IDs to the same images used on the client home screen.
/// Falls back to null (icon) if we don't have a known mapping.
String? _assetForService(String id) {
  switch (id.toLowerCase()) {
    case 'cleaner':
    case 'home_cleaning':
    case 'cleaning':
      return 'assets/images/Cleaning_Cat.png';
    case 'plumber':
    case 'plumbing':
      return 'assets/images/Plumbing_Cat.png';
    case 'electrician':
    case 'electrical':
      return 'assets/images/Electrician_Cat.png';
    case 'gardener':
    case 'gardening':
      return 'assets/images/Gardening_Cat.png';
    case 'moving':
    case 'mover':
      return 'assets/images/Moving_Out_Cat.png';
    case 'painting':
    case 'painter':
      return 'assets/images/Painting_Cat.png';
    case 'smart_home':
    case 'smart_home_installation':
      return 'assets/images/Smart_Appliances_Cat.png';
    case 'pest_control':
      return 'assets/images/Pest_Control_Cat.png';
    default:
      return null;
  }
}