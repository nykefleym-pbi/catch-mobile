import 'package:flutter/foundation.dart';

/// One row of the moderator review queue (from `mod_queue_v2`, migration 0018).
/// It carries the report plus how many total/open reports its target has drawn,
/// so a moderator can triage the most-flagged targets first.
@immutable
class ModReport {
  const ModReport({
    required this.reportId,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.detail,
    required this.status,
    required this.reportsTotal,
    required this.reportsOpen,
  });

  final String reportId;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? detail;
  final String status;
  final int reportsTotal;
  final int reportsOpen;

  /// True when the target is a player account (so a restriction can be issued);
  /// content targets (cat/trade/message/club) get an action logged but no ban.
  bool get targetIsProfile => targetType == 'profile';

  factory ModReport.fromRow(Map<String, dynamic> row) => ModReport(
        reportId: row['report_id'] as String,
        reporterId: row['reporter_id'] as String? ?? '',
        targetType: row['target_type'] as String? ?? 'unknown',
        targetId: row['target_id'] as String? ?? '',
        reason: row['reason'] as String? ?? '',
        detail: row['detail'] as String?,
        status: row['status'] as String? ?? 'open',
        reportsTotal: (row['reports_total'] as num?)?.toInt() ?? 1,
        reportsOpen: (row['reports_open'] as num?)?.toInt() ?? 1,
      );
}

/// A moderation decision on a report (matches the `mod_resolve_v2` action set).
enum ModActionKind {
  dismiss('dismiss', 'Dismiss', 'No action needed'),
  warn('warn', 'Warn', 'Log a warning'),
  restrict('restrict', 'Restrict', 'Warn + limit the account'),
  removeContent('remove_content', 'Remove content', 'Take the content down'),
  ban('ban', 'Ban', 'Remove from the community');

  const ModActionKind(this.token, this.label, this.hint);
  final String token;
  final String label;
  final String hint;
}

/// The account limit a resolution may attach (only when the target is a profile).
enum RestrictionKind {
  none('', 'No limit'),
  mute('mute', 'Mute'),
  suspend('suspend', 'Suspend'),
  ban('ban', 'Ban');

  const RestrictionKind(this.token, this.label);
  final String token;
  final String label;

  /// The server param — null for [RestrictionKind.none].
  String? get param => this == RestrictionKind.none ? null : token;
}

/// The outcome token a `mod_*_v2` RPC returns, mapped to a gentle message.
enum ModOutcome {
  ok,
  reviewing,
  forbidden,
  notFound,
  badAction,
  badKind,
  unknown;

  static ModOutcome parse(String? token) => switch (token) {
        'ok' => ModOutcome.ok,
        'reviewing' => ModOutcome.reviewing,
        'forbidden' => ModOutcome.forbidden,
        'not_found' => ModOutcome.notFound,
        'bad_action' => ModOutcome.badAction,
        'bad_kind' => ModOutcome.badKind,
        _ => ModOutcome.unknown,
      };

  bool get isSuccess => this == ModOutcome.ok || this == ModOutcome.reviewing;

  String get message => switch (this) {
        ModOutcome.ok => 'Done.',
        ModOutcome.reviewing => 'Claimed for review.',
        ModOutcome.forbidden => 'You are not a moderator.',
        ModOutcome.notFound => 'That report is no longer available.',
        ModOutcome.badAction => 'That action is not allowed.',
        ModOutcome.badKind => 'That restriction is not allowed.',
        ModOutcome.unknown => 'Something went wrong. Please try again.',
      };
}
