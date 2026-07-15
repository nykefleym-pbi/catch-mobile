import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The heart of Cat-ch: photograph a real cat, verify it on-device, and send it
/// off to become a companion (see docs/architecture/07-ai-pipeline.md).
///
/// Phase 0 is a placeholder wired into navigation. Phase 1 replaces the body
/// with the live camera preview + on-device detection + generation call.
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Point your camera at a real cat.\n'
                'We check it on your device, then bring it to life.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Camera & detection arrive in Phase 1.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
