import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
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
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'Caught!',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              Expanded(
                flex: 6,
                child: cat.spriteUrl == null
                    ? const Icon(Icons.pets, color: Colors.white70, size: 96)
                    : Image.network(
                        cat.spriteUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const _Centered(
                                    child: CircularProgressIndicator()),
                        errorBuilder: (context, _, __) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 72),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                cat.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              if (cat.traitLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  cat.traitLabel!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (cat.blurb != null) ...[
                const SizedBox(height: 12),
                Text(
                  cat.blurb!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Catch another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _goToCatDex,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('See in CatDex'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
