import 'package:flutter/foundation.dart';

/// The result of filing a report through the server-side `submit_report` RPC
/// (migration 0009). The RPC is the single anti-abuse gate for the report
/// system: it rate-limits, de-duplicates, and refuses reports from restricted
/// accounts. Parsing the returned status string here keeps the UI honest about
/// what actually happened instead of pretending every tap succeeded.
enum ReportOutcome {
  ok('ok'),
  duplicate('duplicate'),
  rateLimited('rate_limited'),
  restricted('restricted'),
  unauthenticated('unauthenticated'),
  badTarget('bad_target'),
  badReason('bad_reason'),
  unknown('unknown');

  const ReportOutcome(this.token);

  final String token;

  static ReportOutcome fromToken(String? token) {
    for (final o in ReportOutcome.values) {
      if (o.token == token) return o;
    }
    return ReportOutcome.unknown;
  }

  /// Whether the report was actually recorded (a fresh `ok`). A `duplicate`
  /// counts as effectively handled — the earlier report is still open — so the
  /// UI can thank the player either way, but only `ok`/`duplicate` are success.
  bool get isSuccess => this == ReportOutcome.ok || this == ReportOutcome.duplicate;

  /// A gentle, player-facing line for each outcome. Never blames the player.
  String get message => switch (this) {
        ReportOutcome.ok =>
          'Thanks for looking out — our team will take a look.',
        ReportOutcome.duplicate =>
          'You\'ve already reported this. It\'s still in our queue.',
        ReportOutcome.rateLimited =>
          'That\'s a lot of reports in a short time. Please try again a little '
              'later.',
        ReportOutcome.restricted =>
          'Reporting isn\'t available on your account right now.',
        ReportOutcome.unauthenticated =>
          'Please sign in to send a report.',
        ReportOutcome.badTarget ||
        ReportOutcome.badReason ||
        ReportOutcome.unknown =>
          'Something went wrong sending that report. Please try again.',
      };
}

/// A kind of active limitation a moderator can place on an account
/// (migration 0009 `restrictions.kind`). Ordered least → most severe.
enum RestrictionKind {
  mute('mute'),
  suspend('suspend'),
  ban('ban');

  const RestrictionKind(this.token);

  final String token;

  static RestrictionKind? fromToken(String? token) {
    for (final k in RestrictionKind.values) {
      if (k.token == token) return k;
    }
    return null;
  }
}

/// A player's current account limitation, read from their own `restrictions`
/// row (RLS lets a player see only their own). Used to gently explain a limit
/// and to disable social actions client-side — the server enforces it too.
@immutable
class Restriction {
  const Restriction({
    required this.kind,
    this.reason,
    this.expiresAt,
  });

  final RestrictionKind kind;
  final String? reason;
  final DateTime? expiresAt;

  /// A muted player can still browse and care for cats but can't post/react;
  /// a suspended or banned player can't take social actions at all.
  bool get blocksSocialActions =>
      kind == RestrictionKind.suspend || kind == RestrictionKind.ban;

  bool get isActive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

  /// A short, non-punitive banner line.
  String get bannerMessage => switch (kind) {
        RestrictionKind.mute =>
          'Posting and reactions are paused on your account for now.',
        RestrictionKind.suspend =>
          'Social features are paused on your account for now.',
        RestrictionKind.ban =>
          'Social features aren\'t available on your account.',
      };

  static Restriction? fromMap(Map<String, dynamic> map) {
    final kind = RestrictionKind.fromToken(map['kind'] as String?);
    if (kind == null) return null;
    final expiresRaw = map['expires_at'];
    return Restriction(
      kind: kind,
      reason: map['reason'] as String?,
      expiresAt:
          expiresRaw is String ? DateTime.tryParse(expiresRaw)?.toLocal() : null,
    );
  }
}
