import 'package:catch_mobile/features/safety/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportOutcome', () {
    test('parses known tokens and falls back to unknown', () {
      expect(ReportOutcome.fromToken('ok'), ReportOutcome.ok);
      expect(ReportOutcome.fromToken('rate_limited'), ReportOutcome.rateLimited);
      expect(ReportOutcome.fromToken('restricted'), ReportOutcome.restricted);
      expect(ReportOutcome.fromToken('duplicate'), ReportOutcome.duplicate);
      expect(ReportOutcome.fromToken(null), ReportOutcome.unknown);
      expect(ReportOutcome.fromToken('nonsense'), ReportOutcome.unknown);
    });

    test('ok and duplicate are the only success outcomes', () {
      expect(ReportOutcome.ok.isSuccess, isTrue);
      expect(ReportOutcome.duplicate.isSuccess, isTrue);
      expect(ReportOutcome.rateLimited.isSuccess, isFalse);
      expect(ReportOutcome.restricted.isSuccess, isFalse);
      expect(ReportOutcome.unknown.isSuccess, isFalse);
    });

    test('every outcome has a non-empty player-facing message', () {
      for (final o in ReportOutcome.values) {
        expect(o.message.trim(), isNotEmpty, reason: o.name);
      }
    });
  });

  group('RestrictionKind', () {
    test('parses tokens; unknown returns null', () {
      expect(RestrictionKind.fromToken('mute'), RestrictionKind.mute);
      expect(RestrictionKind.fromToken('suspend'), RestrictionKind.suspend);
      expect(RestrictionKind.fromToken('ban'), RestrictionKind.ban);
      expect(RestrictionKind.fromToken('weird'), isNull);
      expect(RestrictionKind.fromToken(null), isNull);
    });

    test('is ordered least -> most severe', () {
      expect(RestrictionKind.mute.index, lessThan(RestrictionKind.suspend.index));
      expect(
          RestrictionKind.suspend.index, lessThan(RestrictionKind.ban.index));
    });
  });

  group('Restriction', () {
    test('mute does not block social actions; suspend/ban do', () {
      expect(
          const Restriction(kind: RestrictionKind.mute).blocksSocialActions,
          isFalse);
      expect(
          const Restriction(kind: RestrictionKind.suspend).blocksSocialActions,
          isTrue);
      expect(const Restriction(kind: RestrictionKind.ban).blocksSocialActions,
          isTrue);
    });

    test('is active when no expiry or expiry in the future', () {
      expect(const Restriction(kind: RestrictionKind.ban).isActive, isTrue);
      expect(
        Restriction(
          kind: RestrictionKind.suspend,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ).isActive,
        isTrue,
      );
    });

    test('is inactive once expiry has passed', () {
      expect(
        Restriction(
          kind: RestrictionKind.suspend,
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ).isActive,
        isFalse,
      );
    });

    test('fromMap parses a row; bad kind yields null', () {
      final r = Restriction.fromMap({
        'kind': 'suspend',
        'reason': 'spam',
        'expires_at': '2999-01-01T00:00:00Z',
      });
      expect(r, isNotNull);
      expect(r!.kind, RestrictionKind.suspend);
      expect(r.reason, 'spam');
      expect(r.isActive, isTrue);

      expect(Restriction.fromMap({'kind': 'nope'}), isNull);
    });

    test('every kind has a non-empty banner message', () {
      for (final k in RestrictionKind.values) {
        expect(Restriction(kind: k).bannerMessage.trim(), isNotEmpty,
            reason: k.name);
      }
    });
  });
}
