import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../care/data/care_repository.dart';
import '../../care/domain/care_state.dart';
import '../domain/cat.dart';

/// A single companion's page: the big sprite, its trait and story, and the care
/// controls (feed + play) backed by the `care_state` table.
///
/// The [Cat] is passed via `GoRouter` `extra` when opened from the CatDex; a
/// deep link without it falls back to a gentle "open from your CatDex" prompt.
class CatDetailScreen extends ConsumerWidget {
  const CatDetailScreen({required this.catId, this.cat, super.key});

  final String catId;
  final Cat? cat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = this.cat;
    if (cat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Open this cat from your CatDex to see its page.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(cat.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SpritePanel(cat: cat),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(cat.name, style: theme.textTheme.headlineSmall),
              ),
              if (cat.traitLabel != null) _TraitChip(label: cat.traitLabel!),
            ],
          ),
          if (cat.blurb != null) ...[
            const SizedBox(height: 10),
            Text(
              cat.blurb!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (cat.discoveredAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Discovered ${_formatDate(cat.discoveredAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _CareCard(catId: catId, catName: cat.name),
        ],
      ),
    );
  }
}

class _SpritePanel extends StatelessWidget {
  const _SpritePanel({required this.cat});

  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: cat.spriteUrl == null
              ? const Center(child: Icon(Icons.pets, size: 72))
              : Image.network(
                  cat.spriteUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, _, __) =>
                      const Center(child: Icon(Icons.broken_image_outlined, size: 56)),
                ),
        ),
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
      ),
      backgroundColor: theme.colorScheme.primaryContainer,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The care panel: mood, the two need bars, and the feed/play actions.
class _CareCard extends ConsumerWidget {
  const _CareCard({required this.catId, required this.catName});

  final String catId;
  final String catName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final care = ref.watch(careControllerProvider(catId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: care.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SizedBox(
            height: 140,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Couldn't load care status."),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(careControllerProvider(catId).notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) => _CareBody(catId: catId, catName: catName, state: state),
        ),
      ),
    );
  }
}

class _CareBody extends ConsumerWidget {
  const _CareBody({
    required this.catId,
    required this.catName,
    required this.state,
  });

  final String catId;
  final String catName;
  final CareState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(careControllerProvider(catId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Care', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              _titleCase(state.currentMood),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NeedBar(
          icon: Icons.restaurant,
          label: 'Hunger',
          value: state.currentHunger,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        _NeedBar(
          icon: Icons.sentiment_very_satisfied,
          label: 'Happiness',
          value: state.currentHappiness,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _act(context, controller.feed, '$catName had a snack 🐟'),
                icon: const Icon(Icons.restaurant),
                label: const Text('Feed'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _act(context, controller.play, '$catName had fun 🧶'),
                icon: const Icon(Icons.sports_esports),
                label: const Text('Play'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _act(
    BuildContext context,
    Future<void> Function() action,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await action();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

class _NeedBar extends StatelessWidget {
  const _NeedBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(width: 78, child: Text(label, style: theme.textTheme.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
