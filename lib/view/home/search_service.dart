import 'dart:async';

import 'package:flutter/material.dart';

class SearchCategory extends StatefulWidget {
  const SearchCategory({super.key});

  @override
  State<SearchCategory> createState() => _SearchCategoryState();
}

class _SearchCategoryState extends State<SearchCategory> {
  static const List<String> _kOptions = <String>[
    'Home Cleaning',
    'Plumbing',
    'Moving',
    'Planning'
  ];

  FutureOr<Iterable<String>> _searchService(TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim().toLowerCase();
    if (query.isEmpty) {
      // Show all options when empty so the user sees suggestions immediately
      return Iterable<String>.empty();
    }
    return _kOptions.where((opt) => opt.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue tev) => _searchService(tev),
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          return TextField(
            controller: textController,
            focusNode: focusNode,
            onSubmitted: (val) => onFieldSubmitted(),
            decoration: InputDecoration(
              hintText: 'Search services...',
              prefixIcon: const Icon(Icons.search),
              labelStyle: TextStyle(fontSize: 16),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  minWidth: 250,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(4),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.build_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        option,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        onSelected: (value) {
          FocusScope.of(context).unfocus();
          // TODO: trigger booking or navigation with `value`
        },
      ),
    );
  }
}
