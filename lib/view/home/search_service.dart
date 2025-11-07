import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modern search with recent searches and rich suggestions.
///
/// Notes for future maintainers (ServeMe guidelines):
/// - We keep styling aligned with the app theme (no hard-coded colors except
///   for subtle dividers). Fonts and primary colors come from Theme.
/// - Recent searches are persisted with SharedPreferences so users see them
///   next time they open the app. We cap to 8 items and de-duplicate.
/// - The suggestions popup shows a "Recent" chip section (when query is empty)
///   and a "Suggestions" list filtered by the current query. Matching text is
///   highlighted to make scanning quicker.
class SearchCategory extends StatefulWidget {
  const SearchCategory({super.key});

  @override
  State<SearchCategory> createState() => _SearchCategoryState();
}

class _SearchCategoryState extends State<SearchCategory> {
  // Built-in demo options. Replace/extend with server-provided categories.
  static const List<String> _kOptions = <String>[
    'Home Cleaning',
    'Plumbing',
    'Moving',
    'Planning',
    'Electrical Repairs',
    'Gardening',
    'Painting',
    'Babysitting',
  ];

  // Persistent recent searches storage key
  static const String _kRecentKey = 'search_recent_terms_v1';

  // Local state
  List<String> _recent = <String>[]; // most-recent-first
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kRecentKey) ?? <String>[];
      setState(() => _recent = list);
    } catch (_) {/* ignore */}
  }

  Future<void> _saveRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentKey, _recent);
    } catch (_) {/* ignore */}
  }

  void _addRecent(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
      _recent.insert(0, t);
      if (_recent.length > 8) _recent = _recent.take(8).toList();
    });
    _saveRecents();
  }

  void _removeRecent(String term) {
    setState(() => _recent.removeWhere((e) => e.toLowerCase() == term.toLowerCase()));
    _saveRecents();
  }

  void _clearRecents() {
    setState(() => _recent.clear());
    _saveRecents();
  }

  FutureOr<Iterable<String>> _searchService(TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim();
    // Track the current query so the options view can decide what to show.
    _query = query;
    final q = query.toLowerCase();
    if (q.isEmpty) {
      // When empty, still return some popular suggestions so the popup has content.
      return _kOptions;
    }
    return _kOptions.where((opt) => opt.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue tev) => _searchService(tev),
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          // We add a clear button and gently rounded, pill-like shape.
          return TextField(
            controller: textController,
            focusNode: focusNode,
            // Close suggestions when the user taps anywhere outside the field
            // (unfocus will dismiss the Autocomplete overlay).
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onChanged: (v) => setState(() => _query = v), // keep query in sync
            onSubmitted: (val) {
              // Persist the submission as a recent search.
              _addRecent(val);
              onFieldSubmitted();
            },
            decoration: InputDecoration(
              hintText: 'Search services... ',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              // Clear input quickly
              suffixIcon: (textController.text.isEmpty)
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        setState(() => _query = '');
                        textController.clear();
                        // Keep focus so the user can type again immediately
                      },
                    ),
              labelStyle: const TextStyle(fontSize: 16),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          final opts = options.toList(growable: false);
          final showRecent = _query.trim().isEmpty && _recent.isNotEmpty;

          // Helper to render highlighted suggestion text for current query
          InlineSpan highlightText(String text, String query) {
            if (query.isEmpty) return TextSpan(text: text, style: theme.textTheme.bodyMedium);
            final q = query.toLowerCase();
            final t = text;
            final lower = t.toLowerCase();
            final idx = lower.indexOf(q);
            if (idx < 0) return TextSpan(text: text, style: theme.textTheme.bodyMedium);
            return TextSpan(
              children: [
                TextSpan(text: t.substring(0, idx), style: theme.textTheme.bodyMedium),
                TextSpan(
                  text: t.substring(idx, idx + q.length),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: t.substring(idx + q.length), style: theme.textTheme.bodyMedium),
              ],
            );
          }

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320, minWidth: 280),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  children: [
                    if (showRecent) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            Text('Recent', style: theme.textTheme.labelLarge),
                            const Spacer(),
                            TextButton(
                              onPressed: _clearRecents,
                              child: const Text('Clear all'),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recent.map((r) {
                            return InputChip(
                              label: Text(r),
                              onPressed: () => onSelected(r),
                              onDeleted: () => _removeRecent(r),
                              avatar: const Icon(Icons.history_rounded, size: 18),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 16),
                    ],

                    // Suggestions header (only if we have any suggestions)
                    if (opts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Text('Suggestions', style: theme.textTheme.labelLarge),
                      ),

                    // Suggestions list
                    ...List.generate(opts.length, (index) {
                      final option = opts[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.miscellaneous_services_rounded, size: 22, color: theme.colorScheme.primary),
                        title: RichText(text: highlightText(option, _query)),
                        onTap: () => onSelected(option),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
        onSelected: (value) {
          // Commit selection to recent list and close keyboard/popup.
          _addRecent(value);
          FocusScope.of(context).unfocus();
          // TODO: trigger booking or navigation with `value` (selected category)
        },
      ),
    );
  }
}
