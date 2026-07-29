import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../tutorial/presentation/first_run_tip.dart';
import '../data/cats_repository.dart';
import '../domain/cat.dart';
import 'cat_sprite.dart';

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
    // Match name or any private tag, so tags act as a personal filter.
    final filtered =
        q.isEmpty ? [...cats] : [for (final c in cats) if (c.matchesQuery(q)) c];
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppAssetImage(AppAssets.catDex, size: 30),
              const SizedBox(width: 8),
              Text('CatDex',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '$total ${total == 1 ? 'story' : 'stories'} & counting',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              // Scrapbook: opens the My Showcase board (replaces the old
              // "your journal awaits" caption).
              IconButton(
                onPressed: () => context.push(AppRoutes.showcase),
                visualDensity: VisualDensity.compact,
                tooltip: 'My showcase',
                icon: Icon(Icons.auto_stories_outlined,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
        FirstRunTip(
          screenId: 'catdex',
          message: AppLocalizations.of(context).tipCatdex,
        ),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        // IntrinsicHeight so the Column's Spacers get a bounded
                        // height and can vertically distribute the greeting +
                        // paw trail across the viewport.
                        child: const IntrinsicHeight(
                          child: _ScrapbookEmpty(),
                        ),
                      ),
                    ),
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
        // Long-press for the per-cat actions: private tags + the diary.
        onLongPress: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetCtx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Edit tags'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _TagEditorSheet(cat: cat),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Open diary'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    context.push(
                      AppRoutes.catDiary,
                      extra: (catId: cat.id, catName: cat.name),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
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
                child: CatSprite(url: cat.spriteUrl, size: 56),
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

/// First-run empty state for the CatDex — a gentle nudge toward the camera, with
/// a trail of paw prints (small → large) stepping down to the Capture button.
class _ScrapbookEmpty extends StatelessWidget {
  const _ScrapbookEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        children: [
          // Center the greeting in the upper space…
          const Spacer(flex: 3),
          Text(
            "Let's meet your first fur-iend",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the paw button below to open the camera and say hi.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
          // …then let the paw trail step down to the raised Capture button.
          const _PawTrail(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A trail of paw prints growing small → large as it steps down and drifts
/// toward the raised Capture (camera) button in the bottom nav.
class _PawTrail extends StatelessWidget {
  const _PawTrail();

  // A gentle alternating walk straight down the centre, growing as it nears
  // the raised (centre) Capture button — so the trail reads as an arrow to it.
  static const _steps = [
    (size: 14.0, dx: -10.0, angle: -0.32),
    (size: 18.0, dx: 8.0, angle: 0.18),
    (size: 23.0, dx: -6.0, angle: -0.12),
    (size: 30.0, dx: 5.0, angle: 0.08),
    (size: 38.0, dx: -3.0, angle: -0.05),
    (size: 46.0, dx: 0.0, angle: 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Transform.translate(
              offset: Offset(_steps[i].dx, 0),
              child: Transform.rotate(
                angle: _steps[i].angle,
                child: Icon(
                  Icons.pets,
                  size: _steps[i].size,
                  color: AppTheme.terracotta.withValues(alpha: 0.30 + i * 0.14),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A bottom sheet for editing a cat's **private** tags. Owner-only, never
/// shared — a personal way to organise the CatDex (long-press a card to open).
class _TagEditorSheet extends ConsumerStatefulWidget {
  const _TagEditorSheet({required this.cat});

  final Cat cat;

  @override
  ConsumerState<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<_TagEditorSheet> {
  late final List<String> _tags = [...widget.cat.tags];
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  void _add() {
    final t = _controller.text.trim();
    _controller.clear();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() => _tags.add(t));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(catsRepositoryProvider).setTags(widget.cat.id, _tags);
      ref.invalidate(catsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save tags — please try again.")),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your tags for ${widget.cat.name}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Private to you — a personal way to organise your CatDex.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              if (_tags.isEmpty)
                Text(
                  'No tags yet.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _tags)
                      InputChip(
                        label: Text(t),
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Add a tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => unawaited(_save()),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
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
