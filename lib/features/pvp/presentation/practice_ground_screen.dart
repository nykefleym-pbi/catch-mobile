import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/cat_stats.dart';
import '../domain/contest_readiness.dart';

/// A gentle, single-player "practice ground" (roadmap p3a/b groundwork). It
/// reads only the player's own cat — there is no opponent, no matchmaking, and
/// no score to chase — so it is safe to ship live while real contests stay
/// gated. Everything here is derived from [CatStats], which come only from care,
/// bond, growth, and personality: the honest, structural no-pay-to-win promise.
class PracticeGroundScreen extends StatelessWidget {
  const PracticeGroundScreen({
    super.key,
    required this.catName,
    required this.stats,
  });

  final String catName;
  final CatStats stats;

  static const _rows = [
    CatStat.agility,
    CatStat.speed,
    CatStat.confidence,
    CatStat.curiosity,
    CatStat.energy,
    CatStat.cuteness,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readiness = ContestReadiness.from(stats);
    return Scaffold(
      appBar: AppBar(title: const Text('Practice ground')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _ReadinessHero(readiness: readiness, catName: catName),
            const SizedBox(height: 20),
            _SignatureCard(readiness: readiness),
            const SizedBox(height: 20),
            Text('Warm-up drills',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final stat in _rows) ...[
              _DrillBar(
                label: statLabel(stat),
                value: stats[stat],
                highlight: stat == readiness.strongest,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            _NudgeCard(nudge: readiness.careNudge),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism_outlined,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Friendly contests with friends are coming — no battles, '
                      'nothing gets hurt, and never anything you can buy your '
                      'way through. This is just a cozy warm-up, all your own.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({required this.readiness, required this.catName});

  final ContestReadiness readiness;
  final String catName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.sage.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: readiness.overall / 100.0,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surface,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
                Text('${readiness.overall}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "$catName's readiness",
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            readiness.moodLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.readiness});

  final ContestReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.apricot.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signature event',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(readiness.signatureEvent,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Where ${statLabel(readiness.strongest).toLowerCase()} '
                  'really shines.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrillBar extends StatelessWidget {
  const _DrillBar({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100.0,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                highlight ? AppTheme.apricot : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text('$value',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudge});

  final String nudge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.peach.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          const Text('💛', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A gentle tip',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  nudge,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
