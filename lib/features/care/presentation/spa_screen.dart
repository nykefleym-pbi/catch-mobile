import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/care_repository.dart';

/// A tactile, purely feel-good grooming session — the "Spa day" screen
/// (roadmap p2c). Pampering a cat freshens its hygiene and deepens the bond a
/// little (persisted once per visit, so it's a treat, never a farmable chore),
/// with lots of gentle sparkle feedback. Grooming is cosmetic + kind — never
/// power (docs/product/04-game-systems.md).
class SpaScreen extends ConsumerStatefulWidget {
  const SpaScreen({
    required this.catId,
    required this.name,
    this.spriteUrl,
    super.key,
  });

  final String catId;
  final String name;
  final String? spriteUrl;

  @override
  ConsumerState<SpaScreen> createState() => _SpaScreenState();
}

class _SpaScreenState extends ConsumerState<SpaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle;
  final List<_Spark> _sparks = [];
  final math.Random _rng = math.Random();
  int _seq = 0;
  bool _groomed = false;
  late String _caption;

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _caption = 'Pick a tool and pamper ${widget.name}.';
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _useTool(String caption, String emoji) async {
    unawaited(HapticFeedback.lightImpact());
    unawaited(_wiggle.forward(from: 0));
    setState(() {
      _caption = caption;
      for (var i = 0; i < 3; i++) {
        _sparks.add(
          _Spark(id: _seq++, emoji: emoji, dx: (_rng.nextDouble() * 130) - 65),
        );
      }
    });
    // The first pampering of the visit is the one that actually persists —
    // hygiene to full and a single bond point, so it's a treat, not a grind.
    if (!_groomed) {
      _groomed = true;
      await ref.read(careControllerProvider(widget.catId).notifier).groom();
    }
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _sparks.removeWhere((s) => s.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Scaffold(
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
                    _RoundBack(onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 8),
                    Text(
                      'Spa day',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _wiggle,
                      builder: (context, child) {
                        final a = math.sin(_wiggle.value * math.pi * 2) * 0.05;
                        return Transform.rotate(angle: a, child: child);
                      },
                      child: _SpaSprite(spriteUrl: widget.spriteUrl),
                    ),
                    for (final s in _sparks)
                      IgnorePointer(
                        child: Transform.translate(
                          offset: Offset(s.dx, 30),
                          child: _SparkView(
                            key: ValueKey(s.id),
                            emoji: s.emoji,
                            onDone: () => _remove(s.id),
                          ),
                        ),
                      ),
                  ],
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToolButton(
                      icon: Icons.brush_outlined,
                      label: 'Brush',
                      onTap: () =>
                          _useTool("Slow strokes — she's purring ♥", '✨'),
                    ),
                    _ToolButton(
                      icon: Icons.water_drop_outlined,
                      label: 'Bathe',
                      onTap: () => _useTool('All squeaky clean 🫧', '💧'),
                    ),
                    _ToolButton(
                      icon: Icons.content_cut,
                      label: 'Claws',
                      onTap: () =>
                          _useTool('A tiny manicure — so dignified', '✨'),
                    ),
                    _ToolButton(
                      icon: Icons.hearing_outlined,
                      label: 'Ears',
                      onTap: () => _useTool('Ears all tidy now', '✨'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(_groomed ? 'All done' : 'Maybe later'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaSprite extends StatelessWidget {
  const _SpaSprite({required this.spriteUrl});

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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow(theme.brightness),
            ),
            child: Icon(icon, color: theme.colorScheme.tertiary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
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

class _Spark {
  const _Spark({required this.id, required this.emoji, required this.dx});

  final int id;
  final String emoji;
  final double dx;
}

/// A single sparkle that drifts up and fades, then removes itself.
class _SparkView extends StatefulWidget {
  const _SparkView({
    required super.key,
    required this.emoji,
    required this.onDone,
  });

  final String emoji;
  final VoidCallback onDone;

  @override
  State<_SparkView> createState() => _SparkViewState();
}

class _SparkViewState extends State<_SparkView>
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
            offset: Offset(0, -120 * t),
            child: Transform.scale(
              scale: 0.7 + 0.6 * t,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
        );
      },
    );
  }
}
