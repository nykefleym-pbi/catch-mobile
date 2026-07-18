import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../care/data/care_repository.dart';
import '../../care/domain/care_state.dart';
import '../../care/domain/treat.dart';
import '../domain/cat.dart';

/// A single companion's page, styled from the "Cat-ch Mobile UI" design: a warm
/// hero with the (reactive) pixel sprite, an overlapping rounded sheet with the
/// cat's story, gentle gradient need-meters, a friendship hearts row, and the
/// care controls — feed + play — that grow a permanent bond with juicy feedback.
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
    return Scaffold(body: _CompanionBody(catId: catId, cat: cat));
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
    final cat = widget.cat;
    final care = ref.watch(careControllerProvider(widget.catId));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(cat, care.valueOrNull),
          Transform.translate(
            offset: const Offset(0, -28),
            child: _sheet(cat, care),
          ),
        ],
      ),
    );
  }

  // --- Hero: gradient panel + reactive sprite + back + mood badge -----------
  Widget _hero(Cat cat, CareState? care) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 300 + topPad,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isLight
                      ? const [Color(0xFFFBE3CD), Color(0xFFF7D9BC)]
                      : const [Color(0xFF3C332B), Color(0xFF2B2420)],
                ),
              ),
            ),
          ),
          // Reactive sprite with floaters.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: topPad, bottom: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (context, child) {
                      final scale = 1 + 0.12 * math.sin(math.pi * _bounce.value);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: _HeroSprite(cat: cat),
                  ),
                  for (final f in _floaters)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
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
                ],
              ),
            ),
          ),
          Positioned(
            top: topPad + 12,
            left: 16,
            child: _RoundIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (care != null)
            Positioned(
              right: 24,
              bottom: 44,
              child: _MoodBadge(mood: _titleCase(care.currentMood)),
            ),
        ],
      ),
    );
  }

  // --- Sheet: name, story, meters, bond, actions ---------------------------
  Widget _sheet(Cat cat, AsyncValue<CareState> care) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(cat.name,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (cat.traitLabel != null) _TraitChip(label: cat.traitLabel!),
            ],
          ),
          if (cat.blurb != null) ...[
            const SizedBox(height: 10),
            Text(
              cat.blurb!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _metaLine(cat),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          care.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SizedBox(
              height: 160,
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
        ],
      ),
    );
  }

  Widget _careBody(CareState state) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Meter(
          label: 'Hunger',
          status: _hungerStatus(state.currentHunger),
          value: state.currentHunger / 100,
          gradient: const [AppTheme.apricot, AppTheme.terracotta],
        ),
        const SizedBox(height: 14),
        _Meter(
          label: 'Happiness',
          status: _happyStatus(state.currentHappiness),
          value: state.currentHappiness / 100,
          gradient: const [AppTheme.sage, Color(0xFF8FB287)],
        ),
        const SizedBox(height: 16),
        _BondHearts(
          filled: Bond.levelIndexFor(state.friendship) + 1,
          total: Bond.levelCount,
          label: state.bondLabel,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _openTreatPicker,
                child: const Text('Feed'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonal(
                onPressed: _play,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                ),
                child: const Text('Play'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            state.bondIsMax
                ? 'Inseparable — the deepest bond 💛'
                : 'Away a while? ${widget.cat.name} just wants a little '
                    'attention — never guilt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _metaLine(Cat cat) {
    final parts = <String>[];
    if (cat.hasLocation) parts.add('Met nearby');
    if (cat.discoveredAt != null) parts.add(_formatDate(cat.discoveredAt!));
    return parts.isEmpty ? 'A treasured companion' : parts.join(' · ');
  }
}

// --- Small pieces ----------------------------------------------------------

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MoodBadge extends StatelessWidget {
  const _MoodBadge({required this.mood});

  final String mood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF6E8C66),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(mood,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.status,
    required this.value,
    required this.gradient,
  });

  final String label;
  final String status;
  final double value;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.brightness == Brightness.light
        ? const Color(0xFFF0E4D4)
        : const Color(0xFF3C332B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(status,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 12, color: track),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, v, _) => Container(
                    height: 12,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BondHearts extends StatelessWidget {
  const _BondHearts({
    required this.filled,
    required this.total,
    required this.label,
  });

  final int filled;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('Friendship',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              Icons.favorite,
              size: 15,
              color: i < filled
                  ? AppTheme.terracotta
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

class _HeroSprite extends StatelessWidget {
  const _HeroSprite({required this.cat});

  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cat.spriteUrl == null) {
      return Icon(Icons.pets, size: 96, color: theme.colorScheme.primary);
    }
    return Image.network(
      cat.spriteUrl!,
      width: 180,
      height: 180,
      fit: BoxFit.contain,
      // Crisp nearest-neighbour scaling for pixel-art sprites.
      filterQuality: FilterQuality.none,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const CircularProgressIndicator(),
      errorBuilder: (context, _, __) =>
          const Icon(Icons.broken_image_outlined, size: 72),
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
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('Pick a treat', style: theme.textTheme.titleLarge),
          ),
          for (final treat in kTreats)
            ListTile(
              leading: Text(treat.emoji, style: const TextStyle(fontSize: 28)),
              title: Text(treat.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text('+${treat.bond} bond'),
              trailing: Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.peach,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8C5A2E),
        ),
      ),
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

String _hungerStatus(int v) {
  if (v >= 85) return 'Full & happy';
  if (v >= 65) return 'Content';
  if (v >= 45) return 'Feeling snacky';
  return 'Hungry';
}

String _happyStatus(int v) {
  if (v >= 85) return 'Blissful';
  if (v >= 65) return 'Pretty content';
  if (v >= 45) return 'A bit restless';
  return 'Needs cheering';
}
