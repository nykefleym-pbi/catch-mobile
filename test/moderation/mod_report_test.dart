import 'package:catch_mobile/features/moderation/domain/mod_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModReport.fromRow', () {
    test('parses a queue row and flags profile targets', () {
      final r = ModReport.fromRow(const {
        'report_id': 'r1',
        'reporter_id': 'u1',
        'target_type': 'profile',
        'target_id': 'p9',
        'reason': 'harassment',
        'detail': 'was unkind',
        'status': 'open',
        'reports_total': 3,
        'reports_open': 2,
      });
      expect(r.reportId, 'r1');
      expect(r.targetIsProfile, isTrue);
      expect(r.reportsOpen, 2);
      expect(r.detail, 'was unkind');
    });

    test('a content target is not a profile, and defaults are gentle', () {
      final r = ModReport.fromRow(const {
        'report_id': 'r2',
        'target_type': 'trade',
        'target_id': 't1',
        'reason': 'spam',
      });
      expect(r.targetIsProfile, isFalse);
      expect(r.detail, isNull);
      expect(r.reportsTotal, 1);
      expect(r.status, 'open');
    });
  });

  group('RestrictionKind.param', () {
    test('none carries no server param; others pass their token', () {
      expect(RestrictionKind.none.param, isNull);
      expect(RestrictionKind.mute.param, 'mute');
      expect(RestrictionKind.suspend.param, 'suspend');
      expect(RestrictionKind.ban.param, 'ban');
    });
  });

  group('ModActionKind tokens', () {
    test('match the server action vocabulary', () {
      expect(ModActionKind.dismiss.token, 'dismiss');
      expect(ModActionKind.removeContent.token, 'remove_content');
      expect(ModActionKind.ban.token, 'ban');
    });
  });

  group('ModOutcome', () {
    test('parses tokens; only ok and reviewing are success', () {
      expect(ModOutcome.parse('ok'), ModOutcome.ok);
      expect(ModOutcome.parse('reviewing'), ModOutcome.reviewing);
      expect(ModOutcome.parse('forbidden'), ModOutcome.forbidden);
      expect(ModOutcome.parse('not_found'), ModOutcome.notFound);
      expect(ModOutcome.parse('???'), ModOutcome.unknown);
      expect(ModOutcome.ok.isSuccess, isTrue);
      expect(ModOutcome.reviewing.isSuccess, isTrue);
      expect(ModOutcome.forbidden.isSuccess, isFalse);
      for (final o in ModOutcome.values) {
        expect(o.message, isNotEmpty);
      }
    });
  });
}
