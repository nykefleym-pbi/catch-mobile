/// The kind of diary moment.
enum DiaryKind { met, milestone, note }

/// A single entry in a cat's private diary — owner-only, and deliberately
/// **never** carrying precise coordinates (only a coarse `locationLabel`).
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.catId,
    required this.kind,
    required this.createdAt,
    this.body,
    this.locationLabel,
  });

  final String id;
  final String catId;
  final DiaryKind kind;
  final DateTime createdAt;
  final String? body;

  /// A coarse, human-readable place label (e.g. "Downtown") — never lat/lng.
  final String? locationLabel;

  /// Row shape for a Postgres insert. Deliberately omits any coordinate key —
  /// the diary stores only a coarse label, upholding the location bright line.
  Map<String, dynamic> toRow(String profileId) => {
        'cat_id': catId,
        'profile_id': profileId,
        'kind': kind.name,
        if (body != null) 'body': body,
        if (locationLabel != null) 'location_label': locationLabel,
      };

  /// JSON shape for the on-device store (minor mode / no session).
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'cat_id': catId,
        'kind': kind.name,
        'body': body,
        'location_label': locationLabel,
        'created_at': createdAt.toIso8601String(),
      };

  factory DiaryEntry.fromMap(Map<String, dynamic> map) => DiaryEntry(
        id: map['id'] as String? ?? '',
        catId: map['cat_id'] as String? ?? '',
        kind: DiaryKind.values.firstWhere(
          (k) => k.name == map['kind'],
          orElse: () => DiaryKind.note,
        ),
        body: map['body'] as String?,
        locationLabel: map['location_label'] as String?,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
