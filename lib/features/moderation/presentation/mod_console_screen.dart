import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moderation_repository.dart';
import '../domain/mod_report.dart';

/// The in-app moderation console — the review queue a registered moderator works
/// (migration 0018). Only reachable when [amIModeratorProvider] is true; the
/// server re-checks moderator status on every action regardless, so this screen
/// holds no privilege of its own.
class ModConsoleScreen extends ConsumerWidget {
  const ModConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(modQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Moderation')),
      body: SafeArea(
        child: queue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const _Message('Could not load the review queue right now.'),
          data: (reports) => reports.isEmpty
              ? const _Message('Nothing waiting — the queue is clear. 🐾')
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(modQueueProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ReportCard(reports[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard(this.report);
  final ModReport report;

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required ModActionKind action,
    RestrictionKind restriction = RestrictionKind.none,
    int? days,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(moderationRepositoryProvider).resolve(
          reportId: report.reportId,
          action: action,
          restriction: restriction,
          days: days,
        );
    if (outcome.isSuccess) ref.invalidate(modQueueProvider);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flagged = report.reportsOpen > 1;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${report.targetType} • ${report.reason}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (flagged)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${report.reportsOpen} open',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Target ${report.targetId}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (report.detail != null && report.detail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(report.detail!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _resolve(context, ref, action: ModActionKind.dismiss),
                  child: const Text('Dismiss'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _resolve(context, ref, action: ModActionKind.warn),
                  child: const Text('Warn'),
                ),
                if (report.targetIsProfile) ...[
                  OutlinedButton(
                    onPressed: () => _resolve(
                      context,
                      ref,
                      action: ModActionKind.restrict,
                      restriction: RestrictionKind.mute,
                      days: 7,
                    ),
                    child: const Text('Mute 7d'),
                  ),
                  OutlinedButton(
                    onPressed: () => _resolve(
                      context,
                      ref,
                      action: ModActionKind.restrict,
                      restriction: RestrictionKind.suspend,
                      days: 30,
                    ),
                    child: const Text('Suspend 30d'),
                  ),
                  FilledButton(
                    onPressed: () => _resolve(
                      context,
                      ref,
                      action: ModActionKind.ban,
                      restriction: RestrictionKind.ban,
                    ),
                    child: const Text('Ban'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: () => _resolve(
                      context,
                      ref,
                      action: ModActionKind.removeContent,
                    ),
                    child: const Text('Remove content'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
