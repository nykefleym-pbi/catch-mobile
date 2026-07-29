import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/academy_repository.dart';
import '../domain/care_lesson.dart';
import 'lesson_screen.dart';

/// The Care Academy — the educational, welfare-first slice of Phase 4's Guardian
/// Missions ("learning responsible care"). It teaches real cat care through a
/// short curriculum of gentle lessons; finishing them all earns a cosmetic
/// "Certified Caretaker" honour (a title/badge only — never power, never money).
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(academyProgressProvider);
    final isGraduate = ref.watch(academyGraduateProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Care Academy')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _Intro(
              done: academyCompletedCount(completed),
              total: kCareLessons.length,
              isGraduate: isGraduate,
            ),
            const SizedBox(height: 20),
            for (final lesson in kCareLessons) ...[
              _LessonRow(
                lesson: lesson,
                done: completed.contains(lesson.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonScreen(lesson: lesson),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            Text(
              'Every lesson is here to help real cats live happier, safer lives. '
              'Nothing here is a test — take them in any order, any time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.done,
    required this.total,
    required this.isGraduate,
  });

  final int done;
  final int total;
  final bool isGraduate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isGraduate ? AppTheme.sage : AppTheme.apricot)
            .withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Column(
        children: [
          Text(isGraduate ? '🎓' : '📚', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            isGraduate ? 'Certified Caretaker' : 'Become a Certified Caretaker',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isGraduate
                ? 'You’ve finished every lesson — a real friend to cats. This '
                    'honour is yours to keep.'
                : 'Learn to care for cats the kind way. Finish all $total '
                    'lessons to earn your Caretaker honour.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surface,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('$done of $total lessons',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.done,
    required this.onTap,
  });

  final CareLesson lesson;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Text(lesson.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      lesson.summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                done ? Icons.check_circle : Icons.chevron_right,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
