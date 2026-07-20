import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../care/data/care_repository.dart';
import '../../care/domain/care_state.dart';
import '../data/nook_repository.dart';
import '../domain/decor.dart';

/// A cat's cozy decorated room — the "nook" (roadmap p2d). Drag to place, tap
/// to rotate, long-press to tidy away. Decor is cosmetic and unlocked by the
/// bond you've built. In dark mode the room simply reads as night.
class NookScreen extends ConsumerStatefulWidget {
  const NookScreen({
    required this.catId,
    required this.name,
    this.spriteUrl,
    super.key,
  });

  final String catId;
  final String name;
  final String? spriteUrl;

  @override
  ConsumerState<NookScreen> createState() => _NookScreenState();
}

class _NookScreenState extends ConsumerState<NookScreen> {
  List<PlacedDecor> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(nookRepositoryProvider).fetch(widget.catId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _save() {
    // Fire-and-forget; the room already reflects the change optimistically.
    unawaited(ref.read(nookRepositoryProvider).save(widget.catId, _items));
  }

  void _add(DecorItem item) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _items.add(
        PlacedDecor(
          instanceId: DateTime.now().microsecondsSinceEpoch.toString(),
          itemId: item.id,
          x: 0.5,
          y: 0.6,
        ),
      );
    });
    _save();
  }

  void _rotate(PlacedDecor p) {
    setState(() => p.rot = (p.rot + 1) % 4);
    _save();
  }

  void _remove(PlacedDecor p) {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _items.remove(p));
    _save();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tidied away'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final friendship =
        ref.watch(careControllerProvider(widget.catId)).valueOrNull?.friendship ??
            0;
    final bondIndex = Bond.levelIndexFor(friendship);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  _RoundBack(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 8),
                  Text(
                    "${widget.name}'s nook",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Drag to place · tap to rotate · long-press to tidy away',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _room(theme, isLight)),
            _palette(theme, bondIndex),
          ],
        ),
      ),
    );
  }

  Widget _room(ThemeData theme, bool isLight) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? const [Color(0xFFFBF1E4), Color(0xFFF3E0CC)]
                  : const [Color(0xFF2B2420), Color(0xFF1C1713)],
            ),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final h = c.maxHeight;
                    return Stack(
                      children: [
                        // A soft floor band for a little depth.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: h * 0.32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: (isLight ? AppTheme.ink : Colors.black)
                                  .withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: const Alignment(0, 0.15),
                            child: _NookSprite(spriteUrl: widget.spriteUrl),
                          ),
                        ),
                        if (_items.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Tap decor below to make '
                                '${widget.name} cozy.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        for (final p in _items)
                          Positioned(
                            left: (p.x * w) - 30,
                            top: (p.y * h) - 30,
                            child: GestureDetector(
                              onTap: () => _rotate(p),
                              onLongPress: () => _remove(p),
                              onPanUpdate: (d) {
                                setState(() {
                                  p.x = (p.x + d.delta.dx / w).clamp(0.05, 0.95);
                                  p.y = (p.y + d.delta.dy / h).clamp(0.05, 0.95);
                                });
                              },
                              onPanEnd: (_) => _save(),
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: Center(
                                  child: Transform.rotate(
                                    angle: p.rot * math.pi / 2,
                                    child: Text(
                                      decorById(p.itemId)?.emoji ?? '❓',
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _palette(ThemeData theme, int bondIndex) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kDecor.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = kDecor[i];
          final locked = item.unlockIndex > bondIndex;
          return _PaletteChip(
            item: item,
            locked: locked,
            onTap: locked ? null : () => _add(item),
          );
        },
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.item,
    required this.locked,
    required this.onTap,
  });

  final DecorItem item;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusChip),
              ),
              child: locked
                  ? Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : Text(item.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 4),
            Text(
              locked ? item.unlockLabel : item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NookSprite extends StatelessWidget {
  const _NookSprite({required this.spriteUrl});

  final String? spriteUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (spriteUrl == null) {
      return Icon(Icons.pets, size: 110, color: theme.colorScheme.primary);
    }
    return Image.network(
      spriteUrl!,
      width: 150,
      height: 150,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const CircularProgressIndicator(),
      errorBuilder: (context, _, __) =>
          const Icon(Icons.broken_image_outlined, size: 72),
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
