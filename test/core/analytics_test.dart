import 'package:catch_mobile/core/analytics/analytics_event.dart';
import 'package:catch_mobile/core/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsSanitizer.clean', () {
    test('reduced-data mode drops everything (minors send bare event)', () {
      final out = AnalyticsSanitizer.clean(
        {'count': 3, 'ok': true},
        reducedData: true,
      );
      expect(out, isEmpty);
    });

    test('keeps primitive values', () {
      final out = AnalyticsSanitizer.clean(
        {'count': 3, 'ratio': 0.5, 'ok': true, 'stage': 'result'},
        reducedData: false,
      );
      expect(out, {'count': 3, 'ratio': 0.5, 'ok': true, 'stage': 'result'});
    });

    test('drops non-primitive values', () {
      final out = AnalyticsSanitizer.clean(
        {'good': 1, 'list': [1, 2], 'map': {'a': 1}, 'nothing': null},
        reducedData: false,
      );
      expect(out, {'good': 1});
    });

    test('strips PII / location / identifier keys (substring match)', () {
      final out = AnalyticsSanitizer.clean(
        {
          'geo_lat': 51.5,
          'lng': -0.1,
          'home_address': 'x',
          'email': 'a@b.c',
          'display_name': 'Alex',
          'profile_id': 'u1',
          'auth_token': 't',
          'keep': 1,
        },
        reducedData: false,
      );
      expect(out, {'keep': 1});
    });

    test('clamps long strings to 64 chars', () {
      final long = 'x' * 200;
      final out = AnalyticsSanitizer.clean({'note': long}, reducedData: false);
      expect((out['note'] as String).length, 64);
    });
  });

  group('AnalyticsEventName', () {
    test('every event has a non-empty snake_case token', () {
      for (final e in AnalyticsEventName.values) {
        expect(e.token, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: e.name);
      }
    });

    test('tokens are unique', () {
      final tokens = AnalyticsEventName.values.map((e) => e.token).toList();
      expect(tokens.toSet().length, tokens.length);
    });
  });

  group('NoopAnalytics', () {
    test('log and recordError never throw', () {
      const a = NoopAnalytics();
      expect(
        () => a.log(AnalyticsEventName.appOpened, params: {'x': 1}),
        returnsNormally,
      );
      expect(
        () => a.recordError(Exception('boom'), StackTrace.current, fatal: true),
        returnsNormally,
      );
    });
  });
}
