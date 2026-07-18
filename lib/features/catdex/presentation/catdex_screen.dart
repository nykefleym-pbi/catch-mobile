import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/cats_repository.dart';
import '../domain/cat.dart';

/// The player's living collection of caught cats, backed by the `cats` table
/// (docs/architecture/06-data-model.md). Styled from the "Cat-ch Mobile UI"
/// design: a treasured scrapbook — big Fredoka title, a search field, filter
/// chips, and a warm grid of sprite cards.
class CatDexScreen extends ConsumerWidget {
  const CatDexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.hasSupabase) {
      return const Scaffold(
        body: SafeArea(
          child: _CatDexMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Offline build',
            body: 'This build has no backend configured, so caught cats can\'t '
                'be loaded.',
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _CatDexBody(onRefresh: () => ref.refresh(catsProvider.future)),
      ),
    );
  }
}

enum _CatFilter { all, trait, place, newest }

class _CatDexBody extends ConsumerStatefulWidget {
  const _CatDexBody({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_CatDexBody> createState() => _CatDexBodyState();
}

class _CatDexBodyState extends ConsumerState<_CatDexBody> {
  String _query = '';
  _CatFilter _filter = _CatFilter.all;

  List<Cat> _apply(List<Cat> cats) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? [...cats]
        : [for (final c in cats) if (c.name.toLowerCase().contains(q)) c];
    switch (_filter) {
      case _CatFilter.all:
        break;
      case _CatFilter.newest:
        filtered.sort((a, b) => (b.discoveredAt ?? DateTime(0))
            .compareTo(a.discoveredAt ?? DateTime(0)));
      case _CatFilter.trait:
        filtered.sort((a, b) =>
            (a.traitLabel ?? '~').compareTo(b.traitLabel ?? '~'));
      case _CatFilter.place:
        filtered.sort((a, b) {
          if (a.hasLocation == b.hasLocation) return 0;
          return a.hasLocation ? -1 : 1;
        });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = ref.watch(catsProvider);
    final total = cats.valueOrNull?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('CatDex',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                total == 0
                    ? 'your journal awaits'
                    : '$total ${total == 1 ? 'story' : 'stories'} & counting',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _SearchField(onChanged: (v) => setState(() => _query = v)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              for (final f in _CatFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: _filterLabel(f),
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: cats.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CatDexMessage(
              icon: Icons.error_outline,
              title: 'Couldn\'t load your cats',
              body: 'Pull down to try again.',
              onRetry: widget.onRefresh,
            ),
            data: (list) {
              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    children: const [
                      SizedBox(height: 80),
                      _CatDexMessage(
                        icon: Icons.pets_outlined,
                        title: 'No cats yet',
                        body: 'Tap the camera and catch your first cat —\n'
                            'they\'ll appear here as a page in your journal.',
                      ),
                    ],
                  ),
                );
              }
              final shown = _apply(list);
              if (shown.isEmpty) {
                return _CatDexMessage(
                  icon: Icons.search_off_outlined,
                  title: 'No matches',
                  body: 'No fur-iends match "$_query".',
                );
              }
              return RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _CatCard(cat: shown[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _filterLabel(_CatFilter f) => switch (f) {
        _CatFilter.all => 'All',
        _CatFilter.trait => 'By trait',
        _CatFilter.place => 'By place',
        _CatFilter.newest => 'Newest',
      };
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surface,
        hintText: 'Search your fur-iends…',
        hintStyle: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search,
            size: 20, color: theme.colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.cat});

  final Cat cat;

  // Soft, varied circle tints behind each sprite (from the design).
  static const _tints = [
    Color(0xFFFBE3CD),
    Color(0xFFEDE7DE),
    Color(0xFFE4DCD2),
    Color(0xFFDEEAD9),
    Color(0xFFF3E7D7),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = _tints[cat.id.hashCode.abs() % _tints.length];
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.catDetailPath(cat.id), extra: cat),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: cat.spriteUrl == null
                    ? Icon(Icons.pets, size: 34, color: theme.colorScheme.primary)
                    : Image.network(
                        cat.spriteUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Icon(Icons.pets,
                            size: 34, color: theme.colorScheme.primary),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (cat.traitLabel != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.peach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cat.traitLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8C5A2E),
                    ),
                  ),
                ),
              ],
              if (cat.hasLocation) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place,
                        size: 12, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      'Met nearby',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatDexMessage extends StatelessWidget {
  const _CatDexMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function()? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => onRetry!(),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
