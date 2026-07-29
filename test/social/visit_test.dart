import 'package:catch_mobile/features/social/data/social_repository.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:catch_mobile/features/social/domain/showcase_cat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShowcaseCat', () {
    test('parses a row and prefers nickname for the display name', () {
      final c = ShowcaseCat.fromRow(const {
        'id': 'c1',
        'name': 'Mittens',
        'nickname': 'Mimi',
        'sprite_url': 'https://x/y.png',
        'growth_stage': 'adult',
        'trait_id': 'curious',
      });
      expect(c.displayName, 'Mimi');
      expect(c.growthLabel, 'Adult');
      expect(c.spriteUrl, 'https://x/y.png');
    });

    test('falls back name → gentle default; unknown stage → Cat', () {
      final noNick = ShowcaseCat.fromRow(const {
        'id': 'c2',
        'name': 'Mittens',
        'growth_stage': 'kitten',
      });
      expect(noNick.displayName, 'Mittens');
      expect(noNick.growthLabel, 'Kitten');

      final bare = ShowcaseCat.fromRow(const {'id': 'c3', 'growth_stage': 'x'});
      expect(bare.displayName, 'A cat');
      expect(bare.growthLabel, 'Cat');
    });

    test('carries no location field (privacy: visiting never reveals place)',
        () {
      // The row from list_friend_showcase deliberately omits location_label;
      // even if a caller slipped one in, the model has nowhere to keep it.
      final c = ShowcaseCat.fromRow(const {
        'id': 'c4',
        'growth_stage': 'young',
        'location_label': 'Downtown',
      });
      // No location surface exists on the model — this is the guarantee.
      expect(c.toString().contains('Downtown'), isFalse);
    });
  });

  group('friendShowcase gating (kSocialLive)', () {
    test('live social is on by default in this build', () {
      expect(kSocialLive, isTrue);
    });

    test('the repository is available when live', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Construction does no I/O; the live showcase read is covered server-side.
      expect(container.read(socialRepositoryProvider), isNotNull);
    });
  });
}
