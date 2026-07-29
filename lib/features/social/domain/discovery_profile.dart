import 'package:flutter/foundation.dart';

/// One adult, opted-in cat-keeper as returned by the `list_discovery_profiles`
/// RPC (migration 0022). Deliberately **data-minimised**: it carries only a
/// rotatable friend code ([handle]) and an aggregate [catsCount] — no name, no
/// email, no location of any precision, and never the cats themselves (the
/// showcase stays friends-only). Discovery is the one surface that reaches
/// beyond a known code, so it exposes as little as possible (ADR 0004).
@immutable
class DiscoveryProfile {
  const DiscoveryProfile({
    required this.id,
    required this.handle,
    required this.catsCount,
  });

  /// The profile id — used only to send a friend request or to report/block.
  final String id;

  /// The keeper's rotatable friend code (their shareable handle).
  final String handle;

  /// How many companions they keep — an aggregate, non-identifying signal.
  final int catsCount;

  factory DiscoveryProfile.fromRow(Map<String, dynamic> row) => DiscoveryProfile(
        id: row['id'] as String,
        handle: (row['handle'] as String?)?.trim() ?? '',
        catsCount: (row['cats_count'] as num?)?.toInt() ?? 0,
      );
}
