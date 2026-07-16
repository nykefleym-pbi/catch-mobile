import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../application/capture_providers.dart';
import '../domain/cat_detector.dart';

/// The heart of Cat-ch: photograph a real cat, verify it on-device, and (soon)
/// send it off to become a companion (docs/architecture/07-ai-pipeline.md).
///
/// Phase 1: live camera + on-device ML Kit detection gate. Generation is wired
/// once the provider key is live in the `generate-companion` Edge Function.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage { initializing, permissionDenied, unavailable, ready, analyzing, result }

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _Stage _stage = _Stage.initializing;
  CatDetectionResult? _result;
  String? _capturedPath;
  String? _message;

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
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initCamera());
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
      _stage = _Stage.ready;
    });
  }

  void _onKeep() {
    // Generation is wired next (needs the provider key live in the Edge
    // Function). For now, acknowledge and return to the camera.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lovely catch! Bringing them to life is coming next.'),
      ),
    );
    _retake();
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
    }
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
