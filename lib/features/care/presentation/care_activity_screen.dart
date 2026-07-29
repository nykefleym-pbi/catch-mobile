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
    required this.gain,
    this.color = const Color(0xFFB98A5E),
    this.liquid = false,
    this.caption,
  });

  final String id;
  final String label;
  final String asset;

  /// How much this item raises the session gauge per drop.
  final int gain;

  /// The item's dominant colour — used by the feed mini-game to tint the bits
  /// that fall as it's eaten (drops for a liquid, crumbs for a solid).
  final Color color;

  /// Whether the item is a liquid (feed only) — falling bits are round drops
  /// instead of crumbly semicircles.
  final bool liquid;

  /// Optional warm line shown when this item is used.
  final String? caption;
}

// Warm gauge palette — the same "not-great → lovely" sweep reads for every
// activity (Hungry→Full, Sad→Happy, Dirty→Clean).
const _gaugeLow = Color(0xFFE8703A);
const _gaugeMid = Color(0xFFF2B950);
const _gaugeHigh = Color(0xFF67A860);

/// A cozy, tactile care mini-game shared by Feed, Play, and Groom. Drag an item
/// onto the cat (or tap it) and a bespoke animation plays on the sprite — food
/// is nibbled away with crumbs, a toy wiggles amid a burst of hearts, bubbles
/// foam up and pop into a clean shine. A gradient gauge shows where the cat is.
/// On finish the session persists once: the gauge becomes the relevant need,
/// the bond deepens, and the gentle side-effects apply — always floored so a
/// cat is never left worse off (welfare-wins). Care is cosmetic + kind, never
/// power.
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
  late final AnimationController _nudge;
  late double _gauge;
  int _bond = 0;
  bool _leaving = false;
  bool _committed = false;
  late String _caption;

  /// The item currently being consumed on the sprite, plus a nonce so each use
  /// remounts the overlay with fresh particles.
  CareActivityItem? _active;
  int _actionSeq = 0;

  /// The best (highest-gain) item — gets the little crown.
  late final String? _bestId;

  @override
  void initState() {
    super.initState();
    _gauge = widget.startValue.toDouble().clamp(0, 100).toDouble();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _caption = _promptFor(widget.kind, widget.name);
    _bestId = widget.items.isEmpty
        ? null
        : widget.items
            .reduce((a, b) => b.gain > a.gain ? b : a)
            .id;
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  void _use(CareActivityItem item) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(_nudge.forward(from: 0));
    setState(() {
      _gauge = (_gauge + item.gain).clamp(0, 100).toDouble();
      _caption = _gauge >= 100
          ? _fullFor(widget.kind, widget.name)
          : (item.caption ?? _promptFor(widget.kind, widget.name));
      if (_bond < widget.maxBond) _bond++;
      _active = item;
      _actionSeq++;
    });
  }

  void _clearAction(int seq) {
    if (!mounted || seq != _actionSeq) return;
    setState(() => _active = null);
  }

  /// Persist the session once (only if any care actually happened).
  Future<void> _commit() async {
    if (_committed) return;
    _committed = true;
    if (_bond > 0) {
      final notifier = ref.read(careControllerProvider(widget.catId).notifier);
      final value = _gauge.round();
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

  /// Leave safely. Flip [_leaving] first so [PopScope.canPop] is already true by
  /// the time we pop — the pop is never re-intercepted (this previously
  /// crashed) — persist while still mounted, then pop exactly once.
  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _commit();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final accent = _accentFor(widget.kind, theme);
    final zones = _zonesFor(widget.kind);
    final v = (_gauge / 100).clamp(0.0, 1.0);
    final zoneWord = v < 1 / 3 ? zones[0] : (v < 2 / 3 ? zones[1] : zones[2]);

    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? const [Color(0xFFFDEAD6), Color(0xFFF7D9BC)]
                  : const [Color(0xFF3C332B), Color(0xFF201A16)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _RoundBack(onTap: _finish),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleFor(widget.kind),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _subtitleFor(widget.kind),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable body (fits without scrolling on tall screens; the
                // scroll view only kicks in on small ones, so nothing overflows).
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        _GaugeCard(
                          value: v,
                          zoneWord: zoneWord,
                          lowWord: zones[0],
                          highWord: zones[2],
                          accent: accent,
                        ),
                        const SizedBox(height: 12),
                        _StageRow(
                          spriteUrl: widget.spriteUrl,
                          nudge: _nudge,
                          active: _active,
                          actionSeq: _actionSeq,
                          accent: accent,
                          kind: widget.kind,
                          tip: _sideNoteFor(widget.kind),
                          onDropAccept: _use,
                          onActionDone: () => _clearAction(_actionSeq),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _caption,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ItemCard(
                          title: _itemQuestionFor(widget.kind, widget.name),
                          items: widget.items,
                          bestId: _bestId,
                          accent: accent,
                          onUse: _use,
                        ),
                        const SizedBox(height: 12),
                        _LoveCard(
                          title: _loveTitleFor(widget.kind),
                          text: _loveTextFor(widget.kind, widget.name),
                          accent: accent,
                        ),
                      ],
                    ),
                  ),
                ),
                // Pinned CTA.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _CtaButton(
                    label: _bond > 0 ? 'All done!' : 'Maybe later',
                    onTap: _finish,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Per-kind copy ------------------------------------------------------

  static String _titleFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => 'Feeding time',
        CareActivityKind.play => 'Playtime',
        CareActivityKind.groom => 'Spa day',
      };

  static String _subtitleFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => 'A happy cat is a healthy cat! 🐾',
        CareActivityKind.play => 'Time to pounce and play! 🐾',
        CareActivityKind.groom => 'Fresh, fluffy, and pampered! 🐾',
      };

  /// The three gauge-zone labels (low → mid → high) for each activity.
  static List<String> _zonesFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => const ['Hungry', 'Content', 'Full'],
        CareActivityKind.play => const ['Sad', 'Content', 'Happy'],
        CareActivityKind.groom => const ['Dirty', 'Messy', 'Clean'],
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

  static String _itemQuestionFor(CareActivityKind k, String name) =>
      switch (k) {
        CareActivityKind.feed => 'What will you feed $name?',
        CareActivityKind.play => 'Pick a toy for $name!',
        CareActivityKind.groom => 'How will you pamper $name?',
      };

  static String _sideNoteFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed =>
          'A good meal costs a little tidiness and leaves a sleepier cat.',
        CareActivityKind.play =>
          'Play works up an appetite and is happily tiring.',
        CareActivityKind.groom =>
          'A bath is tiring, and most cats only just tolerate it.',
      };

  static String _loveTitleFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed => 'Feeding with love',
        CareActivityKind.play => 'Playing with love',
        CareActivityKind.groom => 'Grooming with love',
      };

  static String _loveTextFor(CareActivityKind k, String name) => switch (k) {
        CareActivityKind.feed =>
          'Regular, balanced meals keep $name healthy, active and full of joy!',
        CareActivityKind.play =>
          'Play keeps $name sharp, happy, and bonded to you!',
        CareActivityKind.groom =>
          'A gentle clean keeps $name fresh, comfy, and cared for!',
      };

  static Color _accentFor(CareActivityKind k, ThemeData theme) => switch (k) {
        CareActivityKind.feed => AppTheme.terracotta,
        CareActivityKind.play => AppTheme.apricot,
        CareActivityKind.groom => theme.colorScheme.tertiary,
      };
}

// --- Cards -----------------------------------------------------------------

/// A soft, rounded cream panel — the shared card chrome for this screen.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard + 6),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: child,
    );
  }
}

// --- Gauge -----------------------------------------------------------------

/// The gradient-arc gauge card: an orange→green scale with a heart marker at
/// the cat's current level, a zone pill, emoji end-labels, and a % read-out.
class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.value,
    required this.zoneWord,
    required this.lowWord,
    required this.highWord,
    required this.accent,
  });

  final double value; // 0..1
  final String zoneWord;
  final String lowWord;
  final String highWord;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
            builder: (context, v, __) => _Arc(value: v, zoneWord: zoneWord),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.sentiment_dissatisfied_rounded,
                  color: _gaugeLow, size: 20),
              const SizedBox(width: 6),
              Text(
                lowWord,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _gaugeLow,
                ),
              ),
              const Spacer(),
              Text(
                highWord,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _gaugeHigh,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.sentiment_satisfied_alt_rounded,
                  color: _gaugeHigh, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
            builder: (context, v, __) => _Slider(value: v, accent: accent),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${(value * 100).round()}% ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _gaugeHigh,
                ),
              ),
              TextSpan(
                text: highWord,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Arc extends StatelessWidget {
  const _Arc({required this.value, required this.zoneWord});

  final double value; // 0..1
  final String zoneWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = math.min(constraints.maxWidth, 300.0);
        final h = w * 0.52 + 8;
        final center = Offset(w / 2, h - 8);
        final radius = w / 2 - 16;
        final ang = math.pi + math.pi * value.clamp(0.0, 1.0);
        final mx = center.dx + math.cos(ang) * radius;
        final my = center.dy + math.sin(ang) * radius;
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _ArcPainter(
                  center: center,
                  radius: radius,
                  track: theme.colorScheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              // Zone pill, tucked under the apex.
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.44,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow(theme.brightness),
                    ),
                    child: Text(
                      zoneWord,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _gaugeMid,
                      ),
                    ),
                  ),
                ),
              ),
              // Heart marker riding the arc.
              Positioned(
                left: mx - 15,
                top: my - 15,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow(theme.brightness),
                  ),
                  child: const Icon(Icons.favorite,
                      color: Color(0xFFE86A6A), size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.center,
    required this.radius,
    required this.track,
  });

  final Offset center;
  final double radius;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Track (a touch wider, softer) behind the gradient.
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi, math.pi, false, base);

    final grad = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [_gaugeLow, _gaugeMid, _gaugeHigh],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi, false, grad);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.center != center || old.radius != radius || old.track != track;
}

class _Slider extends StatelessWidget {
  const _Slider({required this.value, required this.accent});

  final double value; // 0..1
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const knob = 18.0;
        final fillW = (w * v).clamp(0.0, w);
        final knobLeft = (w * v - knob / 2).clamp(0.0, w - knob);
        return SizedBox(
          height: knob,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 8,
                width: fillW,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: knobLeft,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 3),
                    boxShadow: AppTheme.cardShadow(theme.brightness),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Stage (sprite + drop target + tip) ------------------------------------

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.spriteUrl,
    required this.nudge,
    required this.active,
    required this.actionSeq,
    required this.accent,
    required this.kind,
    required this.tip,
    required this.onDropAccept,
    required this.onActionDone,
  });

  final String? spriteUrl;
  final AnimationController nudge;
  final CareActivityItem? active;
  final int actionSeq;
  final Color accent;
  final CareActivityKind kind;
  final String tip;
  final ValueChanged<CareActivityItem> onDropAccept;
  final VoidCallback onActionDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DragTarget<CareActivityItem>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) => onDropAccept(d.data),
            builder: (context, candidate, __) {
              final hovering = candidate.isNotEmpty;
              return AnimatedScale(
                scale: hovering ? 1.06 : 1,
                duration: const Duration(milliseconds: 160),
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: nudge,
                        builder: (context, child) {
                          final a = math.sin(nudge.value * math.pi * 2) * 0.04;
                          return Transform.rotate(angle: a, child: child);
                        },
                        child: _Sprite(spriteUrl: spriteUrl),
                      ),
                      if (active != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _ConsumeOverlay(
                              key: ValueKey(actionSeq),
                              kind: kind,
                              item: active!,
                              accent: accent,
                              onDone: onActionDone,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Tip bubble, tucked to the right.
          Positioned(
            right: 0,
            top: 24,
            child: _TipCard(text: tip),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.sage, size: 18),
              const SizedBox(width: 4),
              Text(
                'Tip',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Item card + tiles -----------------------------------------------------

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.title,
    required this.items,
    required this.bestId,
    required this.accent,
    required this.onUse,
  });

  final String title;
  final List<CareActivityItem> items;
  final String? bestId;
  final Color accent;
  final ValueChanged<CareActivityItem> onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final item in items)
                _ItemTile(
                  item: item,
                  best: item.id == bestId,
                  accent: accent,
                  onTap: onUse,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.best,
    required this.accent,
    required this.onTap,
  });

  final CareActivityItem item;
  final bool best;
  final Color accent;
  final ValueChanged<CareActivityItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                  boxShadow: AppTheme.cardShadow(theme.brightness),
                ),
                child: AppAssetImage(item.asset, size: 48),
              ),
              if (best)
                const Positioned(
                  top: -8,
                  right: -6,
                  child: _CrownBadge(),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${item.gain}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.favorite, size: 11, color: Color(0xFFE86A6A)),
              ],
            ),
          ),
        ],
      ),
    );
    return Draggable<CareActivityItem>(
      data: item,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: const Offset(-34, -34),
        child: AppAssetImage(item.asset, size: 68),
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

class _CrownBadge extends StatelessWidget {
  const _CrownBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF2B950),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.workspace_premium_rounded,
          size: 14, color: Colors.white),
    );
  }
}

// --- Love footer card ------------------------------------------------------

class _LoveCard extends StatelessWidget {
  const _LoveCard({
    required this.title,
    required this.text,
    required this.accent,
  });

  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.volunteer_activism_rounded,
                color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
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

// --- CTA -------------------------------------------------------------------

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.apricot, AppTheme.terracotta],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_border_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Consume overlays ------------------------------------------------------

/// Plays the kind-specific "item consumed" animation over the sprite, then
/// calls [onDone] so the parent can clear it.
class _ConsumeOverlay extends StatefulWidget {
  const _ConsumeOverlay({
    required super.key,
    required this.kind,
    required this.item,
    required this.accent,
    required this.onDone,
  });

  final CareActivityKind kind;
  final CareActivityItem item;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<_ConsumeOverlay> createState() => _ConsumeOverlayState();
}

class _ConsumeOverlayState extends State<_ConsumeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Bit> _bits;
  late final List<_Heart> _hearts;
  late final List<_Bubble> _bubbles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: widget.kind == CareActivityKind.groom ? 1900 : 1500),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
    _bits = widget.kind == CareActivityKind.feed ? _makeBits() : const [];
    _hearts = widget.kind == CareActivityKind.play ? _makeHearts() : const [];
    _bubbles = widget.kind == CareActivityKind.groom ? _makeBubbles() : const [];
  }

  List<_Bit> _makeBits() => [
        for (var i = 0; i < 8; i++)
          _Bit(
            fromLeft: i.isEven,
            x: 34 + _rng.nextDouble() * 26,
            y: 60 + _rng.nextDouble() * 26,
            fall: 55 + _rng.nextDouble() * 60,
            size: 6 + _rng.nextDouble() * 5,
            delay: 0.1 + _rng.nextDouble() * 0.5,
          ),
      ];

  List<_Heart> _makeHearts() => [
        for (var i = 0; i < 7; i++)
          _Heart(
            angle: -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2,
            dist: 60 + _rng.nextDouble() * 36,
            delay: _rng.nextDouble() * 0.4,
            size: 18 + _rng.nextDouble() * 12,
          ),
      ];

  // A 4x4 jittered grid so the whole sprite box is covered.
  List<_Bubble> _makeBubbles() {
    final out = <_Bubble>[];
    const cols = 4, rows = 4;
    const box = 176.0, origin = 17.0;
    var order = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx =
            origin + (c + 0.5) * (box / cols) + (_rng.nextDouble() - 0.5) * 12;
        final cy =
            origin + (r + 0.5) * (box / rows) + (_rng.nextDouble() - 0.5) * 12;
        out.add(_Bubble(
          cx: cx,
          cy: cy,
          r: 16 + _rng.nextDouble() * 7,
          popAt: 0.18 + (order / (cols * rows)) * 0.6,
        ));
        order++;
      }
    }
    return out;
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
        return switch (widget.kind) {
          CareActivityKind.feed => _buildFeed(t),
          CareActivityKind.play => _buildPlay(t),
          CareActivityKind.groom => _buildGroom(t),
        };
      },
    );
  }

  Widget _buildFeed(double t) {
    return Stack(
      children: [
        // The food at the top of the sprite, eaten away top→bottom.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: (1 - t).clamp(0.05, 1.0),
              child: Opacity(
                opacity: (1 - t * 0.25).clamp(0.0, 1.0),
                child: AppAssetImage(widget.item.asset, size: 58),
              ),
            ),
          ),
        ),
        // Crumbs / drops falling at the sides in the food's colour.
        Positioned.fill(
          child: CustomPaint(
            painter: _BitsPainter(
              progress: t,
              bits: _bits,
              color: widget.item.color,
              liquid: widget.item.liquid,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlay(double t) {
    final wiggle = t < 0.6 ? math.sin(t * math.pi * 8) * 0.28 : 0.0;
    final toyOpacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Transform.rotate(
              angle: wiggle,
              child: Opacity(
                opacity: toyOpacity,
                child: AppAssetImage(widget.item.asset, size: 54),
              ),
            ),
          ),
        ),
        for (final h in _hearts) _heartWidget(h, t),
      ],
    );
  }

  Widget _heartWidget(_Heart h, double t) {
    final local = ((t - h.delay) / (1 - h.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    final d = h.dist * Curves.easeOut.transform(local);
    final dx = math.cos(h.angle) * d;
    final dy = math.sin(h.angle) * d;
    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: (1 - local).clamp(0.0, 1.0),
          child: Text('💗', style: TextStyle(fontSize: h.size)),
        ),
      ),
    );
  }

  Widget _buildGroom(double t) {
    // Bubbles cover the sprite then pop one by one; a shine blooms once clean.
    final shine = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BubblesPainter(progress: t, bubbles: _bubbles),
          ),
        ),
        if (shine > 0)
          Positioned.fill(
            child: Opacity(
              opacity: shine,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.accent.withValues(alpha: 0.35),
                      const Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (shine > 0) ...[
          _sparkle(const Offset(-42, -28), shine, 22),
          _sparkle(const Offset(44, -12), shine, 18),
          _sparkle(const Offset(6, 36), shine, 24),
          _sparkle(const Offset(-26, 40), shine, 16),
        ],
      ],
    );
  }

  Widget _sparkle(Offset offset, double shine, double size) => Center(
        child: Transform.translate(
          offset: offset,
          child: Opacity(
            opacity: shine,
            child: Transform.scale(
              scale: 0.6 + 0.4 * shine,
              child: Text('✨', style: TextStyle(fontSize: size)),
            ),
          ),
        ),
      );
}

class _Bit {
  const _Bit({
    required this.fromLeft,
    required this.x,
    required this.y,
    required this.fall,
    required this.size,
    required this.delay,
  });

  final bool fromLeft;
  final double x; // inset from the side
  final double y; // start height
  final double fall;
  final double size;
  final double delay;
}

class _BitsPainter extends CustomPainter {
  _BitsPainter({
    required this.progress,
    required this.bits,
    required this.color,
    required this.liquid,
  });

  final double progress;
  final List<_Bit> bits;
  final Color color;
  final bool liquid;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final b in bits) {
      final local = ((progress - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final cx = b.fromLeft ? b.x : size.width - b.x;
      final cy = b.y + b.fall * local;
      paint.color = color.withValues(alpha: (1 - local).clamp(0.0, 1.0));
      final center = Offset(cx, cy);
      if (liquid) {
        // A round drop.
        canvas.drawCircle(center, b.size / 2, paint);
      } else {
        // A crumb: a semicircle (half disk).
        final r = Rect.fromCircle(center: center, radius: b.size / 2);
        canvas.drawArc(r, math.pi, math.pi, true, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BitsPainter old) =>
      old.progress != progress || old.color != color || old.liquid != liquid;
}

class _Heart {
  const _Heart({
    required this.angle,
    required this.dist,
    required this.delay,
    required this.size,
  });

  final double angle;
  final double dist;
  final double delay;
  final double size;
}

class _Bubble {
  const _Bubble({
    required this.cx,
    required this.cy,
    required this.r,
    required this.popAt,
  });

  final double cx;
  final double cy;
  final double r;
  final double popAt;
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter({required this.progress, required this.bubbles});

  final double progress;
  final List<_Bubble> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final appear = (progress / 0.12).clamp(0.0, 1.0);
      double radius;
      double alpha;
      if (progress < b.popAt) {
        radius = b.r * appear;
        alpha = 0.9;
      } else {
        final pop = ((progress - b.popAt) / 0.12).clamp(0.0, 1.0);
        if (pop >= 1) continue; // popped and gone
        radius = b.r * (1 + 0.6 * pop);
        alpha = 0.9 * (1 - pop);
      }
      if (radius <= 0) continue;
      final center = Offset(b.cx, b.cy);
      final body = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.55 * alpha),
            const Color(0xFFBFE3F5).withValues(alpha: 0.35 * alpha),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, body);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * alpha);
      canvas.drawCircle(center, radius, rim);
      canvas.drawCircle(
        center.translate(-radius * 0.3, -radius * 0.3),
        radius * 0.18,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.progress != progress;
}

// --- Sprite + back button --------------------------------------------------

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
      width: 180,
      height: 180,
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
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
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
