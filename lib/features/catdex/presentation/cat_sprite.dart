import 'package:flutter/material.dart';

/// One canonical way to render a cat sprite, so every surface shows companions
/// at a consistent scale with the same graceful fallback — a paw, never a broken
/// image box (item 9a). Pixel-art sprites use nearest-neighbour scaling.
class CatSprite extends StatelessWidget {
  const CatSprite({
    super.key,
    required this.url,
    required this.size,
    this.fit = BoxFit.contain,
  });

  final String? url;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget fallback() => Icon(
          Icons.pets,
          size: size * 0.6,
          color: theme.colorScheme.primary,
        );

    final u = url;
    if (u == null || u.isEmpty) return fallback();
    return Image.network(
      u,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}
