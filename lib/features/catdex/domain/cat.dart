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
    this.lat,
    this.lng,
    this.collarId,
  });

  final String id;
  final String name;
  final String? spriteUrl;
  final String? traitId;
  final Map<String, dynamic> generationMeta;
  final DateTime? discoveredAt;

  /// The equipped cosmetic collar id (from `cats.cosmetic_collar`), or null for
  /// no collar. Matches the client collar catalogue (features/wardrobe).
  final String? collarId;

  /// Coarse, privacy-fuzzed coordinates of where this cat was met (~1 km).
  /// Null when the catch was made with location off. Used only for the map pin.
  final double? lat;
  final double? lng;

  /// Whether this cat can be dropped on the Explore map.
  bool get hasLocation => lat != null && lng != null;

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

  /// A characterful backstory for the reveal + detail pages. Prefers the
  /// generated [blurb]; otherwise falls back to a warm, trait-flavoured line so
  /// every cat — old or new — arrives with a little story of its own.
  String get story {
    final generated = blurb;
    if (generated != null) return generated;
    final trait = traitId;
    if (trait != null && _traitStories.containsKey(trait)) {
      return _traitStories[trait]!;
    }
    return 'A gentle wanderer who picked your neighbourhood to call home.';
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
      lat: _toDouble(map['geo_lat']),
      lng: _toDouble(map['geo_lng']),
      collarId: map['cosmetic_collar'] as String?,
    );
  }
}

/// Numeric columns can arrive as [int], [double], or a string over the wire.
double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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

/// Warm, trait-flavoured backstories used when a cat has no generated blurb —
/// so every companion still reads as a little character, not a blank card.
const Map<String, String> _traitStories = {
  'curious': 'Nose into everything, this one — every open door is a mystery '
      'worth solving.',
  'brave': 'Fears neither vacuum nor thunder; guards the windowsill like a '
      'tiny, fearless knight.',
  'lazy': 'A connoisseur of sunbeams and long afternoons, with a full-time '
      'career in napping.',
  'foodie': 'Believes every doorstep hides a snack, and greets each meal like '
      'a small festival.',
  'mischievous': 'Knocks pens off tables purely for science, then blinks at '
      'you with total innocence.',
  'elegant': 'Moves like poured cream and expects — quite reasonably — to be '
      'admired.',
  'playful': 'Would chase a leaf to the ends of the earth, then present it to '
      'you as treasure.',
  'protective': 'Keeps a careful eye on their people and their patch, always '
      'the first to check on a noise.',
  'explorer': 'Maps the whole neighbourhood one fence at a time, home only for '
      'dinner and a debrief.',
  'shy': 'Watches from beneath the sofa at first, but once you have won them '
      'over, you have won a friend for life.',
};

String _titleCase(String value) =>
    value[0].toUpperCase() + value.substring(1);
