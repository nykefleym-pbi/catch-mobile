import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/generation/generation_client.dart';
import '../../catdex/data/cats_repository.dart';
import '../../catdex/domain/cat.dart';
import '../../map/data/location_service.dart';
import '../application/capture_providers.dart';
import '../domain/cat_detector.dart';

/// The heart of Cat-ch: photograph a real cat, verify it on-device, then send
/// it to the `generate-companion` Edge Function to become a collectible
/// companion (docs/architecture/07-ai-pipeline.md).
///
/// Stages: live camera → on-device ML Kit gate → generation → caught reveal →
/// CatDex.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage {
  initializing,
  permissionDenied,
  unavailable,
  ready,
  analyzing,
  result,
  generating,
  caught,
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _Stage _stage = _Stage.initializing;
  CatDetectionResult? _result;
  String? _capturedPath;
  String? _message;
  Cat? _caughtCat;
  // Best-effort "where you met them" lookup, kicked off the moment a cat is
  // spotted so it's ready by the time the player taps Keep. Never blocks a catch.
  Future<LocationResult>? _locationRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.dispose());
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Only revive the camera when it's the surface on screen; the result and
      // caught screens don't need it.
      final onCameraSurface =
          _stage == _Stage.ready || _stage == _Stage.initializing;
      if (onCameraSurface && _controller == null) {
        unawaited(_initCamera());
      }
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _stage = _Stage.permissionDenied);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _stage = _Stage.unavailable;
            _message = 'No camera found on this device.';
          });
        }
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _stage = _Stage.ready;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _Stage.unavailable;
          _message = 'Could not start the camera. Please try again.';
        });
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _stage = _Stage.analyzing);
    try {
      final photo = await controller.takePicture();
      final detector = ref.read(catDetectorProvider);
      final result = await detector.analyze(photo.path);
      if (!mounted) return;
      // Start locating now (while the player reviews the result) so the coarse
      // pin is ready at Keep — but only once we actually think it's a cat, to
      // avoid prompting for location on a miss.
      if (result.accepted) {
        _locationRequest = ref.read(locationServiceProvider).current();
      }
      setState(() {
        _capturedPath = photo.path;
        _result = result;
        _stage = _Stage.result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.ready;
        _message = 'Something went wrong taking that photo.';
      });
    }
  }

  void _retake() {
    setState(() {
      _result = null;
      _capturedPath = null;
      _caughtCat = null;
      _locationRequest = null;
      _stage = _Stage.ready;
    });
    // The camera may have been released (e.g. backgrounded during the result
    // screen); bring it back so the preview isn't a dead spinner.
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      unawaited(_initCamera());
    }
  }

  /// Send the accepted photo to the `generate-companion` Edge Function, which
  /// turns it into a companion and stores it in the CatDex.
  Future<void> _onKeep() async {
    final path = _capturedPath;
    final result = _result;
    if (path == null || result == null) return;

    setState(() => _stage = _Stage.generating);
    try {
      final bytes = await File(path).readAsBytes();
      // Resolve the coarse location if it's ready; a catch never waits long on
      // it — a slow GPS fix just means this cat lands without a map pin.
      LocationResult? location;
      try {
        location = await _locationRequest?.timeout(const Duration(seconds: 4));
      } catch (_) {
        location = null;
      }
      final cat = await ref.read(generationClientProvider).generate(
        imageBytes: bytes,
        detection: {
          'is_cat': result.isCat,
          'confidence': result.confidence,
        },
        lat: location?.latLng?.latitude,
        lng: location?.latLng?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _caughtCat = cat;
        _stage = _Stage.caught;
      });
    } on GenerationException catch (error) {
      _showGenerationError(error.message);
    } catch (_) {
      _showGenerationError(
        'Something went wrong bringing them to life. Please try again.',
      );
    }
  }

  void _showGenerationError(String message) {
    if (!mounted) return;
    setState(() => _stage = _Stage.result);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToCatDex() {
    ref.invalidate(catsProvider);
    context.go(AppRoutes.catdex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(context),
          // The caught reveal has its own warm background + navigation buttons,
          // so the dark camera-style close button would look out of place there.
          if (_stage != _Stage.caught)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _CircleButton(
                    icon: Icons.close,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.initializing:
      case _Stage.analyzing:
        return _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _stage == _Stage.analyzing
                    ? 'Checking for a cat…'
                    : 'Warming up the camera…',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      case _Stage.permissionDenied:
        return _MessagePane(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          body: 'Cat-ch needs the camera to meet cats. You can grant access in '
              'Settings.',
          primaryLabel: 'Open settings',
          onPrimary: () => unawaited(openAppSettings()),
        );
      case _Stage.unavailable:
        return _MessagePane(
          icon: Icons.error_outline,
          title: 'Camera unavailable',
          body: _message ?? 'The camera could not be started.',
          primaryLabel: 'Retry',
          onPrimary: () => unawaited(_initCamera()),
        );
      case _Stage.ready:
        return _buildPreview(context);
      case _Stage.result:
        return _buildResult(context);
      case _Stage.generating:
        return _buildGenerating(context);
      case _Stage.caught:
        return _buildCaught(context);
    }
  }

  Widget _buildGenerating(BuildContext context) {
    final path = _capturedPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null)
          Image.file(File(path), fit: BoxFit.cover)
        else
          const ColoredBox(color: Colors.black),
        Container(color: Colors.black.withValues(alpha: 0.55)),
        const _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Bringing your cat to life…',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                'This can take a few seconds.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaught(BuildContext context) {
    final cat = _caughtCat;
    if (cat == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          const Positioned.fill(child: _ConfettiDots()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'A new fur-iend!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.apricot,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Transform.rotate(
                          angle: 0.026, // a playful ~1.5° tilt, per the design
                          child: _RevealCard(cat: cat),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _goToCatDex,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSheet),
                            ),
                          ),
                          child: Text('See ${cat.name} in CatDex'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _retake,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(color: theme.colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSheet),
                            ),
                          ),
                          child: const Text('Catch another'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _Centered(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 0,
            height: controller.value.previewSize?.width ?? 0,
            child: CameraPreview(controller),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Point at a real cat and tap to catch',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ShutterButton(onPressed: () => unawaited(_capture())),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _result;
    final path = _capturedPath;
    if (result == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null)
          Image.file(File(path), fit: BoxFit.cover)
        else
          const ColoredBox(color: Colors.black),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: result.accepted
                  ? _ResultCard(
                      emoji: '😺',
                      title: 'It\'s a cat!',
                      body: 'On-device confidence '
                          '${(result.confidence * 100).round()}%. '
                          'Bringing them to life comes next.',
                      primaryLabel: 'Keep',
                      onPrimary: _onKeep,
                      secondaryLabel: 'Retake',
                      onSecondary: _retake,
                    )
                  : _ResultCard(
                      emoji: '🙈',
                      title: 'No cat spotted',
                      body: result.rejectionReason ??
                          'Point the camera at a real cat and try again.',
                      primaryLabel: 'Try again',
                      onPrimary: _retake,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// The reveal card: the new companion's sprite in a tinted circle, its name,
/// trait, story, and a small "met" line — styled from the Cat-ch design.
class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.cat});

  final Cat cat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final circleTint = theme.brightness == Brightness.light
        ? AppTheme.peach
        : const Color(0xFF463427);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(color: circleTint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: _BreathingSprite(url: cat.spriteUrl),
          ),
          const SizedBox(height: 14),
          Text(
            cat.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (cat.traitLabel != null) ...[
            const SizedBox(height: 10),
            _RevealTraitChip(label: cat.traitLabel!),
          ],
          if (cat.blurb != null) ...[
            const SizedBox(height: 12),
            Text(
              cat.blurb!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _revealMetaLine(cat),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sprite in the reveal circle, with a gentle continuous "breathing" scale.
class _BreathingSprite extends StatefulWidget {
  const _BreathingSprite({required this.url});

  final String? url;

  @override
  State<_BreathingSprite> createState() => _BreathingSpriteState();
}

class _BreathingSpriteState extends State<_BreathingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = widget.url;
    final Widget sprite = url == null
        ? Icon(Icons.pets, size: 88, color: theme.colorScheme.primary)
        : Image.network(
            url,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            // Crisp nearest-neighbour scaling for pixel-art sprites.
            filterQuality: FilterQuality.none,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(),
            errorBuilder: (context, _, __) => Icon(
                Icons.broken_image_outlined,
                size: 72,
                color: theme.colorScheme.onSurfaceVariant),
          );
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: sprite,
    );
  }
}

class _RevealTraitChip extends StatelessWidget {
  const _RevealTraitChip({required this.label});

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

/// A few soft decorative dots behind the reveal — a calm, confetti-lite touch.
class _ConfettiDots extends StatelessWidget {
  const _ConfettiDots();

  @override
  Widget build(BuildContext context) {
    Widget dot(double size, Color color, double opacity) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: 90, left: 34, child: dot(10, AppTheme.apricot, 0.5)),
          Positioned(top: 130, right: 48, child: dot(8, AppTheme.sage, 0.5)),
          Positioned(top: 210, right: 34, child: dot(9, AppTheme.apricot, 0.4)),
          Positioned(top: 180, left: 52, child: dot(7, AppTheme.terracotta, 0.4)),
          Positioned(
              bottom: 150, left: 40, child: dot(8, AppTheme.sage, 0.4)),
          Positioned(
              bottom: 190, right: 44, child: dot(10, AppTheme.apricot, 0.4)),
        ],
      ),
    );
  }
}

const _revealMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _revealMetaLine(Cat cat) {
  final parts = <String>[];
  parts.add(cat.hasLocation ? 'Met nearby' : 'A new companion');
  final at = cat.discoveredAt?.toLocal() ?? DateTime.now();
  parts.add('${_revealMonths[at.month - 1]} ${at.day}, ${at.year}');
  return parts.join(' · ').toUpperCase();
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: primary, width: 5),
        ),
        child: Icon(Icons.pets, color: primary, size: 32),
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String emoji;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryLabel != null && onSecondary != null) ...[
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
