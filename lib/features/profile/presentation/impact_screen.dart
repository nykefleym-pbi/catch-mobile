import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../academy/data/academy_repository.dart';
import '../data/guardian_repository.dart';
import '../domain/impact_stats.dart';

/// "Impact so far" — a gentle, honest reflection of the player's own kindness.
///
/// Everything here is the player's own data (cats met, places explored, bond,
/// lessons learned). It deliberately shows **no** donation or "cats helped"
/// numbers — those are Phase 4 and only appear once they're real (ADR 0005).
class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final guardian = ref.watch(guardianProfileProvider);
    final lessons = ref.watch(academyProgressProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Impact so far')),
      body: SafeArea(
        child: guardian.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Come back in a moment — still tallying your kindness.',
                  textAlign: TextAlign.center),
            ),
          ),
          data: (g) {
            final stats = ImpactStats(
              catsMet: g.catsCount,
              placesExplored: g.placesExplored,
              bondShared: g.totalBond,
              lessonsLearned: lessons,
            );
            final cards = <_ImpactMetric>[
              (label: 'Cats met', value: stats.catsMet, icon: Icons.pets),
              (
                label: 'Places explored',
                value: stats.placesExplored,
                icon: Icons.place_outlined
              ),
              (
                label: 'Bond shared',
                value: stats.bondShared,
                icon: Icons.favorite_outline
              ),
              (
                label: 'Lessons learned',
                value: stats.lessonsLearned,
                icon: Icons.school_outlined
              ),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Text(
                  'The kindness you\'ve shared so far',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [for (final c in cards) _ImpactCard(metric: c)],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Text(
                    'This reflects your own journey so far. Real-world impact — '
                    'meals funded, cats helped through shelter partners — will '
                    'appear here only once it\'s real and we can prove it.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

typedef _ImpactMetric = ({String label, int value, IconData icon});

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.metric});

  final _ImpactMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, color: theme.colorScheme.primary, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${metric.value}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                metric.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
