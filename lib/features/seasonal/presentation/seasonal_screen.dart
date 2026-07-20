import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../nook/domain/decor.dart';
import '../../wardrobe/domain/collar.dart';
import '../domain/seasonal_event.dart';

/// A cozy "This season" screen — a celebratory, informational look at the
/// current seasonal theme and its featured cosmetics (roadmap p3e). Featured
/// items are already permanent members of their catalogues; this screen never
/// equips anything itself (that stays in the per-cat wardrobe/nook) and never
/// implies urgency — everything shown here is yours to keep, always.
class SeasonalScreen extends StatelessWidget {
  const SeasonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final event = activeSeasonalEvent(DateTime.now());
    final theme = Theme.of(context);
    final collars = [
      for (final id in event.featuredCollarIds)
        if (collarById(id) != null) collarById(id)!,
    ];
    final decor = [
      for (final id in event.featuredDecorIds)
        if (decorById(id) != null) decorById(id)!,
    ];

    return Scaffold(
      appBar: const AppBar(title: Text('This season')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SeasonHero(event: event),
            const SizedBox(height: 24),
            if (collars.isNotEmpty) ...[
              Text('Featured collars',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final collar in collars)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeaturedTile(
                    emoji: collar.emoji,
                    label: collar.label,
                    unlockLabel: collar.unlockLabel,
                    accent: collar.color,
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (decor.isNotEmpty) ...[
              Text('Featured cosmetics for the nook',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final item in decor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeaturedTile(
                    emoji: item.emoji,
                    label: item.label,
                    unlockLabel: item.unlockLabel,
                    accent: event.accent,
                  ),
                ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'Earned through care — yours to keep, always. Nothing here ever '
              'expires.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonHero extends StatelessWidget {
  const _SeasonHero({required this.event});

  final SeasonalEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: event.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            event.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            event.greeting,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single featured-item row: emoji, label, and a gentle unlock hint (since
/// unlocks are per-cat by bond — this screen only celebrates, never equips).
class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({
    required this.emoji,
    required this.label,
    required this.unlockLabel,
    required this.accent,
  });

  final String emoji;
  final String label;
  final String unlockLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reach $unlockLabel with a cat to unlock',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
