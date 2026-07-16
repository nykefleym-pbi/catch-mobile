import 'package:catch_mobile/features/profile/domain/guardian_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuardianProfile', () {
    test('score blends cats befriended with total bond', () {
      const p = GuardianProfile(displayName: null, catsCount: 3, totalBond: 5);
      expect(p.score, 14); // 3*3 + 5
    });

    test('rank, progress, and points-to-next derive from the score', () {
      const p = GuardianProfile(displayName: 'Mim', catsCount: 3, totalBond: 5);
      // score 14 sits in the first tier (0) heading toward Caretaker (20).
      expect(p.rankLabel, 'Fledgling Guardian');
      expect(p.rankIsMax, isFalse);
      expect(p.rankProgress, closeTo(0.7, 0.0001)); // 14/20
      expect(p.pointsToNextRank, 6); // 20 - 14
    });

    test('empty profile is a fresh Fledgling Guardian', () {
      expect(GuardianProfile.empty.score, 0);
      expect(GuardianProfile.empty.rankLabel, 'Fledgling Guardian');
    });
  });

  group('GuardianRank', () {
    test('labels climb with score', () {
      expect(GuardianRank.labelFor(0), 'Fledgling Guardian');
      expect(GuardianRank.labelFor(50), 'Kind Guardian');
      expect(GuardianRank.labelFor(1000), 'Legendary Guardian');
    });

    test('reports the max tier and full progress there', () {
      expect(GuardianRank.isMax(199), isFalse);
      expect(GuardianRank.isMax(400), isTrue);
      expect(GuardianRank.progressFor(400), 1.0);
      expect(GuardianRank.toNext(400), 0);
    });
  });
}
