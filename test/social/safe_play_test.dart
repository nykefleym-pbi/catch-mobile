import 'package:catch_mobile/features/safety/domain/age_bracket.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafePlay.itemIsTradable — cosmetic only, never power/currency', () {
    test('a cosmetic item is tradable', () {
      expect(SafePlay.itemIsTradable(isCosmetic: true, type: 'cosmetic'), isTrue);
      expect(SafePlay.itemIsTradable(isCosmetic: true, type: 'collar'), isTrue);
    });

    test('a non-cosmetic item is never tradable', () {
      expect(SafePlay.itemIsTradable(isCosmetic: false, type: 'food'), isFalse);
    });

    test('a power/consumable/currency type is never tradable, even if flagged '
        'cosmetic', () {
      expect(SafePlay.itemIsTradable(isCosmetic: true, type: 'food'), isFalse);
      expect(
          SafePlay.itemIsTradable(isCosmetic: true, type: 'currency'), isFalse);
      expect(SafePlay.itemIsTradable(isCosmetic: true, type: 'buff'), isFalse);
    });
  });

  group('SafePlay.rewardIsCosmeticOnly — no power rewards', () {
    test('cosmetic/progression reward kinds are allowed', () {
      expect(SafePlay.rewardIsCosmeticOnly('collar'), isTrue);
      expect(SafePlay.rewardIsCosmeticOnly('title'), isTrue);
      expect(SafePlay.rewardIsCosmeticOnly('badge'), isTrue);
    });

    test('a power or currency reward is rejected', () {
      expect(SafePlay.rewardIsCosmeticOnly('power'), isFalse);
      expect(SafePlay.rewardIsCosmeticOnly('currency'), isFalse);
      expect(SafePlay.rewardIsCosmeticOnly('stat'), isFalse);
    });
  });

  group('SafePlay showcase location safety', () {
    test('coarse (<=2dp) or absent coordinates are safe', () {
      expect(SafePlay.isCoarseCoordinate(null), isTrue);
      expect(SafePlay.isCoarseCoordinate(51.51), isTrue);
      expect(SafePlay.showcaseIsLocationSafe(lat: 51.51, lng: -0.13), isTrue);
      expect(SafePlay.showcaseIsLocationSafe(), isTrue);
    });

    test('a precise coordinate leaks a location and is rejected', () {
      expect(SafePlay.isCoarseCoordinate(51.507351), isFalse);
      expect(
        SafePlay.showcaseIsLocationSafe(lat: 51.507351, lng: -0.127758),
        isFalse,
      );
    });
  });

  group('SafePlay interaction is friends-only + age-gated', () {
    test('an adult may interact with a friend but not a stranger', () {
      final caps = SocialCapabilities.forBracket(AgeBracket.adult);
      expect(SafePlay.interactionAllowed(caps, otherIsFriend: true), isTrue);
      expect(SafePlay.interactionAllowed(caps, otherIsFriend: false), isFalse);
    });

    test('an under-13 may not interact even with a friend', () {
      final caps = SocialCapabilities.forBracket(AgeBracket.under13);
      expect(SafePlay.interactionAllowed(caps, otherIsFriend: true), isFalse);
    });
  });

  group('SafePlay messaging — canned reactions only, no free text', () {
    test('a canned reaction is allowed', () {
      expect(SafePlay.isAllowedMessage(SafePlay.kSafeReactions.first), isTrue);
    });

    test('free text is never allowed', () {
      expect(SafePlay.isAllowedMessage('give me your address'), isFalse);
      expect(SafePlay.isAllowedMessage(''), isFalse);
    });
  });

  group('SocialCapabilities.forBracket', () {
    test('under-13 and unknown get no social access (reduced-data mode)', () {
      for (final b in [AgeBracket.under13, AgeBracket.unknown]) {
        final caps = SocialCapabilities.forBracket(b);
        expect(caps.canUseSocial, isFalse);
        expect(caps.canAddFriends, isFalse);
        expect(caps.canShowcaseToFriends, isFalse);
        expect(caps.canTrade, isFalse);
      }
    });

    test('a teen can add friends but can never showcase publicly', () {
      final caps = SocialCapabilities.forBracket(AgeBracket.teen);
      expect(caps.canUseSocial, isTrue);
      expect(caps.canAddFriends, isTrue);
      expect(caps.canShowcaseToFriends, isFalse);
      expect(caps.canTrade, isFalse);
    });

    test('an adult may showcase, and trading follows the master switch', () {
      expect(
        SocialCapabilities.forBracket(AgeBracket.adult).canShowcaseToFriends,
        isTrue,
      );
      expect(
        SocialCapabilities.forBracket(AgeBracket.adult, socialLive: false)
            .canTrade,
        isFalse,
      );
      expect(
        SocialCapabilities.forBracket(AgeBracket.adult, socialLive: true)
            .canTrade,
        isTrue,
      );
    });

    test('the shipped default keeps live trading off', () {
      // kSocialLive is the master switch; groundwork ships with it off.
      expect(kSocialLive, isFalse);
    });
  });
}
