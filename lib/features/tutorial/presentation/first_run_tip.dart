import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tutorial_repository.dart';

/// A lightweight, dismissible first-run coach-mark for a screen. Shows once per
/// [screenId] (persisted), is always skippable via "Got it", never blocks
/// interaction, and is resettable from Settings — a guide, not a gate (ADR 0005,
/// no dark patterns). Renders nothing once dismissed.
///
/// Deliberately an inline banner rather than a full-screen overlay, so it can't
/// trap the player on flows like the live camera and reads cleanly to screen
/// readers.
class FirstRunTip extends ConsumerWidget {
  const FirstRunTip({
    super.key,
    required this.screenId,
    required this.message,
  });

  /// A stable id for the screen this tip belongs to (e.g. `'catdex'`).
  final String screenId;

  /// The (already-localized) tip copy.
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(tutorialSeenProvider).contains(screenId);
    if (seen) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Tip: $message',
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                size: 20, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(
                  ref.read(tutorialSeenProvider.notifier).markSeen(screenId)),
              child: Text(
                'Got it',
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
