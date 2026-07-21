import 'package:catch_mobile/features/social/data/trade_repository.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:catch_mobile/features/social/domain/trade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('charm display', () {
    test('known charms map to an emoji; unknown falls back gently', () {
      expect(charmEmoji('charm_yarn'), '🧶');
      expect(charmEmoji('charm_paw'), '🐾');
      expect(charmEmoji('charm_unknown'), '🎀');
    });

    test('the catalogue order matches the emoji map', () {
      for (final id in kCharmOrder) {
        expect(kCharmEmoji.containsKey(id), isTrue, reason: id);
      }
      expect(kCharmOrder.length, kCharmEmoji.length);
    });
  });

  group('OwnedCosmetic.fromRow', () {
    test('parses a nested inventory row', () {
      final c = OwnedCosmetic.fromRow(const {
        'quantity': 2,
        'items': {
          'id': 'charm_star',
          'label': 'Gold Star',
          'type': 'charm',
          'is_cosmetic': true,
        },
      });
      expect(c.itemId, 'charm_star');
      expect(c.label, 'Gold Star');
      expect(c.quantity, 2);
      expect(c.emoji, '⭐');
    });
  });

  group('TradeOffer / OfferLine', () {
    test('serialises to the from/to shape the RPC expects', () {
      const offer = TradeOffer(
        give: [OfferLine(itemId: 'charm_yarn', quantity: 1)],
        request: [OfferLine(itemId: 'charm_fish', quantity: 2)],
      );
      expect(offer.toJson(), {
        'from': [
          {'item_id': 'charm_yarn', 'qty': 1}
        ],
        'to': [
          {'item_id': 'charm_fish', 'qty': 2}
        ],
      });
      expect(offer.isEmpty, isFalse);
      expect(const TradeOffer().isEmpty, isTrue);
    });

    test('OfferLine round-trips through json', () {
      final l = OfferLine.fromJson(const {'item_id': 'charm_bell', 'qty': 3});
      expect(l.itemId, 'charm_bell');
      expect(l.quantity, 3);
      expect(l.label, 'Jingle Bell');
      expect(l.toJson(), {'item_id': 'charm_bell', 'qty': 3});
    });
  });

  group('Trade.fromRow', () {
    test('parses both offer sides and viewer perspective', () {
      final t = Trade.fromRow(const {
        'id': 't1',
        'from_id': 'alice',
        'to_id': 'bob',
        'status': 'proposed',
        'offer': {
          'from': [
            {'item_id': 'charm_yarn', 'qty': 1}
          ],
          'to': [
            {'item_id': 'charm_moon', 'qty': 1}
          ],
        },
      });
      expect(t.give.single.itemId, 'charm_yarn');
      expect(t.request.single.itemId, 'charm_moon');
      expect(t.isIncoming('bob'), isTrue);
      expect(t.isOutgoing('alice'), isTrue);
      expect(t.otherId('bob'), 'alice');
      expect(t.otherId('alice'), 'bob');
    });

    test('handles a one-sided gift (empty request)', () {
      final t = Trade.fromRow(const {
        'id': 't2',
        'from_id': 'a',
        'to_id': 'b',
        'status': 'proposed',
        'offer': {
          'from': [
            {'item_id': 'charm_heart', 'qty': 1}
          ],
          'to': <dynamic>[],
        },
      });
      expect(t.give.length, 1);
      expect(t.request, isEmpty);
    });
  });

  group('TradeOutcome', () {
    test('parses tokens and only ok is success', () {
      expect(TradeOutcome.parse('ok'), TradeOutcome.ok);
      expect(TradeOutcome.parse('not_cosmetic'), TradeOutcome.notCosmetic);
      expect(TradeOutcome.parse('insufficient'), TradeOutcome.insufficient);
      expect(TradeOutcome.parse('???'), TradeOutcome.unknown);
      expect(TradeOutcome.ok.isSuccess, isTrue);
      expect(TradeOutcome.notCosmetic.isSuccess, isFalse);
      for (final o in TradeOutcome.values) {
        expect(o.message, isNotEmpty);
      }
    });
  });

  group('TradeRepository gating (kSocialLive)', () {
    test('the master switch is off in this build', () {
      expect(kSocialLive, isFalse);
    });

    test('reads return empty and mutations short-circuit with no network',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(tradeRepositoryProvider);

      expect(await repo.myCharms(), isEmpty);
      expect(await repo.proposedTrades(), isEmpty);
      expect(
        await repo.propose('friend-1',
            const TradeOffer(give: [OfferLine(itemId: 'charm_yarn', quantity: 1)])),
        TradeOutcome.restricted,
      );
      expect(await repo.accept('t1'), TradeOutcome.restricted);
      expect(await repo.decline('t1'), TradeOutcome.restricted);
      expect(await repo.cancel('t1'), TradeOutcome.restricted);
    });
  });
}
