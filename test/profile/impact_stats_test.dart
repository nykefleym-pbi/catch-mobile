import 'package:catch_mobile/features/profile/domain/impact_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('impact metrics are own-data only — never real-world/donation figures',
      () {
    final metrics = const ImpactStats(
      catsMet: 2,
      placesExplored: 1,
      bondShared: 5,
      lessonsLearned: 3,
    ).toMetrics();

    // The metric set is a closed allow-list of the player's own data.
    expect(
      metrics.keys.toSet(),
      {'cats_met', 'places_explored', 'bond_shared', 'lessons_learned'},
    );

    // Guard against any key that would imply fabricated real-world impact
    // before Phase 4 (donations, cats helped, fundraising, partners).
    const banned = [
      'donat',
      'helped',
      'fund',
      'money',
      'currency',
      'revenue',
      'partner',
      'cash',
      'meal',
    ];
    for (final key in metrics.keys) {
      for (final b in banned) {
        expect(key.contains(b), isFalse,
            reason: 'impact metric "$key" must not imply real-world impact');
      }
    }

    // Values reflect the inputs honestly.
    expect(metrics['cats_met'], 2);
    expect(metrics['lessons_learned'], 3);
  });

  test('empty impact is honest zeros, never a seeded number', () {
    expect(ImpactStats.empty.toMetrics().values, everyElement(0));
  });
}
