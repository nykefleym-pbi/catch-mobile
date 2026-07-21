import 'package:catch_mobile/features/pvp/domain/match.dart';
import 'package:catch_mobile/features/social/data/social_inbox.dart';
import 'package:catch_mobile/features/social/domain/trade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Trade trade(String toId, String status) => Trade.fromRow({
        'id': 't',
        'from_id': 'other',
        'to_id': toId,
        'status': status,
        'offer': const {'from': <dynamic>[], 'to': <dynamic>[]},
      });

  Match match(String opponentId, String status) => Match.fromMap({
        'id': 'm',
        'mode': 'zoomies',
        'challenger_id': 'other',
        'opponent_id': opponentId,
        'status': status,
        'winner_id': null,
      });

  group('socialInboxCount', () {
    test('counts only incoming proposed trades + invited matches for the viewer',
        () {
      final n = socialInboxCount(
        uid: 'me',
        trades: [
          trade('me', 'proposed'), // incoming, counts
          trade('other', 'proposed'), // addressed elsewhere
          trade('me', 'completed'), // not pending
        ],
        matches: [
          match('me', 'invited'), // incoming, counts
          match('other', 'invited'), // addressed elsewhere
          match('me', 'accepted'), // already answered
        ],
      );
      expect(n, 2);
    });

    test('a signed-out viewer has an empty inbox', () {
      expect(
        socialInboxCount(uid: null, trades: const [], matches: const []),
        0,
      );
    });

    test('nothing pending is zero', () {
      expect(
        socialInboxCount(
          uid: 'me',
          trades: [trade('me', 'completed')],
          matches: [match('me', 'declined')],
        ),
        0,
      );
    });
  });
}
