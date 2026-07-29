import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../data/care_repository.dart';

/// Which hands-on care mini-game this is.
enum CareActivityKind { feed, play, groom }

/// One draggable item in a care mini-game (a food, a toy, or a grooming tool).
@immutable
class CareActivityItem {
  const CareActivityItem({
    required this.id,
    required this.label,
    required this.asset,
    required this.particle,
    required this.particleRises,
    required this.gain,
    this.caption,
  });

  final String id;
  final String label;
  final String asset;

  /// The little glyph that bursts from the cat when this item lands.
  final String particle;

  /// Whether the particle floats up (bubbles, joy, shine) or falls (crumbs,
  /// nail bits, fur).
  final bool particleRises;

  /// How much this item raises the session meter per drop.
  final int gain;

  /// Optional warm line shown when this item is used.
  final String? caption;
}

/// A tactile, drag-to-care mini-game shared by Feed, Play, and Groom. Drag an
/// item onto the cat and a burst of particles plays; a meter fills toward
/// content. When you finish, the session is persisted once: the meter becomes
/// the relevant need, the bond deepens, and the gentle side-effects (a little
/// less sleep, etc.) are applied — always floored so a cat is never left worse
/// off (welfare-wins). Care is cosmetic + kind, never power.
class CareActivityScreen extends ConsumerStatefulWidget {
  const CareActivityScreen({
    required this.kind,
    required this.catId,
    required this.name,
    required this.items,
    required this.startValue,
    this.spriteUrl,
    this.maxBond = 3,
    super.key,
  });

  final CareActivityKind kind;
  final String catId;
  final String name;
  final List<CareActivityItem> items;

  /// The current value of the need this session fills (0–100).
  final int startValue;
  final String? spriteUrl;

  /// The most bond a single session can earn (kindness, not grinding).
  final int maxBond;

  @override
  ConsumerState<CareActivityScreen> createState() => _CareActivityScreenState();
}

class _CareActivityScreenState extends ConsumerState<CareActivityScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();
  int _seq = 0;
  late double _meter;
  int _bond = 0;
  bool _committed = false;
  late String _caption;

  @override
  void initState() {
    super.initState();
    _meter = widget.startValue.toDouble().clamp(0, 100).toDouble();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _caption = _promptFor(widget.kind, widget.name);
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _use(CareActivityItem item) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(_wiggle.forward(from: 0));
    setState(() {
      _meter = (_meter + item.gain).clamp(0, 100).toDouble();
      _caption = _meter >= 100
          ? _fullFor(widget.kind, widget.name)
          : (item.caption ?? _promptFor(widget.kind, widget.name));
      if (_bond < widget.maxBond) _bond++;
      for (var i = 0; i < 4; i++) {
        _particles.add(_Particle(
          id: _seq++,
          glyph: item.particle,
          rises: item.particleRises,
          dx: (_rng.nextDouble() * 150) - 75,
        ));
      }
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _particles.removeWhere((p) => p.id == id));
  }

  /// Persist the session once. Sets [_committed] so [PopScope.canPop] becomes
  /// true and the subsequent pop is allowed through instead of re-intercepted.
  Future<void> _commit() async {
    if (_committed) return;
    _committed = true;
    if (_bond > 0) {
      final notifier = ref.read(careControllerProvider(widget.catId).notifier);
      final value = _meter.round();
      switch (widget.kind) {
        case CareActivityKind.feed:
          await notifier.commitFeed(value, _bond);
        case CareActivityKind.play:
          await notifier.commitPlay(value, _bond);
        case CareActivityKind.groom:
          await notifier.commitGroom(value, _bond);
      }
    }
  }

  /// Leave the mini-game: commit, then pop (canPop is now true, so this pop is
  /// not re-intercepted by [PopScope]).
  Future<void> _exit() async {
    await _commit();
    if (!mounted) return;
    setState(() {}); // reflect _committed in canPop
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final full = _meter >= 100;
    return PopScope(
      canPop: _committed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? const [Color(0xFFFBE3CD), Color(0xFFF7D9BC)]
                  : const [Color(0xFF3C332B), Color(0xFF201A16)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      _RoundBack(onTap: _exit),
                      const SizedBox(width: 8),
                      Text(
                        _titleFor(widget.kind),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _Meter(
                    label: _meterLabelFor(widget.kind),
                    value: _meter / 100,
                    color: _colorFor(widget.kind, theme),
                    full: full,
                  ),
                ),
                Expanded(
                  child: DragTarget<CareActivityItem>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) => _use(d.data),
                    builder: (context, candidate, __) {
                      final hovering = candidate.isNotEmpty;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedScale(
                            scale: hovering ? 1.06 : 1,
                            duration: const Duration(milliseconds: 160),
                            child: AnimatedBuilder(
                              animation: _wiggle,
                              builder: (context, child) {
                                final a =
                                    math.sin(_wiggle.value * math.pi * 2) * 0.05;
                                return Transform.rotate(angle: a, child: child);
                              },
                              child: _Sprite(spriteUrl: widget.spriteUrl),
                            ),
                          ),
                          for (final p in _particles)
                            IgnorePointer(
                              child: Transform.translate(
                                offset: Offset(p.dx, 20),
                                child: _ParticleView(
                                  key: ValueKey(p.id),
                                  glyph: p.glyph,
                                  rises: p.rises,
                                  onDone: () => _remove(p.id),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _caption,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) =>
                        _ItemChip(item: widget.items[i], onTap: _use),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Text(
                    _sideNoteFor(widget.kind),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _exit,
                      child: Text(_bond > 0 ? 'All done' : 'Maybe later'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _titleFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => 'Feeding time',
        CareActivityKind.play => 'Playtime',
        CareActivityKind.groom => 'Spa day',
      };

  static String _meterLabelFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => 'Fullness',
        CareActivityKind.play => 'Happiness',
        CareActivityKind.groom => 'Freshness',
      };

  static String _promptFor(CareActivityKind k, String name) => switch (k) {
        CareActivityKind.feed => 'Drag a snack to $name.',
        CareActivityKind.play => 'Drag a toy over to $name.',
        CareActivityKind.groom => 'Drag a tool to pamper $name.',
      };

  static String _fullFor(CareActivityKind k, String name) => switch (k) {
        CareActivityKind.feed => '$name is happily full! 🐟',
        CareActivityKind.play => '$name had so much fun! 😻',
        CareActivityKind.groom => 'Squeaky clean and gleaming! ✨',
      };

  static String _sideNoteFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed =>
          'A good meal uses up a little energy and tidiness.',
        CareActivityKind.play => 'All that play is happily tiring.',
        CareActivityKind.groom => 'A spa session is relaxing but a bit tiring.',
      };

  static Color _colorFor(CareActivityKind k, ThemeData theme) => switch (k) {
        CareActivityKind.feed => AppTheme.terracotta,
        CareActivityKind.play => AppTheme.apricot,
        CareActivityKind.groom => theme.colorScheme.tertiary,
      };
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.color,
    required this.full,
  });

  final String label;
  final double value;
  final Color color;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              full ? 'Full!' : '${(value * 100).round()}%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 320),
            builder: (context, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item, required this.onTap});

  final CareActivityItem item;
  final ValueChanged<CareActivityItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow(theme.brightness),
          ),
          child: AppAssetImage(item.asset, size: 44),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    return Draggable<CareActivityItem>(
      data: item,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: const Offset(-36, -36),
        child: AppAssetImage(item.asset, size: 72),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: GestureDetector(
        onTap: () => onTap(item),
        behavior: HitTestBehavior.opaque,
        child: tile,
      ),
    );
  }
}

class _Sprite extends StatelessWidget {
  const _Sprite({required this.spriteUrl});

  final String? spriteUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (spriteUrl == null) {
      return Icon(Icons.pets, size: 120, color: theme.colorScheme.primary);
    }
    return Image.network(
      spriteUrl!,
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const CircularProgressIndicator(),
      errorBuilder: (context, _, __) =>
          const Icon(Icons.broken_image_outlined, size: 80),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onTap});

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
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.id,
    required this.glyph,
    required this.rises,
    required this.dx,
  });

  final int id;
  final String glyph;
  final bool rises;
  final double dx;
}

/// A single particle that drifts (up or down), fades, then removes itself.
class _ParticleView extends StatefulWidget {
  const _ParticleView({
    required super.key,
    required this.glyph,
    required this.rises,
    required this.onDone,
  });

  final String glyph;
  final bool rises;
  final VoidCallback onDone;

  @override
  State<_ParticleView> createState() => _ParticleViewState();
}

class _ParticleViewState extends State<_ParticleView>
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
        final dy = (widget.rises ? -120 : 120) * t;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: 0.7 + 0.5 * t,
              child: Text(widget.glyph, style: const TextStyle(fontSize: 30)),
            ),
          ),
        );
      },
    );
  }
}
