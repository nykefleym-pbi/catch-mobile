import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/cats_repository.dart';
import '../domain/cat.dart';
import '../domain/collection_summary.dart';

/// A celebratory, read-only "showcase" of the player's own collection (roadmap
/// p3: "CatDex showcases"). It reads only the signed-in player's cats — there
/// is no cross-user surface here, so it needs no moderation. Sharing a showcase
/// *with a friend* is the opt-in, gated path that lives in the social hub; this
/// screen is the poster you'd be sharing, always yours to look at.
class ShowcaseScreen extends ConsumerWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My showcase')),
      body: SafeArea(
        top: false,
        child: cats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ShowcaseMessage(
            icon: Icons.error_outline,
            title: 'Couldn\'t load your showcase',
            body: 'Head back and try again in a moment.',
          ),
          data: (list) {
            final summary = CollectionSummary.fromCats(list);
            if (summary.isEmpty) {
              return const _ShowcaseMessage(
                icon: Icons.auto_awesome_outlined,
                title: 'Nothing to show just yet',
                body: 'Meet a few cats on your walks and your showcase will '
                    'fill in — every one a page worth showing off.',
              );
            }
            return _ShowcaseBody(summary: summary, cats: list);
          },
        ),
      ),
    );
  }
}

class _ShowcaseBody extends StatelessWidget {
  const _ShowcaseBody({required this.summary, required this.cats});

  final CollectionSummary summary;
  final List<Cat> cats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _CollectionHero(summary: summary),
        const SizedBox(height: 20),
        Text('At a glance',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                emoji: '🐾',
                value: '${summary.totalCats}',
                label: summary.totalCats == 1 ? 'companion' : 'companions',
                accent: AppTheme.apricot,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                emoji: '✨',
                value: '${summary.traitsCollected}/${summary.traitsKnown}',
                label: 'personalities',
                accent: AppTheme.sage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                emoji: '🗺️',
                value: '${summary.placesMet}',
                label: summary.placesMet == 1 ? 'place walked' : 'places walked',
                accent: AppTheme.terracotta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                emoji: '🎀',
                value: '${summary.collarsStyled}',
                label: summary.collarsStyled == 1 ? 'collar styled' : 'collars styled',
                accent: AppTheme.peach,
              ),
            ),
          ],
        ),
        if (summary.firstMet != null || summary.latestMet != null) ...[
          const SizedBox(height: 20),
          Text('Milestones',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (summary.firstMet != null)
            _MilestoneRow(
              icon: Icons.flag_outlined,
              label: 'First friend',
              catName: summary.firstMet!.name,
            ),
          if (summary.latestMet != null &&
              summary.latestMet!.id != summary.firstMet?.id) ...[
            const SizedBox(height: 10),
            _MilestoneRow(
              icon: Icons.favorite_outline,
              label: 'Newest arrival',
              catName: summary.latestMet!.name,
            ),
          ],
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This showcase is yours alone. Sharing it with a friend is '
                  'opt-in — turn it on in Friends & play, any time you like.',
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
    );
  }
}

class _CollectionHero extends StatelessWidget {
  const _CollectionHero({required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (summary.traitProgress * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.apricot.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        children: [
          const Text('📖', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            'A collection of ${summary.totalCats} '
            '${summary.totalCats == 1 ? 'story' : 'stories'}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.traitProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surface,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct% of personalities met — every walk adds a page.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accent,
  });

  final String emoji;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.icon,
    required this.label,
    required this.catName,
  });

  final IconData icon;
  final String label;
  final String catName;

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
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              catName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseMessage extends StatelessWidget {
  const _ShowcaseMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
