import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/app_router.dart';
import '../../catdex/data/cats_repository.dart';
import '../../catdex/domain/cat.dart';
import '../data/location_service.dart';

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
      if (moveMap) _controller.move(result.latLng!, 15);
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
          _controller.move(points.first, 15);
        } else {
          _controller.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(64),
              maxZoom: 16,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _me ??
                  (located.isNotEmpty
                      ? LatLng(located.first.lat!, located.first.lng!)
                      : _fallbackCenter),
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.catch_mobile',
              ),
              MarkerLayer(
                markers: [
                  for (final cat in located)
                    Marker(
                      point: LatLng(cat.lat!, cat.lng!),
                      width: 56,
                      height: 66,
                      // Anchor the pin's tip on the actual spot.
                      alignment: Alignment.topCenter,
                      child: _CatPin(
                        cat: cat,
                        color: theme.colorScheme.primary,
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
          const Positioned(
            left: 8,
            bottom: 8,
            child: _Attribution(),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: _HintBanner(catCount: located.length),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locating ? null : () => _locate(moveMap: true),
        tooltip: 'Locate me',
        child: _locating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }
}

/// A caught cat on the map: its sprite in a rounded "photo" pin with a little
/// pointer, tappable through to the cat's detail page.
class _CatPin extends StatelessWidget {
  const _CatPin({required this.cat, required this.color, required this.onTap});

  final Cat cat;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: ColoredBox(
                color: Colors.white,
                child: cat.spriteUrl == null
                    ? Icon(Icons.pets, color: color, size: 22)
                    : Image.network(
                        cat.spriteUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.pets, color: color, size: 22),
                      ),
              ),
            ),
          ),
          // Little downward pointer so the pin reads as "here".
          Transform.translate(
            offset: const Offset(0, -2),
            child: Icon(Icons.arrow_drop_down, color: color, size: 18),
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

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.catCount});

  final int catCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCats = catCount > 0;
    final message = hasCats
        ? 'You\'ve met $catCount ${catCount == 1 ? 'cat' : 'cats'} here — tap a '
            'pin to visit.'
        : 'Walk your neighbourhood to meet cats — each one you catch pins here.';
    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(hasCats ? Icons.pets : Icons.travel_explore,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
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
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );
  }
}
