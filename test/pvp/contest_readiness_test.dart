import 'package:catch_mobile/features/pvp/domain/cat_stats.dart';
import 'package:catch_mobile/features/pvp/domain/contest_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

CatStats _stats({
  int agility = 50,
  int speed = 50,
  int confidence = 50,
  int curiosity = 50,
  int energy = 50,
  int cuteness = 50,
}) =>
    CatStats(
      agility: agility,
      speed: speed,
      confidence: confidence,
      curiosity: curiosity,
      energy: energy,
      cuteness: cuteness,
    );

void main() {
  group('ContestReadiness.from', () {
    test('overall is the rounded average of the six stats', () {
      final r = ContestReadiness.from(_stats(
        agility: 10,
        speed: 20,
        confidence: 30,
        curiosity: 40,
        energy: 50,
        cuteness: 60,
      ));
      expect(r.overall, 35); // (10+20+30+40+50+60)/6 = 35
    });

    test('strongest and gentlest pick the max and min stats', () {
      final r = ContestReadiness.from(_stats(
        agility: 30,
        speed: 90, // max
        confidence: 40,
        curiosity: 12, // min
        energy: 55,
        cuteness: 60,
      ));
      expect(r.strongest, CatStat.speed);
      expect(r.gentlest, CatStat.curiosity);
      expect(r.signatureEvent, 'Zoomie race');
    });

    test('ties resolve deterministically to declaration order', () {
      // All equal: strongest and gentlest both fall to the first CatStat.
      final r = ContestReadiness.from(_stats());
      expect(r.strongest, CatStat.values.first);
      expect(r.gentlest, CatStat.values.first);
    });

    test('careNudge always targets the gentlest stat — a care action', () {
      final r = ContestReadiness.from(_stats(energy: 5));
      expect(r.gentlest, CatStat.energy);
      // The only lever offered is caring (a meal + a nap), never a purchase.
      expect(r.careNudge.toLowerCase(), contains('meal'));
      expect(r.careNudge.toLowerCase(), isNot(contains('buy')));
      expect(r.careNudge.toLowerCase(), isNot(contains('coin')));
    });

    test('moodLine is encouraging across the whole range, never a fail', () {
      expect(ContestReadiness.from(_stats(
        agility: 90,
        speed: 90,
        confidence: 90,
        curiosity: 90,
        energy: 90,
        cuteness: 90,
      )).moodLine, contains('raring'));
      expect(ContestReadiness.from(_stats(
        agility: 5,
        speed: 5,
        confidence: 5,
        curiosity: 5,
        energy: 5,
        cuteness: 5,
      )).moodLine, isNotEmpty);
    });
  });

  test('statLabel title-cases each stat', () {
    expect(statLabel(CatStat.cuteness), 'Cuteness');
    expect(statLabel(CatStat.agility), 'Agility');
  });
}
