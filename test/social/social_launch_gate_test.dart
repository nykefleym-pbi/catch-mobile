import 'package:catch_mobile/features/social/domain/social_launch_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SocialLaunchGate.isLive', () {
    test('master switch off is never live, whatever the market/region', () {
      expect(
        SocialLaunchGate.isLive(
          socialLive: false,
          launchMarkets: const {'US'},
          region: 'US',
        ),
        isFalse,
      );
    });

    test('no allowlist means unrestricted when the switch is on', () {
      expect(
        SocialLaunchGate.isLive(
          socialLive: true,
          launchMarkets: const {},
          region: null,
        ),
        isTrue,
      );
      expect(
        SocialLaunchGate.isLive(
          socialLive: true,
          launchMarkets: const {},
          region: 'BR',
        ),
        isTrue,
      );
    });

    test('with an allowlist, only a cleared market is live', () {
      const markets = {'US', 'CA'};
      expect(
        SocialLaunchGate.isLive(
            socialLive: true, launchMarkets: markets, region: 'US'),
        isTrue,
      );
      expect(
        SocialLaunchGate.isLive(
            socialLive: true, launchMarkets: markets, region: 'BR'),
        isFalse,
      );
    });

    test('region match is case-insensitive', () {
      expect(
        SocialLaunchGate.isLive(
          socialLive: true,
          launchMarkets: const {'US'},
          region: 'us',
        ),
        isTrue,
      );
    });

    test('unknown/blank region fails closed when an allowlist is set', () {
      expect(
        SocialLaunchGate.isLive(
            socialLive: true, launchMarkets: const {'US'}, region: null),
        isFalse,
      );
      expect(
        SocialLaunchGate.isLive(
            socialLive: true, launchMarkets: const {'US'}, region: ''),
        isFalse,
      );
    });
  });
}
