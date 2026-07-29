import 'package:catch_mobile/features/social/data/club_repository.dart';
import 'package:catch_mobile/features/social/domain/club.dart';
import 'package:catch_mobile/features/social/domain/safe_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClubChallenge', () {
    test('fraction is clamped and safe when goal is zero', () {
      const half = ClubChallenge(
          kind: ClubChallengeKind.care, goal: 20, progress: 10, completed: false);
      expect(half.fraction, 0.5);

      const over = ClubChallenge(
          kind: ClubChallengeKind.play, goal: 5, progress: 9, completed: true);
      expect(over.fraction, 1.0); // never exceeds 1

      const zero = ClubChallenge(
          kind: ClubChallengeKind.groom, goal: 0, progress: 3, completed: false);
      expect(zero.fraction, 0.0); // no divide-by-zero
    });

    test('kind parses from token with a caring default', () {
      expect(ClubChallengeKind.fromToken('play'), ClubChallengeKind.play);
      expect(ClubChallengeKind.fromToken('groom'), ClubChallengeKind.groom);
      expect(ClubChallengeKind.fromToken(null), ClubChallengeKind.care);
      expect(ClubChallengeKind.fromToken('???'), ClubChallengeKind.care);
    });
  });

  group('Club.fromRow', () {
    test('parses a row with an active challenge', () {
      final c = Club.fromRow(const {
        'club_id': 'club1',
        'name': 'Sunbeam Squad',
        'my_role': 'owner',
        'my_status': 'active',
        'member_count': 3,
        'challenge_kind': 'care',
        'challenge_goal': 30,
        'challenge_progress': 12,
        'challenge_status': 'active',
      });
      expect(c.name, 'Sunbeam Squad');
      expect(c.isOwner, isTrue);
      expect(c.isActive, isTrue);
      expect(c.memberCount, 3);
      expect(c.challenge, isNotNull);
      expect(c.challenge!.goal, 30);
      expect(c.challenge!.completed, isFalse);
    });

    test('parses an invited row with no challenge', () {
      final c = Club.fromRow(const {
        'club_id': 'club2',
        'name': 'Nap Club',
        'my_role': 'member',
        'my_status': 'invited',
        'member_count': 2,
      });
      expect(c.isInvited, isTrue);
      expect(c.isActive, isFalse);
      expect(c.isOwner, isFalse);
      expect(c.challenge, isNull);
    });
  });

  group('ClubMember.fromRow', () {
    test('shows a friend by name', () {
      final m = ClubMember.fromRow(const {
        'profile_id': 'p1',
        'role': 'member',
        'status': 'active',
        'display_name': 'Sam',
        'is_friend': true,
      });
      expect(m.label, 'Sam');
      expect(m.isFriend, isTrue);
    });

    test('a non-friend co-member stays anonymous (no stranger handle leaks)',
        () {
      final m = ClubMember.fromRow(const {
        'profile_id': 'p2',
        'role': 'member',
        'status': 'active',
        'display_name': null,
        'is_friend': false,
      });
      expect(m.label, 'Club friend'); // never a stranger's real handle
      expect(m.isFriend, isFalse);
    });
  });

  group('ClubOutcome', () {
    test('parses tokens and classifies success', () {
      expect(ClubOutcome.parse('ok'), ClubOutcome.ok);
      expect(ClubOutcome.parse('not_friends'), ClubOutcome.notFriends);
      expect(ClubOutcome.parse('age_restricted'), ClubOutcome.ageRestricted);
      expect(ClubOutcome.parse('full'), ClubOutcome.full);
      expect(ClubOutcome.parse('mystery'), ClubOutcome.unknown);
      expect(ClubOutcome.ok.isSuccess, isTrue);
      expect(ClubOutcome.completed.isSuccess, isTrue);
      expect(ClubOutcome.notFriends.isSuccess, isFalse);
    });
  });

  group('ClubRepository gating (kSocialLive)', () {
    test('live social is on by default in this build', () {
      expect(kSocialLive, isTrue);
    });

    test('the repository is available when live', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // No I/O on construction; live club RPCs are covered server-side.
      expect(container.read(clubRepositoryProvider), isNotNull);
    });
  });
}
