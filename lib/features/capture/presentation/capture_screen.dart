import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/generation/generation_client.dart';
import '../../catdex/data/cats_repository.dart';
import '../../catdex/domain/cat.dart';
import '../../map/data/location_service.dart';
import '../../safety/data/age_gate.dart';
import '../application/capture_providers.dart';
import '../domain/cat_detector.dart';

/// The heart of Cat-ch: photograph a real cat, verify it on-device, then send
/// it to the `generate-companion` Edge Function to become a collectible
/// companion (docs/architecture/07-ai-pipeline.md).
///
/// Stages: live camera → on-device ML Kit gate → generation → caught reveal →
/// CatDex. The viewfinder, detection copy, generating polaroid, and reveal are
/// styled from the "Cat-ch Mobile UI" design (turns 3 & 4).
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
      _logEvent(result.accepted
          ? AnalyticsEventName.captureSucceeded
          : AnalyticsEventName.captureRejected);
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

  /// "Retake photo" from the reveal: the companion was already generated and
  /// saved, so discard it (best-effort) before returning to the camera.
  Future<void> _discardAndRetake() async {
    final cat = _caughtCat;
    if (cat != null) {
      try {
        await ref.read(catsRepositoryProvider).delete(cat.id);
        ref.invalidate(catsProvider);
      } catch (_) {
        // Best-effort — a lingering companion can still be removed later.
      }
    }
    if (!mounted) return;
    _retake();
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
      _logEvent(AnalyticsEventName.generationSucceeded);
    } on GenerationException catch (error) {
      _showGenerationError(error.message);
    } catch (_) {
      _showGenerationError(
        'Something went wrong bringing them to life. Please try again.',
      );
    }
  }

  void _showGenerationError(String message) {
    _logEvent(AnalyticsEventName.generationFailed);
    if (!mounted) return;
    setState(() => _stage = _Stage.result);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Emit an anonymous, aggregate core-loop event. Carries no parameters — just
  /// that the step happened — and honours reduced-data mode for minors.
  void _logEvent(AnalyticsEventName event) {
    ref.read(analyticsProvider).log(
          event,
          reducedData: ref.read(ageBracketProvider).isMinor,
        );
  }

  void _goToCatDex() {
    ref.invalidate(catsProvider);
    context.go(AppRoutes.catdex);
  }

  @override
  Widget build(BuildContext context) {
    // The live viewfinder carries its own close button in the bottom row (beside
    // the shutter); warm-background panes (generating, caught reveal) provide
    // their own chrome. So the top-left close only shows on the message/result
    // panes, where there's no bottom control row to host it.
    final hasOwnClose = _stage == _Stage.ready ||
        _stage == _Stage.analyzing ||
        _stage == _Stage.caught ||
        _stage == _Stage.generating;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(context),
          if (!hasOwnClose)
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
        return const _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetImage(AppAssets.cameraArt, size: 96),
              SizedBox(height: 16),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Warming up the camera…',
                  style: TextStyle(color: Colors.white)),
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
      case _Stage.analyzing:
        return _buildPreview(context);
      case _Stage.result:
        return _buildResult(context);
      case _Stage.generating:
        return _buildGenerating(context);
      case _Stage.caught:
        return _buildCaught(context);
    }
  }

  // --- Viewfinder ------------------------------------------------------------

  Widget _buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _Centered(child: CircularProgressIndicator());
    }
    final analyzing = _stage == _Stage.analyzing;
    final frameColor = analyzing ? AppTheme.sage : AppTheme.apricot;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Meet a cat',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          // The live feed lives inside a cozy, contained viewfinder window
          // (rounded frame + corner brackets) rather than filling the screen.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
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
                    // Soft rounded frame border (calm apricot, sage while looking).
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: frameColor, width: 3),
                          ),
                        ),
                      ),
                    ),
                    _ViewfinderFrame(color: frameColor),
                    // Top hint pill.
                    const Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _HintPill(
                          text: 'Point at a cat — no flash, no rush',
                        ),
                      ),
                    ),
                    // Bottom status pill (the "checking" detection state).
                    if (analyzing)
                      const Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _StatusPill(
                            color: Color(0xFFFFFDF8),
                            textColor: AppTheme.ink,
                            dotColor: Color(0xFFD9A03F),
                            text: 'Looking gently…',
                            pulse: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 18),
            // Full-width row: the shutter stays centred (flanked by equal-width
            // Expandeds) while the close button pins to the far left, so the two
            // never overlap.
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child:
                          _CloseShutterButton(onPressed: () => context.pop()),
                    ),
                  ),
                ),
                _ShutterButton(
                  onPressed: analyzing ? null : () => unawaited(_capture()),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Detection result ------------------------------------------------------

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
        Container(color: Colors.black.withValues(alpha: 0.4)),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: result.accepted
                  ? _ResultSheet(
                      tone: _ResultTone.success,
                      title: "That's a cat! Hold steady…",
                      body: 'A lovely find. Ready to bring them to life?',
                      primaryLabel: 'Keep',
                      onPrimary: _onKeep,
                      secondaryLabel: 'Retake',
                      onSecondary: _retake,
                    )
                  : _ResultSheet(
                      tone: _ResultTone.retry,
                      title: 'Hmm, no whiskers found — try again?',
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

  // --- Generating (cozy polaroid) --------------------------------------------

  Widget _buildGenerating(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: const Stack(
        children: [
          Positioned.fill(child: _WanderingPaws()),
          Center(child: _GeneratingCard()),
        ],
      ),
    );
  }

  // --- Caught reveal ---------------------------------------------------------

  Widget _buildCaught(BuildContext context) {
    final cat = _caughtCat;
    if (cat == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          const Positioned.fill(child: _WanderingPaws()),
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
                            color: theme.colorScheme.tertiary,
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
                          child: Text('Keep ${cat.name}'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => unawaited(_discardAndRetake()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(color: theme.colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSheet),
                            ),
                          ),
                          child: const Text('Retake photo'),
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
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// Rounded viewfinder overlay with four corner brackets (idle apricot, success
/// sage) — the calm framing from the design's camera turn.
class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: 12, left: 12, child: _Corner(color: color, top: true, left: true)),
          Positioned(top: 12, right: 12, child: _Corner(color: color, top: true, left: false)),
          Positioned(bottom: 12, left: 12, child: _Corner(color: color, top: false, left: true)),
          Positioned(bottom: 12, right: 12, child: _Corner(color: color, top: false, left: false)),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.color, required this.top, required this.left});

  final Color color;
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const w = 3.5;
    final side = BorderSide(color: color, width: w);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: !top ? side : BorderSide.none,
          left: left ? side : BorderSide.none,
          right: !left ? side : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(10) : Radius.zero,
          topRight: top && !left ? const Radius.circular(10) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(10) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }
}

/// A dark translucent hint pill shown over the viewfinder.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF3E9DF),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// The kind detection status pill (checking / success / retry).
class _StatusPill extends StatefulWidget {
  const _StatusPill({
    required this.color,
    required this.textColor,
    required this.dotColor,
    required this.text,
    this.pulse = false,
  });

  final Color color;
  final Color textColor;
  final Color dotColor;
  final String text;
  final bool pulse;

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.dotColor),
    );
    if (widget.pulse) {
      dot = FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: dot,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The cozy generating polaroid — a shimmering "developing" card so the wait
/// reads as the companion coming to life, never a frozen screen.
class _GeneratingCard extends StatefulWidget {
  const _GeneratingCard();

  @override
  State<_GeneratingCard> createState() => _GeneratingCardState();
}

class _GeneratingCardState extends State<_GeneratingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  // Cozy reassurance copy that rotates while the companion is generated, so the
  // wait always feels alive (and never like a frozen screen). Advances every
  // 10 seconds; starts on a random line so repeat catches don't feel scripted.
  static const _messages = [
    'Getting to know them…',
    'Painting whiskers, one by one…',
    'Looking closely at those adorable eyes…',
    'Matching their unique fur pattern…',
    'Adding a little sparkle to their personality…',
    'Practicing their cutest pose…',
    'Fluffing every last tuft of fur…',
    'Capturing what makes them special…',
    'Writing the first page of their story…',
    'Making sure every pixel feels just right…',
    'Almost ready to meet your new friend…',
    'Putting on the finishing paw touches…',
    'Following tiny paw prints…',
    'Untangling a ball of yarn…',
    'Offering a tasty treat…',
    'Waiting for a curious sniff…',
    'Waking up sleepy whiskers…',
    'Picking the perfect colors…',
    'Capturing their best side…',
    "Giving them a name they'll love…",
    'Filling them with personality…',
    'One more happy purr…',
    'Straightening their little ears…',
    'Here they come…',
  ];

  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _messageIndex = DateTime.now().millisecondsSinceEpoch % _messages.length;
    _messageTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Transform.rotate(
      angle: -0.026,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: AppTheme.cardShadow(theme.brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Shimmer(
              controller: _c,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Shimmer(
              controller: _c,
              child: Container(
                width: 140,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Shimmer(
              controller: _c,
              child: Container(
                width: 190,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _messages[_messageIndex],
                // Key by index so AnimatedSwitcher cross-fades between lines.
                key: ValueKey(_messageIndex),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Every cat is uniquely generated, so it may take a little longer.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sweeps a soft warm highlight across its (opaque, white) child to fake the
/// classic content-loading shimmer, using the child's own shape as a mask.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = isLight ? const Color(0xFFF0E4D4) : const Color(0xFF3C332B);
    final highlight = isLight ? const Color(0xFFFBF3E8) : const Color(0xFF4A4038);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final slide = controller.value * 3 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(slide - 1, 0),
            end: Alignment(slide + 1, 0),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// The reveal card: the new companion's sprite filling a tinted circle, its
/// name, trait, backstory, and a small "met" line — from the Cat-ch design.
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
          ClipOval(
            child: Container(
              width: 160,
              height: 160,
              color: circleTint,
              alignment: Alignment.center,
              child: _BreathingSprite(url: cat.spriteUrl, size: 160),
            ),
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
          const SizedBox(height: 12),
          Text(
            cat.story,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
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

/// The sprite in the reveal circle — filling the frame, with a gentle
/// continuous "breathing" scale.
class _BreathingSprite extends StatefulWidget {
  const _BreathingSprite({required this.url, required this.size});

  final String? url;
  final double size;

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
        ? Icon(Icons.pets, size: widget.size * 0.5, color: theme.colorScheme.primary)
        : Image.network(
            url,
            width: widget.size,
            height: widget.size,
            // Fill the whole circular frame with the companion.
            fit: BoxFit.cover,
            // Crisp nearest-neighbour scaling for pixel-art sprites.
            filterQuality: FilterQuality.none,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(),
            errorBuilder: (context, _, __) => Icon(
                Icons.broken_image_outlined,
                size: widget.size * 0.45,
                color: theme.colorScheme.onSurfaceVariant),
          );
    return ScaleTransition(
      scale: Tween(begin: 0.98, end: 1.05).animate(
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

/// Soft paw prints scattered behind the generating polaroid and the reveal —
/// each a different size, gently drifting and fading in and out so the wait
/// (and the celebration) always feels alive, like little paws padding past.
/// Honours the platform reduce-motion setting (renders them still).
class _WanderingPaws extends StatefulWidget {
  const _WanderingPaws();

  @override
  State<_WanderingPaws> createState() => _WanderingPawsState();
}

class _WanderingPawsState extends State<_WanderingPaws>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Fractional position (-1..1), size, fade/drift phase, drift amount, tilt,
  // and a colour index — a hand-scattered spread of varied paw prints.
  static const _paws =
      <({double x, double y, double size, double phase, double drift, double angle, int color})>[
    (x: -0.72, y: -0.80, size: 15, phase: 0.00, drift: 10, angle: -0.4, color: 0),
    (x: 0.70, y: -0.66, size: 12, phase: 0.35, drift: 8, angle: 0.5, color: 1),
    (x: -0.58, y: -0.30, size: 23, phase: 0.60, drift: 12, angle: -0.2, color: 2),
    (x: 0.76, y: -0.10, size: 14, phase: 0.15, drift: 9, angle: 0.3, color: 0),
    (x: -0.82, y: 0.34, size: 18, phase: 0.80, drift: 11, angle: 0.15, color: 1),
    (x: 0.62, y: 0.48, size: 25, phase: 0.45, drift: 13, angle: -0.35, color: 0),
    (x: -0.34, y: 0.74, size: 13, phase: 0.25, drift: 8, angle: 0.4, color: 2),
    (x: 0.30, y: 0.82, size: 20, phase: 0.70, drift: 10, angle: -0.1, color: 1),
  ];

  static const _colors = [AppTheme.apricot, AppTheme.sage, AppTheme.terracotta];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final p in _paws)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = (_c.value + p.phase) % 1.0;
                // Sine fade in→out; gentle elliptical drift so each paw "pads".
                final fade =
                    reduceMotion ? 0.38 : 0.16 + 0.34 * math.sin(math.pi * t);
                final dx =
                    reduceMotion ? 0.0 : math.cos(2 * math.pi * t) * p.drift * 0.5;
                final dy =
                    reduceMotion ? 0.0 : -math.sin(2 * math.pi * t) * p.drift;
                return Align(
                  alignment: Alignment(p.x, p.y),
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(
                      angle: p.angle,
                      child: Opacity(
                        opacity: fade.clamp(0.0, 1.0),
                        child: Icon(Icons.pets,
                            size: p.size, color: _colors[p.color]),
                      ),
                    ),
                  ),
                );
              },
            ),
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

/// The shutter: an apricot disc with a soft inner ring, per the design.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.apricot,
            border: Border.all(color: const Color(0xFFFFFDF8), width: 5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.terracotta.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.ink.withValues(alpha: 0.25),
                  width: 3,
                ),
              ),
              // A little paw print marks the shutter.
              child: const Center(
                child: Icon(Icons.pets, size: 28, color: Color(0xFFFFF7EF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom-row close control — same disc treatment as the shutter (soft
/// ring, gentle shadow) but calmer (cream fill, terracotta ✕) and a touch
/// smaller, so it reads clearly as "leave" without competing with the shutter.
class _CloseShutterButton extends StatelessWidget {
  const _CloseShutterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFDF8),
          border: Border.all(color: AppTheme.apricot, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.close, size: 26, color: AppTheme.terracotta),
        ),
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

enum _ResultTone { success, retry }

/// The post-capture decision card: warm, kind, never error-red — success in
/// sage, "no cat" in soft peach, both with gentle copy from the design.
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.tone,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final _ResultTone tone;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = tone == _ResultTone.success;
    final chipColor = success
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.primaryContainer;
    final dotColor = success ? const Color(0xFF6E8C66) : AppTheme.terracotta;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (secondaryLabel != null && onSecondary != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(secondaryLabel!),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
