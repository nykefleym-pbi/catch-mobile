/// A companion the player has caught — the CatDex's core entity.
///
/// Mirrors the `cats` row shape returned by both the `generate-companion` Edge
/// Function and a direct `cats` select (see docs/architecture/06-data-model.md).
class Cat {
  const Cat({
    required this.id,
    required this.name,
    this.spriteUrl,
    this.traitId,
    this.generationMeta = const {},
    this.discoveredAt,
  });

  final String id;
  final String name;
  final String? spriteUrl;
  final String? traitId;
  final Map<String, dynamic> generationMeta;
  final DateTime? discoveredAt;

  /// Human-friendly trait label (e.g. 'foodie' -> 'Foodie'). Falls back to a
  /// title-cased id for any trait added server-side we don't know about yet.
  String? get traitLabel {
    final id = traitId;
    if (id == null) return null;
    return _traitLabels[id] ?? (id.isEmpty ? null : _titleCase(id));
  }

  /// A short descriptive line pulled from generation metadata, if present.
  String? get blurb {
    final value = generationMeta['blurb'];
    return value is String && value.isNotEmpty ? value : null;
  }

  factory Cat.fromMap(Map<String, dynamic> map) {
    final rawMeta = map['generation_meta'];
    final discovered = map['discovered_at'];
    return Cat(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Mystery Cat',
      spriteUrl: map['sprite_url'] as String?,
      traitId: map['trait_id'] as String?,
      generationMeta:
          rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : const {},
      discoveredAt: discovered is String ? DateTime.tryParse(discovered) : null,
    );
  }
}

const Map<String, String> _traitLabels = {
  'curious': 'Curious',
  'brave': 'Brave',
  'lazy': 'Lazy',
  'foodie': 'Foodie',
  'mischievous': 'Mischievous',
  'elegant': 'Elegant',
  'playful': 'Playful',
  'protective': 'Protective',
  'explorer': 'Explorer',
  'shy': 'Shy',
};

String _titleCase(String value) =>
    value[0].toUpperCase() + value.substring(1);
