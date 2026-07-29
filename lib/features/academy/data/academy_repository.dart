import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/care_lesson.dart';

/// Persisted key for the set of completed lesson ids. Versioned so a future
/// curriculum change can reset progress cleanly.
const _academyCompletedKey = 'academy_completed_v1';

/// Tracks which Care Academy lessons the guardian has finished. Progress is a
/// personal, on-device record only — completing lessons collects no data and
/// touches no server, which keeps it safe under the reduced-data minor mode.
class AcademyController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final stored =
        ref.read(sharedPreferencesProvider).getStringList(_academyCompletedKey);
    // Keep only ids still in the curriculum, so a removed lesson can't linger.
    final valid = kCareLessons.map((l) => l.id).toSet();
    return {...?stored}.intersection(valid);
  }

  /// Marks a lesson complete and persists it. Idempotent — re-finishing a
  /// lesson is fine and never un-earns anything.
  Future<void> markComplete(String lessonId) async {
    if (state.contains(lessonId)) return;
    final next = {...state, lessonId};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_academyCompletedKey, next.toList());
    state = next;
  }
}

final academyProgressProvider =
    NotifierProvider<AcademyController, Set<String>>(AcademyController.new);

/// Whether the guardian has earned the (cosmetic) "Certified Caretaker" honour.
final academyGraduateProvider = Provider<bool>(
  (ref) => academyIsComplete(ref.watch(academyProgressProvider)),
);
