import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_scaffold.dart';

/// Guardian profile: identity, settings, privacy controls, and (later) Guardian
/// rank/progress. Phase 0 placeholder.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Guardian',
      icon: Icons.person_outline,
      message: 'Your Guardian profile lives here.\n'
          'Kindness, not combat, earns your rank.',
    );
  }
}
