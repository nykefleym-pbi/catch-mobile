import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_scaffold.dart';

/// The player's living collection of discovered cats. Phase 1 populates this
/// from the `cats` / `catdex_entries` tables (see docs/architecture/06-data-model.md).
class CatDexScreen extends StatelessWidget {
  const CatDexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'CatDex',
      icon: Icons.collections_bookmark_outlined,
      message: 'Every cat you meet becomes a page here —\n'
          'a journal of real-world memories.',
    );
  }
}
