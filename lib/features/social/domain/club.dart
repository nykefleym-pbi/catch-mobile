import 'package:flutter/foundation.dart';

/// The kind of gentle, cooperative goal a club works toward together. All are
/// *caring* actions — there is no competitive or spend-driven kind (no
/// pay-to-win, ADR 0004).
enum ClubChallengeKind {
  care('care', 'Caring together', '🍲'),
  play('play', 'Playing together', '🧶'),
  groom('groom', 'Grooming together', '🛁');

  const ClubChallengeKind(this.token, this.label, this.emoji);

  final String token;
  final String label;
  final String emoji;

  static ClubChallengeKind fromToken(String? token) => switch (token) {
        'play' => ClubChallengeKind.play,
        'groom' => ClubChallengeKind.groom,
        _ => ClubChallengeKind.care,
      };
}

/// A club's single active shared goal: a collective progress bar the members
/// fill by caring for their own cats. Completing it grants a celebratory state
/// only — never an ownable/tradable reward, never power.
@immutable
class ClubChallenge {
  const ClubChallenge({
    required this.kind,
    required this.goal,
    required this.progress,
    required this.completed,
  });

  final ClubChallengeKind kind;
  final int goal;
  final int progress;
  final bool completed;

  double get fraction => goal <= 0 ? 0 : (progress / goal).clamp(0.0, 1.0);
}

/// A small, friends-based club with a shared goal. Built from a `list_my_clubs`
/// row: the caller's own role/status plus the active challenge (if any).
@immutable
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.myRole,
    required this.myStatus,
    required this.memberCount,
    this.challenge,
  });

  final String id;
  final String name;
  final String myRole; // 'owner' | 'member'
  final String myStatus; // 'invited' | 'active' | 'left'
  final int memberCount;
  final ClubChallenge? challenge;

  bool get isOwner => myRole == 'owner';
  bool get isInvited => myStatus == 'invited';
  bool get isActive => myStatus == 'active';

  factory Club.fromRow(Map<String, dynamic> row) {
    final goal = row['challenge_goal'] as int?;
    return Club(
      id: row['club_id'] as String,
      name: (row['name'] as String?) ?? 'Club',
      myRole: (row['my_role'] as String?) ?? 'member',
      myStatus: (row['my_status'] as String?) ?? 'active',
      memberCount: (row['member_count'] as int?) ?? 0,
      challenge: goal == null
          ? null
          : ClubChallenge(
              kind: ClubChallengeKind.fromToken(
                  row['challenge_kind'] as String?),
              goal: goal,
              progress: (row['challenge_progress'] as int?) ?? 0,
              completed: (row['challenge_status'] as String?) == 'completed',
            ),
    );
  }
}

/// A co-member of a club. The display name is present ONLY when this member is
/// the viewer's accepted friend (or the viewer themself); otherwise it is null
/// and they are shown anonymously — a minor never learns a stranger's handle
/// even inside a shared club (enforced server-side in `list_club_members`).
@immutable
class ClubMember {
  const ClubMember({
    required this.profileId,
    required this.role,
    required this.status,
    required this.isFriend,
    this.displayName,
  });

  final String profileId;
  final String role;
  final String status;
  final bool isFriend;
  final String? displayName;

  bool get isOwner => role == 'owner';
  bool get isInvited => status == 'invited';

  /// A friendly label that never leaks a stranger's identity.
  String get label {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Club friend';
  }

  factory ClubMember.fromRow(Map<String, dynamic> row) => ClubMember(
        profileId: row['profile_id'] as String,
        role: (row['role'] as String?) ?? 'member',
        status: (row['status'] as String?) ?? 'active',
        isFriend: row['is_friend'] == true,
        displayName: row['display_name'] as String?,
      );
}

/// The typed outcome of a club RPC — parses the status tokens the server RPCs
/// return into gentle, player-facing messages.
enum ClubOutcome {
  ok,
  restricted,
  ageRestricted,
  notMember,
  notOwner,
  notFriends,
  targetAge,
  blocked,
  full,
  exists,
  noInvite,
  badName,
  badGoal,
  badKind,
  tooMany,
  activeExists,
  noChallenge,
  completed,
  dissolved,
  declined,
  unauthenticated,
  unknown;

  static ClubOutcome parse(String? token) => switch (token) {
        'ok' => ClubOutcome.ok,
        'restricted' => ClubOutcome.restricted,
        'age_restricted' => ClubOutcome.ageRestricted,
        'not_member' => ClubOutcome.notMember,
        'not_owner' => ClubOutcome.notOwner,
        'not_friends' => ClubOutcome.notFriends,
        'target_age' => ClubOutcome.targetAge,
        'blocked' => ClubOutcome.blocked,
        'full' => ClubOutcome.full,
        'exists' => ClubOutcome.exists,
        'no_invite' => ClubOutcome.noInvite,
        'bad_name' => ClubOutcome.badName,
        'bad_goal' => ClubOutcome.badGoal,
        'bad_kind' => ClubOutcome.badKind,
        'too_many' => ClubOutcome.tooMany,
        'active_exists' => ClubOutcome.activeExists,
        'no_challenge' => ClubOutcome.noChallenge,
        'completed' => ClubOutcome.completed,
        'dissolved' => ClubOutcome.dissolved,
        'declined' => ClubOutcome.declined,
        'unauthenticated' => ClubOutcome.unauthenticated,
        _ => ClubOutcome.unknown,
      };

  bool get isSuccess =>
      this == ClubOutcome.ok ||
      this == ClubOutcome.completed ||
      this == ClubOutcome.dissolved ||
      this == ClubOutcome.declined;

  String get message => switch (this) {
        ClubOutcome.ok => 'Done! 🐾',
        ClubOutcome.completed => 'Goal complete — wonderful teamwork! 🎉',
        ClubOutcome.dissolved => 'Club closed.',
        ClubOutcome.declined => 'Invitation declined.',
        ClubOutcome.restricted => "That isn't available on your account.",
        ClubOutcome.ageRestricted => 'Clubs are part of the older experience.',
        ClubOutcome.notMember => "You're not in this club.",
        ClubOutcome.notOwner => 'Only the club owner can do that.',
        ClubOutcome.notFriends => 'You can only invite an accepted friend.',
        ClubOutcome.targetAge => "That friend can't join clubs yet.",
        ClubOutcome.blocked => "Can't invite that person right now.",
        ClubOutcome.full => 'This club is full (8 is our cozy maximum).',
        ClubOutcome.exists => "They're already in this club (or invited).",
        ClubOutcome.noInvite => 'That invitation is no longer here.',
        ClubOutcome.badName => 'Please give your club a name.',
        ClubOutcome.badGoal => 'Please choose a small, reachable goal.',
        ClubOutcome.badKind => "That goal type isn't available.",
        ClubOutcome.tooMany => "You've made a lot of clubs already.",
        ClubOutcome.activeExists => 'This club already has a goal on the go.',
        ClubOutcome.noChallenge => 'No active goal to add to yet.',
        ClubOutcome.unauthenticated => 'Please sign in first.',
        ClubOutcome.unknown => 'Something went wrong — try again.',
      };
}
