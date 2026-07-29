import 'package:catch_mobile/features/pvp/domain/match.dart';
import 'package:catch_mobile/features/social/data/social_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks a friendly contest through its lifecycle from both players' points of
/// view, pinning the viewer-relevant transitions the matches UI + inbox badge
/// bind to. This is the deterministic stand-in for a two-client UI run: a true
/// end-to-end pass needs a live backend + two authenticated sessions (the swap
/// itself is exercised server-side in the staging round-trip), but the flow
/// predicates below are what each screen actually renders on.
void main() {
  const challenger = 'alice';
  const opponent = 'bob';

  Match at(String status, {String? winner}) => Match.fromMap({
        'id': 'm1',
        'mode': 'zoomies',
        'challenger_id': challenger,
        'opponent_id': opponent,
        'status': status,
        'winner_id': winner,
      });

  group('match lifecycle from each side', () {
    test('an invite is incoming for the opponent, outgoing for the challenger',
        () {
      final m = at('invited');
      expect(m.incomingFor(opponent), isTrue);
      expect(m.outgoingFor(opponent), isFalse);
      expect(m.outgoingFor(challenger), isTrue);
      expect(m.incomingFor(challenger), isFalse);
      expect(m.otherId(challenger), opponent);
      expect(m.otherId(opponent), challenger);
    });

    test('accepting clears both the incoming and outgoing invite states', () {
      final m = at('accepted');
      expect(m.isAccepted, isTrue);
      expect(m.incomingFor(opponent), isFalse);
      expect(m.outgoingFor(challenger), isFalse);
    });

    test('completing records the friendly result as a keepsake', () {
      final m = at('completed', winner: challenger);
      expect(m.isCompleted, isTrue);
      expect(m.winnerId, challenger);
      // A draw is allowed — no winner, still complete.
      expect(at('completed').winnerId, isNull);
    });
  });

  group('inbox badge tracks the invite through the flow', () {
    test('the opponent sees +1 while invited, and 0 once answered', () {
      expect(
        socialInboxCount(uid: opponent, trades: const [], matches: [at('invited')]),
        1,
      );
      expect(
        socialInboxCount(uid: opponent, trades: const [], matches: [at('accepted')]),
        0,
      );
      // The challenger never sees their own outgoing invite as inbox activity.
      expect(
        socialInboxCount(uid: challenger, trades: const [], matches: [at('invited')]),
        0,
      );
    });
  });
}
