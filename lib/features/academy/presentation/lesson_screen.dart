import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_repository.dart';
import '../domain/care_lesson.dart';

/// A single lesson: the care tips, then a gentle, no-fail reflection. Choosing
/// any answer reveals the insight and marks the lesson complete — there is no
/// score and no way to "fail", in keeping with the no-dark-patterns pillar.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final CareLesson lesson;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  int? _chosen;

  void _choose(int index) {
    if (_chosen != null) return;
    setState(() => _chosen = index);
    // Reflecting at all completes the lesson — the goal is learning, not a
    // right answer. Persisted so the honour, once earned, stays earned.
    unawaited(
      ref.read(academyProgressProvider.notifier).markComplete(widget.lesson.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = widget.lesson;
    final reflection = lesson.reflection;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Text(lesson.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(lesson.summary,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.4)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Good to know',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final tip in lesson.tips) ...[
              _TipRow(tip: tip),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.peach.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A little reflection',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(reflection.question,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < reflection.options.length; i++) ...[
                    _OptionTile(
                      label: reflection.options[i],
                      state: _tileState(i, reflection.kindChoice),
                      onTap: _chosen == null ? () => _choose(i) : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (_chosen != null) ...[
              const SizedBox(height: 16),
              _InsightCard(
                kindChosen: _chosen == reflection.kindChoice,
                insight: reflection.insight,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done — back to the Academy'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _OptionState _tileState(int index, int kindChoice) {
    if (_chosen == null) return _OptionState.idle;
    if (index == kindChoice) return _OptionState.kind;
    if (index == _chosen) return _OptionState.chosenOther;
    return _OptionState.dim;
  }
}

enum _OptionState { idle, kind, chosenOther, dim }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color border, Color bg, Widget? trailing) = switch (state) {
      _OptionState.idle => (
          theme.colorScheme.outline,
          theme.colorScheme.surface,
          null,
        ),
      _OptionState.kind => (
          AppTheme.sage,
          AppTheme.sage.withValues(alpha: 0.16),
          const Icon(Icons.favorite, size: 18, color: AppTheme.sage),
        ),
      _OptionState.chosenOther => (
          theme.colorScheme.outline,
          theme.colorScheme.surfaceContainerHighest,
          Icon(Icons.check, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
      _OptionState.dim => (
          theme.colorScheme.outline,
          theme.colorScheme.surface,
          null,
        ),
    };
    return Opacity(
      opacity: state == _OptionState.dim ? 0.6 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.bodyMedium),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.kindChosen, required this.insight});

  final bool kindChosen;
  final String insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.sage.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kindChosen ? 'Yes — exactly 💛' : 'Here’s the kind way 💛',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(insight, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.pets, size: 15, color: AppTheme.terracotta),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tip,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
        ),
      ],
    );
  }
}
