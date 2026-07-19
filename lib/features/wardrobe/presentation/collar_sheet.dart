import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/collar.dart';

/// The wardrobe picker. Pops with the chosen collar id, the empty string to
/// mean "no collar", or null when dismissed without a choice. Locked collars
/// (above the cat's current bond tier) are shown but not selectable — a gentle
/// "keep caring" nudge, never a paywall.
class CollarSheet extends StatelessWidget {
  const CollarSheet({
    required this.bondIndex,
    required this.equippedId,
    super.key,
  });

  /// The cat's current bond-level index; collars unlock at or below it.
  final int bondIndex;
  final String? equippedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wardrobe', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Collars are cosmetic — earned by the bond you build, never bought.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _NoCollarTile(
                  selected: equippedId == null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final collar in kCollars)
                  _CollarTile(
                    collar: collar,
                    selected: equippedId == collar.id,
                    locked: collar.unlockIndex > bondIndex,
                    onTap: () => Navigator.of(context).pop(collar.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollarTile extends StatelessWidget {
  const _CollarTile({
    required this.collar,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final Collar collar;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Tile(
      selected: selected,
      accent: collar.color,
      onTap: locked ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: locked ? 0.4 : 1,
            child: Text(collar.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 6),
          Text(
            collar.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: locked
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    collar.unlockLabel,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoCollarTile extends StatelessWidget {
  const _NoCollarTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Tile(
      selected: selected,
      accent: theme.colorScheme.outline,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 30,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            'No collar',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared square tile chrome for the wardrobe grid.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 88,
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}
