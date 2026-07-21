import 'package:flutter/foundation.dart';

/// The four friendly contest modes, matching the `matches.mode` check constraint
/// in migration 0012. Each is a gentle, no-harm game of play — never a battle,
/// and the outcome is a keepsake, never a power reward (no pay-to-win).
enum MatchMode {
  zoomies('zoomies', 'Zoomie race', '💨',
      'A dash of happy chaos — who gets the zoomies fastest?'),
  agility('agility', 'Agility course', '🤸',
      'Weave and hop through a gentle obstacle course.'),
  treasure('treasure', 'Treasure hunt', '🔎',
      'Sniff out hidden toys — curiosity leads the way.'),
  toy('toy', 'Toy chase', '🧶', 'Chase the feather wand for pure joy.');

  const MatchMode(this.token, this.label, this.emoji, this.blurb);

  /// The stored token (`matches.mode`).
  final String token;
  final String label;
  final String emoji;
  final String blurb;

  static MatchMode? fromToken(String? token) {
    for (final m in MatchMode.values) {
      if (m.token == token) return m;
    }
    return null;
  }
}

/// A match row as read back from the `matches` table. RLS scopes reads to the
/// two participants (migration 0012); all writes go through the guarded RPCs.
@immutable
class Match {
  const Match({
    required this.id,
    required this.mode,
    required this.challengerId,
    required this.opponentId,
    required this.status,
    required this.winnerId,
  });

  final String id;
  final MatchMode? mode;
  final String challengerId;
  final String opponentId;

  /// One of invited / accepted / declined / cancelled / completed.
  final String status;
  final String? winnerId;

  bool get isInvited => status == 'invited';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';

  /// True when [viewerId] is the opponent of an open invite (can accept/decline).
  bool incomingFor(String viewerId) => opponentId == viewerId && isInvited;

  /// True when [viewerId] is the challenger of an open invite (can cancel).
  bool outgoingFor(String viewerId) => challengerId == viewerId && isInvited;

  /// The other participant's id, from [viewerId]'s point of view.
  String otherId(String viewerId) =>
      viewerId == challengerId ? opponentId : challengerId;

  factory Match.fromMap(Map<String, dynamic> map) => Match(
        id: map['id'] as String,
        mode: MatchMode.fromToken(map['mode'] as String?),
        challengerId: map['challenger_id'] as String,
        opponentId: map['opponent_id'] as String,
        status: (map['status'] as String?) ?? 'invited',
        winnerId: map['winner_id'] as String?,
      );
}
