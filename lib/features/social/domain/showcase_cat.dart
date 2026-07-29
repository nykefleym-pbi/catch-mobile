import 'package:flutter/foundation.dart';

/// One cat as returned by the `list_friend_showcase` RPC (migration 0014) when
/// visiting an accepted friend's showcase. It carries only safe, cosmetic
/// fields — deliberately **no location** of any precision — so visiting can
/// never reveal where a real cat was met (08-ethics R6).
@immutable
class ShowcaseCat {
  const ShowcaseCat({
    required this.id,
    required this.name,
    required this.nickname,
    required this.spriteUrl,
    required this.growthStage,
    required this.traitId,
  });

  final String id;
  final String? name;
  final String? nickname;
  final String? spriteUrl;
  final String growthStage;
  final String? traitId;

  /// The friendliest name to show: nickname, else name, else a gentle fallback.
  String get displayName {
    final n = (nickname != null && nickname!.trim().isNotEmpty)
        ? nickname!.trim()
        : (name != null && name!.trim().isNotEmpty ? name!.trim() : null);
    return n ?? 'A cat';
  }

  /// A human label for the growth stage (kitten → Kitten, etc.).
  String get growthLabel => switch (growthStage) {
        'kitten' => 'Kitten',
        'young' => 'Young',
        'adult' => 'Adult',
        'senior' => 'Senior',
        _ => 'Cat',
      };

  factory ShowcaseCat.fromRow(Map<String, dynamic> row) => ShowcaseCat(
        id: row['id'] as String,
        name: row['name'] as String?,
        nickname: row['nickname'] as String?,
        spriteUrl: row['sprite_url'] as String?,
        growthStage: (row['growth_stage'] as String?) ?? 'kitten',
        traitId: row['trait_id'] as String?,
      );
}
