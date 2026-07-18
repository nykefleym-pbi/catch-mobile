import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../care/data/care_repository.dart';
import '../../care/domain/care_state.dart';
import '../../care/domain/treat.dart';
import '../domain/cat.dart';

/// A single companion's page: the big (reactive) sprite, its trait and story,
/// and the care controls — feed + play — that raise a permanent friendship bond
/// and give juicy, animated feedback on every tap.
///
/// The [Cat] is passed via `GoRouter` `extra` when opened from the CatDex; a
/// deep link without it falls back to a gentle "open from your CatDex" prompt.
class CatDetailScreen extends StatelessWidget {
  const CatDetailScreen({required this.catId, this.cat, super.key});

  final String catId;
  final Cat? cat;

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      appBar: AppBar(title: Text(cat.name)),
      body: _CompanionBody(catId: catId, cat: cat),
    );
  }
}

class _CompanionBody extends ConsumerStatefulWidget {
  const _CompanionBody({required this.catId, required this.cat});

  final String catId;
  final Cat cat;

  @override
  ConsumerState<_CompanionBody> createState() => _CompanionBodyState();
}

class _CompanionBodyState extends ConsumerState<_CompanionBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  final List<_FloaterSpec> _floaters = [];
  final math.Random _random = math.Random();
  int _floaterSeq = 0;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _openTreatPicker() async {
    final treat = await showModalBottomSheet<Treat>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _TreatSheet(),
    );
    if (treat == null) return;
    await _feed(treat);
  }

  Future<void> _feed(Treat treat) {
    // The 'foodie' trait "gains extra affection from feeding" (0002 seed).
    final foodie = widget.cat.traitId == 'foodie';
    final bond = treat.bond + (foodie ? 1 : 0);
    return _runCare(
      floater: treat.emoji,
      action: () => ref.read(careControllerProvider(widget.catId).notifier).feed(
            bondGain: bond,
            happinessGain: treat.happiness,
          ),
      message: foodie
          ? '${widget.cat.name} devoured the ${treat.label}! ${treat.emoji}'
          : '${widget.cat.name} enjoyed ${treat.label} ${treat.emoji}',
    );
  }

  Future<void> _play() => _runCare(
        floater: '🧶',
        action: () =>
            ref.read(careControllerProvider(widget.catId).notifier).play(),
        message: '${widget.cat.name} had fun 🧶',
      );

  /// Shared care flow: haptic + sprite bounce + floating emoji, run the action,
  /// then a snackbar — celebrating a bond level-up when one happens.
  Future<void> _runCare({
    required String floater,
    required Future<void> Function() action,
    required String message,
  }) async {
    final provider = careControllerProvider(widget.catId);
    final before = ref.read(provider).valueOrNull?.friendship ?? 0;

    unawaited(HapticFeedback.lightImpact());
    unawaited(_bounce.forward(from: 0));
    _spawnFloater(floater);

    await action();
    if (!mounted) return;

    final after = ref.read(provider).valueOrNull?.friendship ?? before;
    final leveledUp = Bond.levelIndexFor(after) > Bond.levelIndexFor(before);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (leveledUp) {
      _spawnFloater('💛');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You and ${widget.cat.name} are now ${Bond.labelFor(after)}! 💛',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _spawnFloater(String emoji) {
    final id = _floaterSeq++;
    final dx = (_random.nextDouble() * 64) - 32;
    setState(() => _floaters.add(_FloaterSpec(id: id, emoji: emoji, dx: dx)));
  }

  void _removeFloater(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = widget.cat;
    final care = ref.watch(careControllerProvider(widget.catId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _spriteStack(cat),
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
        _careCard(care),
      ],
    );
  }

  Widget _spriteStack(Cat cat) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final scale = 1 + 0.12 * math.sin(math.pi * _bounce.value);
            return Transform.scale(scale: scale, child: child);
          },
          child: _SpritePanel(cat: cat),
        ),
        for (final f in _floaters)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Transform.translate(
                    offset: Offset(f.dx, 0),
                    child: _Floater(
                      key: ValueKey(f.id),
                      emoji: f.emoji,
                      onDone: () => _removeFloater(f.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _careCard(AsyncValue<CareState> care) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: care.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Couldn't load care status."),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(careControllerProvider(widget.catId).notifier)
                        .load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: _careBody,
        ),
      ),
    );
  }

  Widget _careBody(CareState state) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Bond', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              state.bondLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: state.bondProgress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 14,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          state.bondIsMax
              ? 'Inseparable — the deepest bond 💛'
              : 'Feed and play to grow your bond.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Divider(height: 28),
        Row(
          children: [
            Text('Today', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              _titleCase(state.currentMood),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
          color: theme.colorScheme.secondary,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _openTreatPicker,
                icon: const Icon(Icons.restaurant),
                label: const Text('Feed'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _play,
                icon: const Icon(Icons.sports_esports),
                label: const Text('Play'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FloaterSpec {
  const _FloaterSpec({required this.id, required this.emoji, required this.dx});

  final int id;
  final String emoji;
  final double dx;
}

/// A single emoji that drifts up and fades, then removes itself via [onDone].
class _Floater extends StatefulWidget {
  const _Floater({
    required super.key,
    required this.emoji,
    required this.onDone,
  });

  final String emoji;
  final VoidCallback onDone;

  @override
  State<_Floater> createState() => _FloaterState();
}

class _FloaterState extends State<_Floater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -130 * t),
            child: Transform.scale(
              scale: 0.8 + 0.6 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
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
                  // Crisp nearest-neighbour scaling for pixel-art sprites.
                  filterQuality: FilterQuality.none,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, _, __) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 56),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The treat menu shown when the player taps Feed. Tapping a treat pops the
/// sheet with the chosen [Treat].
class _TreatSheet extends StatelessWidget {
  const _TreatSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Pick a treat', style: theme.textTheme.titleLarge),
          ),
          for (final treat in kTreats)
            ListTile(
              leading: Text(treat.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(treat.label),
              subtitle: Text('+${treat.bond} bond'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(treat),
            ),
          const SizedBox(height: 8),
        ],
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
