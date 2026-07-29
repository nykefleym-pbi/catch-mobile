import 'package:flutter/foundation.dart';

/// A row from the `list_friends()` RPC — one edge in the player's social graph,
/// exposing only the friend's id, display name, and status (data-minimization).
@immutable
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    required this.status,
    required this.isIncoming,
  });

  final String id;
  final String? displayName;

  /// 'pending' or 'accepted'.
  final String status;

  /// True when this is an incoming request awaiting the player's response.
  final bool isIncoming;

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : 'A guardian';

  factory Friend.fromRow(Map<String, dynamic> row) => Friend(
        id: row['friend_id'] as String,
        displayName: row['display_name'] as String?,
        status: row['status'] as String? ?? 'pending',
        isIncoming: row['is_incoming'] as bool? ?? false,
      );
}
