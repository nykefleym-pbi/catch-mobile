import 'package:catch_mobile/features/trading/domain/trade_offer.dart';
import 'package:catch_mobile/features/trading/domain/trade_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TradeOffer serialization', () {
    test('round-trips through json', () {
      const offer = TradeOffer(
        from: [TradeItem(itemId: 'collar_blossom', qty: 1)],
        to: [TradeItem(itemId: 'decor_tulips', qty: 2)],
      );
      final parsed = TradeOffer.fromJson(offer.toJson());
      expect(parsed.from.single.itemId, 'collar_blossom');
      expect(parsed.from.single.qty, 1);
      expect(parsed.to.single.itemId, 'decor_tulips');
      expect(parsed.to.single.qty, 2);
    });

    test('fromJson drops malformed items and tolerates missing sides', () {
      final Map<String, dynamic> input = {
        'from': [
          {'item_id': 'ok', 'qty': 1},
          {'item_id': '', 'qty': 1}, // empty id -> dropped
          {'qty': 3}, // no id -> dropped
          {'item_id': 'noqty'}, // no qty -> dropped
        ],
        // 'to' missing entirely
      };
      final parsed = TradeOffer.fromJson(input);
      expect(parsed.from.map((i) => i.itemId), ['ok']);
      expect(parsed.to, isEmpty);
    });
  });

  group('TradeOffer.isStructurallyValid', () {
    test('a normal one-sided or two-sided offer is valid', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'a', qty: 1)], to: [])
            .isStructurallyValid,
        isTrue,
      );
    });

    test('both sides empty is invalid', () {
      expect(const TradeOffer(from: [], to: []).isStructurallyValid, isFalse);
    });

    test('non-positive quantity is invalid', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'a', qty: 0)], to: [])
            .isStructurallyValid,
        isFalse,
      );
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'a', qty: -1)], to: [])
            .isStructurallyValid,
        isFalse,
      );
    });

    test('the same item on both sides is invalid (no duplicates)', () {
      expect(
        const TradeOffer(
          from: [TradeItem(itemId: 'dup', qty: 1)],
          to: [TradeItem(itemId: 'dup', qty: 1)],
        ).isStructurallyValid,
        isFalse,
      );
    });
  });

  group('TradeOffer.isCosmeticSafe', () {
    ({bool isCosmetic, String type})? lookup(String id) => switch (id) {
          'collar' => (isCosmetic: true, type: 'cosmetic'),
          'kibble' => (isCosmetic: false, type: 'food'),
          'token' => (isCosmetic: true, type: 'currency'), // cosmetic flag but power type
          _ => null,
        };

    test('all-cosmetic offer is safe', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'collar', qty: 1)], to: [])
            .isCosmeticSafe(lookup),
        isTrue,
      );
    });

    test('a food item makes it unsafe', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'kibble', qty: 1)], to: [])
            .isCosmeticSafe(lookup),
        isFalse,
      );
    });

    test('a currency-typed item is unsafe even if flagged cosmetic', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'token', qty: 1)], to: [])
            .isCosmeticSafe(lookup),
        isFalse,
      );
    });

    test('an unknown item is never tradable', () {
      expect(
        const TradeOffer(from: [TradeItem(itemId: 'ghost', qty: 1)], to: [])
            .isCosmeticSafe(lookup),
        isFalse,
      );
    });
  });

  group('TradeOutcome', () {
    test('parses tokens; unknown falls back', () {
      expect(TradeOutcome.fromToken('ok'), TradeOutcome.ok);
      expect(TradeOutcome.fromToken('not_cosmetic'), TradeOutcome.notCosmetic);
      expect(TradeOutcome.fromToken('insufficient'), TradeOutcome.insufficient);
      expect(TradeOutcome.fromToken(null), TradeOutcome.unknown);
      expect(TradeOutcome.fromToken('???'), TradeOutcome.unknown);
    });

    test('only ok is success', () {
      expect(TradeOutcome.ok.isSuccess, isTrue);
      for (final o in TradeOutcome.values.where((o) => o != TradeOutcome.ok)) {
        expect(o.isSuccess, isFalse, reason: o.name);
      }
    });

    test('every outcome has a non-empty message', () {
      for (final o in TradeOutcome.values) {
        expect(o.message.trim(), isNotEmpty, reason: o.name);
      }
    });
  });
}
