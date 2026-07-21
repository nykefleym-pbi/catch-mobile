import 'package:catch_mobile/features/pvp/data/match_repository.dart';
import 'package:catch_mobile/features/pvp/domain/match.dart';
import 'package:catch_mobile/features/pvp/domain/match_outcome.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchMode', () {
    test('tokens are the DB check-constraint values and round-trip', () {
      expect(MatchMode.values.map((m) => m.token).toSet(),
          {'zoomies', 'agility', 'treasure', 'toy'});
      for (final m in MatchMode.values) {
        expect(MatchMode.fromToken(m.token), m);
        expect(m.label, isNotEmpty);
        expect(m.emoji, isNotEmpty);
        expect(m.blurb, isNotEmpty);
      }
    });

    test('an unknown token is null', () {
      expect(MatchMode.fromToken('battle'), isNull);
      expect(MatchMode.fromToken(null), isNull);
    });
  });

  group('Match', () {
    Match make(String status, {String? winner}) => Match.fromMap({
          'id': 'm1',
          'mode': 'zoomies',
          'challenger_id': 'A',
          'opponent_id': 'B',
          'status': status,
          'winner_id': winner,
        });

    test('parses a row and resolves the mode', () {
      final m = make('invited');
      expect(m.mode, MatchMode.zoomies);
      expect(m.challengerId, 'A');
      expect(m.opponentId, 'B');
      expect(m.isInvited, isTrue);
    });

    test('an unknown mode parses to null, not a crash', () {
      final m = Match.fromMap({
        'id': 'm2',
        'mode': 'battle',
        'challenger_id': 'A',
        'opponent_id': 'B',
        'status': 'invited',
      });
      expect(m.mode, isNull);
    });

    test('direction helpers are viewer-relative', () {
      final m = make('invited');
      // B is the opponent → it is incoming for B, outgoing for A.
      expect(m.incomingFor('B'), isTrue);
      expect(m.incomingFor('A'), isFalse);
      expect(m.outgoingFor('A'), isTrue);
      expect(m.outgoingFor('B'), isFalse);
      expect(m.otherId('A'), 'B');
      expect(m.otherId('B'), 'A');
    });

    test('non-invited matches are neither incoming nor outgoing', () {
      final done = make('completed', winner: 'A');
      expect(done.incomingFor('B'), isFalse);
      expect(done.outgoingFor('A'), isFalse);
      expect(done.isCompleted, isTrue);
    });
  });

  group('MatchOutcome', () {
    test('every server token maps to a value with a friendly message', () {
      const tokens = [
        'ok', 'bad_target', 'bad_mode', 'age_restricted', 'restricted',
        'blocked', 'not_friends', 'rate_limited', 'not_found', 'forbidden',
        'closed', 'bad_winner', 'unauthenticated',
      ];
      for (final t in tokens) {
        final o = MatchOutcome.fromToken(t);
        expect(o.token, t, reason: t);
        expect(o.message, isNotEmpty, reason: t);
      }
    });

    test('an unrecognised token is unknown, never a silent success', () {
      final o = MatchOutcome.fromToken('surprise');
      expect(o, MatchOutcome.unknown);
      expect(o.isSuccess, isFalse);
    });
  });

  group('MatchRepository gating (kSocialLive master switch)', () {
    // The suite must run with live social OFF — the whole point of the gate.
    test('the master switch is off in this build', () {
      expect(kSocialLive, isFalse);
    });

    test('writes short out with restricted and never touch the network', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(matchRepositoryProvider);

      expect(await repo.challenge('B', MatchMode.zoomies),
          MatchOutcome.restricted);
      expect(await repo.respond('m1', accept: true), MatchOutcome.restricted);
      expect(await repo.cancel('m1'), MatchOutcome.restricted);
      expect(await repo.recordResult('m1', null), MatchOutcome.restricted);
    });

    test('invite lists are empty while gated (no network read)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(matchRepositoryProvider);

      expect(await repo.incoming(), isEmpty);
      expect(await repo.outgoing(), isEmpty);
    });
  });
}
