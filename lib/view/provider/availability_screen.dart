import 'package:flutter/material.dart';

/// ProviderAvailabilityScreen
/// ---------------------------
/// Presentational template for a provider to preview and adjust availability.
///
/// Design goals
///  - Follow the existing app theme (Material 3, seeded ColorScheme) and fonts
///    used elsewhere (AnonymousPro for section headings).
///  - Mirror the provided design structure: two month calendars stacked + a
///    weekday list with on/off switches and a default time window label.
///  - Keep logic simple and mocked so the backend can be wired later.
///
/// Backend wiring notes (where to connect)
///  - Fetch recurring weekly availability rule set (e.g., Mon 09:00–17:00 on/off)
///    and the exceptions per specific date (vacation, custom hours).
///    Suggested endpoints:
///    • GET  /api/v1/provider/availability/weekly → { mon:{on:true,start:"09:00",end:"17:00"}, ... }
///    • GET  /api/v1/provider/availability/exceptions?from=YYYY-MM-01&to=YYYY-MM-30
///          → [{date:"2025-10-05", on:false}, {date:"2025-10-07", start:"13:00", end:"18:00"}]
///    • PUT  /api/v1/provider/availability/weekly (body same as GET)
///    • PUT  /api/v1/provider/availability/exceptions (upsert one date rule)
///  - See inline TODOs where to call these APIs and how to map to UI state.
class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  static const String route = '/provider/availability';

  @override
  State<ProviderAvailabilityScreen> createState() => _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState extends State<ProviderAvailabilityScreen> {
  // Selected date across the calendars. Initialize to today.
  DateTime _selected = DateTime.now();

  // Mock weekly availability. Replace with API data.
  final Map<int, _DayAvailability> _weekly = {
    DateTime.monday:    const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.tuesday:   const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.wednesday: const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.thursday:  const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.friday:    const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.saturday:  const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
    DateTime.sunday:    const _DayAvailability(enabled: false, start: '09:00', end: '17:00'),
  };

  // In-memory date exceptions. Map yyyy-mm-dd → availability override.
  final Map<String, _DayAvailability> _exceptions = <String, _DayAvailability>{};

  // Helper to format a DateTime to yyyy-mm-dd used as key for exceptions.
  String _keyFor(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    // TODO: Load weekly and exception data from backend here, then setState.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    final DateTime currentMonth = DateTime(_selected.year, _selected.month);
    final DateTime nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Availability',
                        style: text.titleLarge?.copyWith(
                          fontFamily: 'AnonymousPro',
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // to balance back button space
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month 1
                    _MonthCalendar(
                      baseMonth: currentMonth,
                      selected: _selected,
                      onSelect: (d) => setState(() => _selected = d),
                    ),
                    const SizedBox(height: 16),
                    // Month 2 (next)
                    _MonthCalendar(
                      baseMonth: nextMonth,
                      selected: _selected,
                      onSelect: (d) => setState(() => _selected = d),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Set your availability',
                      style: text.titleLarge?.copyWith(
                        fontFamily: 'AnonymousPro',
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Weekday rows
                    for (final wd in _weekdayOrder) ...[
                      _WeekdayRow(
                        label: _weekdayName(wd),
                        availability: _weekly[wd]!,
                        onChanged: (enabled) {
                          setState(() {
                            _weekly[wd] = _weekly[wd]!.copyWith(enabled: enabled);
                          });
                          // TODO: Debounce & PUT weekly availability to backend
                        },
                        onEditTime: () async {
                          // Pick start and end using simple TimeOfDay pickers
                          final current = _weekly[wd]!;
                          final start = await showTimePicker(
                            context: context,
                            initialTime: _toTimeOfDay(current.start),
                          );
                          if (start == null) return;
                          final end = await showTimePicker(
                            context: context,
                            initialTime: _toTimeOfDay(current.end),
                          );
                          if (end == null) return;
                          setState(() {
                            _weekly[wd] = current.copyWith(
                              start: _fmtTimeOfDay(start),
                              end: _fmtTimeOfDay(end),
                            );
                          });
                          // TODO: PUT weekly availability update
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 12),
                    // Per-date quick toggle (exception example)
                    _DateExceptionCard(
                      selectedDate: _selected,
                      exception: _exceptions[_keyFor(_selected)],
                      onToggle: (enabled) {
                        setState(() {
                          _exceptions[_keyFor(_selected)] =
                              (_exceptions[_keyFor(_selected)] ?? const _DayAvailability(enabled: true, start: '09:00', end: '17:00'))
                                  .copyWith(enabled: enabled);
                        });
                        // TODO: PUT exception upsert to backend
                      },
                      onEditTime: () async {
                        final cur = _exceptions[_keyFor(_selected)] ?? const _DayAvailability(enabled: true, start: '09:00', end: '17:00');
                        final start = await showTimePicker(context: context, initialTime: _toTimeOfDay(cur.start));
                        if (start == null) return;
                        final end = await showTimePicker(context: context, initialTime: _toTimeOfDay(cur.end));
                        if (end == null) return;
                        setState(() {
                          _exceptions[_keyFor(_selected)] = cur.copyWith(
                            start: _fmtTimeOfDay(start),
                            end: _fmtTimeOfDay(end),
                          );
                        });
                        // TODO: PUT exception upsert to backend
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Sticky bottom hint akin to bottom nav spacing on other screens
          ],
        ),
      ),
    );
  }

  static const List<int> _weekdayOrder = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  String _weekdayName(int wd) {
    switch (wd) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  TimeOfDay _toTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 9;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Lightweight month calendar matching the design style.
/// Shows day-of-week header, then a 7xN grid of the month days. Selected day
/// is displayed with a filled circle.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.baseMonth,
    required this.selected,
    required this.onSelect,
  });

  final DateTime baseMonth; // any date within the month to render
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    final DateTime firstOfMonth = DateTime(baseMonth.year, baseMonth.month, 1);
    final int daysInMonth = DateTime(baseMonth.year, baseMonth.month + 1, 0).day;
    final int startWeekday = firstOfMonth.weekday % 7; // 1(Mon)..7(Sun) → 1..0

    // Total cells include leading blanks so that the 1st starts on correct column.
    final int totalCells = startWeekday + daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month title and arrows (arrows are decorative for this static template)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.chevron_left_rounded),
              Expanded(
                child: Center(
                  child: Text(
                    _monthTitle(firstOfMonth),
                    style: text.titleMedium?.copyWith(
                      fontFamily: 'AnonymousPro',
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Day of week header (S M T W T F S to match design)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _Dow('S'), _Dow('M'), _Dow('T'), _Dow('W'), _Dow('T'), _Dow('F'), _Dow('S'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: ((totalCells / 7).ceil()) * 7, // full weeks
            itemBuilder: (context, index) {
              final int dayNum = index - startWeekday + 1; // 1..daysInMonth
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final DateTime dayDate = DateTime(baseMonth.year, baseMonth.month, dayNum);
              final bool isSelected = _isSameDay(dayDate, selected);
              return _CalendarDay(
                day: dayNum,
                selected: isSelected,
                onTap: () => onSelect(dayDate),
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthTitle(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.day, required this.selected, required this.onTap});
  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Widget label = Text('$day', textAlign: TextAlign.center);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Center(
        child: selected
            ? CircleAvatar(
                radius: 16,
                backgroundColor: cs.primary,
                child: DefaultTextStyle(
                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
                  child: label,
                ),
              )
            : SizedBox(width: 32, height: 32, child: Center(child: label)),
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          t,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

/// One row in the weekly availability list with a label, time range subtitle,
/// and a trailing switch. Tapping the time area triggers the provided edit
/// callback.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({
    required this.label,
    required this.availability,
    required this.onChanged,
    required this.onEditTime,
  });

  final String label;
  final _DayAvailability availability;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEditTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle = '${availability.start} - ${availability.end}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(label, style: theme.textTheme.titleMedium),
        subtitle: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditTime,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ),
        trailing: Switch(value: availability.enabled, onChanged: onChanged),
      ),
    );
  }
}

/// Lightweight immutable value describing availability for a day.
class _DayAvailability {
  const _DayAvailability({required this.enabled, required this.start, required this.end});
  final bool enabled;
  final String start; // "HH:mm"
  final String end;   // "HH:mm"

  _DayAvailability copyWith({bool? enabled, String? start, String? end}) =>
      _DayAvailability(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}


/// Per-date exception editor card.
/// Renders the currently selected date, a switch to toggle availability ON/OFF
/// just for that date, and a small action to edit the time range. This is kept
/// very lightweight so you can wire your backend later by handling the provided
/// callbacks.
class _DateExceptionCard extends StatelessWidget {
  const _DateExceptionCard({
    required this.selectedDate,
    required this.exception,
    required this.onToggle,
    required this.onEditTime,
  });

  /// The date the calendars have selected.
  final DateTime selectedDate;
  /// The exception (if any) for [selectedDate]. When null, we show defaults
  /// and treat it as "no override" until toggled/edited.
  final _DayAvailability? exception;
  /// Called when the ON/OFF switch is toggled for this date.
  final ValueChanged<bool> onToggle;
  /// Called when the time range row is tapped to edit start/end times.
  final VoidCallback onEditTime;

  String _dateLabel(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    final enabled = exception?.enabled ?? true; // default ON when creating new
    final start = exception?.start ?? '09:00';
    final end   = exception?.end   ?? '17:00';

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateLabel(selectedDate),
                    style: text.titleMedium?.copyWith(
                      fontFamily: 'AnonymousPro',
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                // Toggle availability for just this specific date
                Row(
                  children: [
                    Text(enabled ? 'On' : 'Off', style: text.bodySmall),
                    const SizedBox(width: 6),
                    Switch(value: enabled, onChanged: onToggle),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            // When OFF, we dim the time row and disable the edit tap by not
            // invoking onEditTime. Still render the current/last range for clarity.
            InkWell(
              onTap: enabled ? onEditTime : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$start - $end',
                        style: text.bodyMedium?.copyWith(
                          color: enabled ? null : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 18, color: enabled ? cs.primary : cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: Date-specific overrides take precedence over your weekly rules.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
