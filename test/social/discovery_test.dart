import 'package:catch_mobile/features/safety/domain/age_bracket.dart';
import 'package:catch_mobile/features/social/domain/discovery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveryProfile.fromRow — safe, minimal fields only', () {
    test('parses id, handle and cat count', () {
      final p = DiscoveryProfile.fromRow(const {
        'id': 'abc',
        'handle': ' K7Q2MN ',
        'cats_count': 4,
      });
      expect(p.id, 'abc');
      expect(p.handle, 'K7Q2MN'); // trimmed
      expect(p.catsCount, 4);
    });

    test('tolerates a missing handle / count', () {
      final p = DiscoveryProfile.fromRow(const {'id': 'x'});
      expect(p.handle, '');
      expect(p.catsCount, 0);
    });
  });

  group('canDiscover capability gate', () {
    test('adult gets discovery only under the live switch', () {
      expect(
        SocialCapabilities.forBracket(AgeBracket.adult, socialLive: true)
            .canDiscover,
        isTrue,
      );
      expect(
        SocialCapabilities.forBracket(AgeBracket.adult, socialLive: false)
            .canDiscover,
        isFalse,
      );
    });

    test('teen / under-13 / unknown never get discovery', () {
      for (final b in [AgeBracket.teen, AgeBracket.under13, AgeBracket.unknown]) {
        expect(
          SocialCapabilities.forBracket(b, socialLive: true).canDiscover,
          isFalse,
        );
      }
    });
  });
}
