import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_scaffold.dart';

/// Cozy exploration map. Phase 1 wires up Google Maps + location; for now this
/// is a themed placeholder so the shell and navigation are real.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Explore',
      icon: Icons.map_outlined,
      message: 'Walk your neighborhood to discover real cats.\n'
          'The cozy map arrives in Phase 1.',
    );
  }
}
