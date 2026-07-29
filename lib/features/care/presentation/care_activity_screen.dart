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

/// A tactile, drop-to-care mini-game shared by Feed, Play, and Groom. Drag an
/// item onto the cat (or tap it) and a bespoke little animation plays on the
/// sprite — food is nibbled away with crumbs, a toy wiggles amid a burst of
/// hearts, bubbles foam up and pop into a clean shine. A semicircular gauge
/// shows where the cat is. When you finish, the session is persisted once: the
/// gauge becomes the relevant need, the bond deepens, and the gentle
/// side-effects apply — always floored so a cat is never left worse off
/// (welfare-wins). Care is cosmetic + kind, never power.
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

  @override
  void initState() {
    super.initState();
    _gauge = widget.startValue.toDouble().clamp(0, 100).toDouble();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _caption = _promptFor(widget.kind, widget.name);
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

  /// Leave the mini-game safely. Flip [_leaving] first so [PopScope.canPop] is
  /// already true by the time we pop — the pop is never re-intercepted (this is
  /// what previously crashed) — persist while still mounted, then pop once.
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
    final color = _colorFor(widget.kind, theme);
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
                      _RoundBack(onTap: _finish),
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
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: _Gauge(
                    value: _gauge / 100,
                    color: color,
                    zones: _zonesFor(widget.kind),
                  ),
                ),
                Expanded(
                  child: DragTarget<CareActivityItem>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) => _use(d.data),
                    builder: (context, candidate, __) {
                      final hovering = candidate.isNotEmpty;
                      return Center(
                        child: AnimatedScale(
                          scale: hovering ? 1.06 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                            width: 240,
                            height: 240,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _nudge,
                                  builder: (context, child) {
                                    final a = math.sin(
                                            _nudge.value * math.pi * 2) *
                                        0.04;
                                    return Transform.rotate(
                                        angle: a, child: child);
                                  },
                                  child: _Sprite(spriteUrl: widget.spriteUrl),
                                ),
                                if (_active != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: _ConsumeOverlay(
                                        key: ValueKey(_actionSeq),
                                        kind: widget.kind,
                                        item: _active!,
                                        accent: color,
                                        onDone: () => _clearAction(_actionSeq),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ),
                        ),
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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in widget.items)
                        _ItemChip(item: item, onTap: _use),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                  child: Text(
                    _sideNoteFor(widget.kind),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
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

  static String _sideNoteFor(CareActivityKind k) => switch (k) {
        CareActivityKind.feed =>
          'A good meal costs a little tidiness and leaves a sleepier cat.',
        CareActivityKind.play =>
          'Play works up an appetite and is happily tiring.',
        CareActivityKind.groom =>
          'A bath is tiring, and most cats only just tolerate it.',
      };

  static Color _colorFor(CareActivityKind k, ThemeData theme) => switch (k) {
        CareActivityKind.feed => AppTheme.terracotta,
        CareActivityKind.play => AppTheme.apricot,
        CareActivityKind.groom => theme.colorScheme.tertiary,
      };
}

// --- Gauge -----------------------------------------------------------------

/// A semicircular gauge with three labelled zones (low / mid / high) and a
/// needle at the current value. Reads as "Hungry → Content → Full" etc.
class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.value,
    required this.color,
    required this.zones,
  });

  final double value; // 0..1
  final Color color;
  final List<String> zones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value.clamp(0.0, 1.0);
    final activeZone = v < 1 / 3 ? 0 : (v < 2 / 3 ? 1 : 2);
    final track = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    return SizedBox(
      width: 220,
      child: Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: v),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          builder: (context, t, __) => CustomPaint(
            size: const Size(220, 116),
            painter: _GaugePainter(value: t, color: color, track: track),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < zones.length; i++)
              Expanded(
                child: Text(
                  zones[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == zones.length - 1
                          ? TextAlign.right
                          : TextAlign.center),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        i == activeZone ? FontWeight.w800 : FontWeight.w500,
                    color: i == activeZone
                        ? color
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value; // 0..1
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height - 2);
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    // Top semicircle: pi (left) sweeping +pi (clockwise, y-down) to 2pi (right).
    canvas.drawArc(rect, math.pi, math.pi, false, base);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, math.pi, math.pi * value.clamp(0.0, 1.0), false, fill);

    // Needle.
    final ang = math.pi + math.pi * value.clamp(0.0, 1.0);
    final tip = Offset(
      center.dx + math.cos(ang) * (radius - 2),
      center.dy + math.sin(ang) * (radius - 2),
    );
    final needle = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(center, 6, Paint()..color = color);
    canvas.drawCircle(
        center, 3, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
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
            x: 40 + _rng.nextDouble() * 30,
            y: 70 + _rng.nextDouble() * 30,
            fall: 60 + _rng.nextDouble() * 70,
            size: 6 + _rng.nextDouble() * 5,
            delay: 0.1 + _rng.nextDouble() * 0.5,
          ),
      ];

  List<_Heart> _makeHearts() => [
        for (var i = 0; i < 7; i++)
          _Heart(
            angle: -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2,
            dist: 70 + _rng.nextDouble() * 40,
            delay: _rng.nextDouble() * 0.4,
            size: 20 + _rng.nextDouble() * 12,
          ),
      ];

  // A 4x4 jittered grid so the whole 240-box sprite is covered.
  List<_Bubble> _makeBubbles() {
    final out = <_Bubble>[];
    const cols = 4, rows = 4;
    const box = 200.0, origin = 20.0;
    var order = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = origin + (c + 0.5) * (box / cols) + (_rng.nextDouble() - 0.5) * 14;
        final cy = origin + (r + 0.5) * (box / rows) + (_rng.nextDouble() - 0.5) * 14;
        out.add(_Bubble(
          cx: cx,
          cy: cy,
          r: 18 + _rng.nextDouble() * 8,
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
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: (1 - t).clamp(0.05, 1.0),
              child: Opacity(
                opacity: (1 - t * 0.25).clamp(0.0, 1.0),
                child: AppAssetImage(widget.item.asset, size: 64),
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
            padding: const EdgeInsets.only(top: 6),
            child: Transform.rotate(
              angle: wiggle,
              child: Opacity(
                opacity: toyOpacity,
                child: AppAssetImage(widget.item.asset, size: 60),
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
          _sparkle(const Offset(-46, -30), shine, 24),
          _sparkle(const Offset(50, -14), shine, 20),
          _sparkle(const Offset(6, 40), shine, 26),
          _sparkle(const Offset(-30, 44), shine, 18),
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
        // A round teardrop-ish drop.
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
      // A little highlight.
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

// --- Item chip -------------------------------------------------------------

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
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow(theme.brightness),
          ),
          child: AppAssetImage(item.asset, size: 38),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 62,
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
        offset: const Offset(-32, -32),
        child: AppAssetImage(item.asset, size: 64),
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
