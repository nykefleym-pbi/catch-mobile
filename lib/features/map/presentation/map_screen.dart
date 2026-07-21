import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../catdex/data/cats_repository.dart';
import '../../catdex/domain/cat.dart';
import '../data/location_service.dart';

/// Warms the near-white CARTO Positron raster tiles into a soft cream
/// "storybook" palette AND deepens them a touch: the previous matrix lifted
/// the midtones, which washed Positron's already-pale land to pure white and
/// swallowed the faint road linework. These negative offsets pull the land
/// down to a warm cream while the white roads stay lighter, so the streets
/// read as pale lines again instead of vanishing.
const _cozyMapMatrix = <double>[
  0.95, 0.06, 0.02, 0, -14, //
  0.05, 0.94, 0.03, 0, -18, //
  0.03, 0.07, 0.85, 0, -26, //
  0, 0, 0, 1, 0, //
];

/// Cozy exploration map — a "memory map" of where you met each cat. Renders free
/// OpenStreetMap tiles (no API key), drops a pin for every caught cat that has a
/// coarse location, and can recenter on the player. Tapping a cat opens its
/// detail + care page.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  // A gentle default until we know where the player (or their cats) are.
  static const LatLng _fallbackCenter = LatLng(37.7749, -122.4194);

  final MapController _controller = MapController();
  LatLng? _me;
  bool _locating = false;
  // How many located cats we last framed the camera around, so we auto-fit once
  // when they load without fighting the player as they pan.
  int _fittedCatCount = -1;

  @override
  void initState() {
    super.initState();
    // Best-effort: try to center on the player once the map is on screen.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _locate(moveMap: true));
  }

  Future<void> _locate({required bool moveMap}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.latLng != null) _me = result.latLng;
    });
    if (result.latLng != null) {
      if (moveMap) _controller.move(result.latLng!, 17);
    } else if (result.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  /// Frame the camera around the located cats the first time they appear (or
  /// when their number changes), including the player if we know where they are.
  void _maybeFitToCats(List<Cat> located) {
    if (located.isEmpty || located.length == _fittedCatCount) return;
    _fittedCatCount = located.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = <LatLng>[
        for (final c in located) LatLng(c.lat!, c.lng!),
        if (_me != null) _me!,
      ];
      try {
        if (points.length == 1) {
          _controller.move(points.first, 17);
        } else {
          _controller.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(64),
              maxZoom: 18,
            ),
          );
        }
      } catch (_) {
        // The map may not be laid out yet on a very early frame; the next data
        // change (or the locate button) will reframe.
        _fittedCatCount = -1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = ref.watch(catsProvider).valueOrNull ?? const <Cat>[];
    final located = [for (final c in cats) if (c.hasLocation) c];
    _maybeFitToCats(located);

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _me ??
                  (located.isNotEmpty
                      ? LatLng(located.first.lat!, located.first.lng!)
                      : _fallbackCenter),
              // Neighbourhood-level default — closer/more focused than a city view.
              initialZoom: 15,
              minZoom: 3,
              // Let players zoom all the way in to street level; CARTO raster
              // tiles serve up to z20.
              maxZoom: 20,
            ),
            children: [
              // Cozy re-theme: the default OpenStreetMap raster tiles are cold
              // and utilitarian, so we warm them into a soft pastel "storybook"
              // palette with a colour matrix — honouring the cozy-map art
              // direction while keeping the free, key-less raster tiles (a full
              // MapLibre vector-tile theme is a larger, provider-keyed follow-up).
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_cozyMapMatrix),
                child: TileLayer(
                  // CARTO Positron: a clean, minimal "basic" basemap (soft roads,
                  // few labels) rather than OSM's dense street detail — warmed by
                  // the cozy colour matrix above. Free, key-less raster tiles.
                  // A single CDN subdomain is baked in to avoid flutter_map's
                  // deprecated `subdomains` field.
                  urlTemplate:
                      'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.catch_mobile',
                ),
              ),
              MarkerLayer(
                markers: [
                  for (final cat in located)
                    Marker(
                      point: LatLng(cat.lat!, cat.lng!),
                      width: 96,
                      height: 92,
                      // Anchor the pin near the sprite so its base sits on spot.
                      alignment: Alignment.topCenter,
                      child: _CatPin(
                        cat: cat,
                        onTap: () => context.push(
                          AppRoutes.catDetailPath(cat.id),
                          extra: cat,
                        ),
                      ),
                    ),
                ],
              ),
              if (_me != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _me!,
                      width: 46,
                      height: 46,
                      child: _MeMarker(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
            ],
          ),
          // A soft warm vignette frames the map cozily (transparent centre so
          // pins stay crisp) — a gentle "golden hour" wash over the tiles.
          const Positioned.fill(
            child: IgnorePointer(child: _MapVignette()),
          ),
          // Top-center "memory map" pill.
          Positioned(
            top: topPad + 12,
            left: 0,
            right: 0,
            child: const Center(child: _MapHeaderPill()),
          ),
          Positioned(
            left: 8,
            bottom: bottomPad + 4,
            child: const _Attribution(),
          ),
          // Bottom controls: locate button above the hint card (matches design).
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPad + 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _LocateButton(
                    locating: _locating,
                    onTap: _locating ? null : () => _locate(moveMap: true),
                  ),
                ),
                const SizedBox(height: 10),
                _HintBanner(catCount: located.length),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft warm vignette over the tiles — transparent in the middle so pins and
/// the player stay crisp, deepening to a gentle warm shade at the edges.
class _MapVignette extends StatelessWidget {
  const _MapVignette();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final edge = (isLight ? AppTheme.ink : Colors.black)
        .withValues(alpha: isLight ? 0.12 : 0.28);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, edge],
          stops: const [0.68, 1.0],
        ),
      ),
    );
  }
}

/// A caught cat on the map: its pixel sprite in a soft white "photo" circle
/// with a little diamond pointer and a name label below — the design's memory-
/// map pin. Tappable through to the cat's detail page.
class _CatPin extends StatelessWidget {
  const _CatPin({required this.cat, required this.onTap});

  final Cat cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final shadow = [
      BoxShadow(
        color: AppTheme.ink.withValues(alpha: 0.22),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
              boxShadow: shadow,
            ),
            child: cat.spriteUrl == null
                ? Icon(Icons.pets, color: theme.colorScheme.primary, size: 24)
                : Image.network(
                    cat.spriteUrl!,
                    fit: BoxFit.contain,
                    // Crisp nearest-neighbour scaling for pixel-art sprites.
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) => Icon(Icons.pets,
                        color: theme.colorScheme.primary, size: 24),
                  ),
          ),
          // Little diamond pointer so the pin reads as "here".
          Transform.translate(
            offset: const Offset(0, -6),
            child: Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(width: 11, height: 11, color: surface),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 92),
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: shadow,
            ),
            child: Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeMarker extends StatelessWidget {
  const _MeMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

/// The little "memory map" pill floating at the top of the Explore screen.
class _MapHeaderPill extends StatelessWidget {
  const _MapHeaderPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Your memory map',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A soft white round "locate me" button matching the design (terracotta target).
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.locating, required this.onTap});

  final bool locating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: CircleBorder(side: BorderSide(color: theme.colorScheme.outline)),
      elevation: 2,
      shadowColor: AppTheme.ink.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: locating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.my_location,
                  size: 20, color: theme.colorScheme.tertiary),
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.catCount});

  final int catCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCats = catCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.peach,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(hasCats ? Icons.pets : Icons.travel_explore,
                size: 18, color: AppTheme.terracotta),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: hasCats
                ? Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      children: [
                        const TextSpan(text: "You've met "),
                        TextSpan(
                          text: '$catCount ${catCount == 1 ? 'cat' : 'cats'}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: ' here — tap a pin to visit.'),
                      ],
                    ),
                  )
                : Text(
                    'Walk your neighbourhood to meet cats — each one you '
                    'catch pins here.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '© OpenStreetMap contributors © CARTO',
          style: TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );
  }
}
