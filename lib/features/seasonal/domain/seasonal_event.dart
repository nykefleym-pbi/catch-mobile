import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A cozy seasonal theme layered over the app: a name, a warm greeting, and a
/// small set of already-permanent cosmetics (collars + nook decor) that are
/// simply *featured* this season. Nothing here is time-limited — seasonal
/// items are earned by bond like any other cosmetic and never expire
/// (docs/product/01-vision.md: no manipulative FOMO, no dark patterns).
@immutable
class SeasonalEvent {
  const SeasonalEvent({
    required this.id,
    required this.name,
    required this.emoji,
    required this.greeting,
    required this.accent,
    required this.featuredCollarIds,
    required this.featuredDecorIds,
  });

  final String id;
  final String name;
  final String emoji;
  final String greeting;

  /// A soft accent colour for the seasonal hero/banner.
  final Color accent;

  /// Ids into [kCollars] — featured, not exclusive; earnable by bond, forever.
  final List<String> featuredCollarIds;

  /// Ids into [kDecor] — featured, not exclusive; earnable by bond, forever.
  final List<String> featuredDecorIds;
}

const _spring = SeasonalEvent(
  id: 'spring',
  name: 'Spring Blossoms',
  emoji: '🌷',
  greeting: 'Soft petals and new beginnings — your cats are stretching in '
      'the first warm sun of the year.',
  accent: AppTheme.sage,
  featuredCollarIds: ['blossom'],
  featuredDecorIds: ['tulips'],
);

const _summer = SeasonalEvent(
  id: 'summer',
  name: 'Summer Sunbeams',
  emoji: '🌻',
  greeting: 'Long, lazy afternoons and warm windowsills — your cats are '
      'soaking up the sun.',
  accent: AppTheme.apricot,
  featuredCollarIds: ['sunflower'],
  featuredDecorIds: ['sun-lamp'],
);

const _autumn = SeasonalEvent(
  id: 'autumn',
  name: 'Autumn Leaves',
  emoji: '🍁',
  greeting: 'Crunchy leaves and cozy sweaters — your cats are curling up as '
      'the evenings turn crisp.',
  accent: AppTheme.terracotta,
  featuredCollarIds: ['maple'],
  featuredDecorIds: ['pumpkin'],
);

const _winter = SeasonalEvent(
  id: 'winter',
  name: 'Winter Hush',
  emoji: '❄️',
  greeting: 'Quiet snowfall and warm blankets — your cats are keeping close '
      'through the hush of winter.',
  accent: Color(0xFFA9C7D8),
  featuredCollarIds: ['snowflake'],
  featuredDecorIds: ['snow-globe'],
);

/// Deterministically maps a month to the active season, Northern-hemisphere
/// meteorological seasons (Mar–May spring, Jun–Aug summer, Sep–Nov autumn,
/// Dec–Feb winter).
///
/// TODO(hemisphere): this is Northern-hemisphere only for now; a future
/// refinement could flip the mapping for guardians south of the equator
/// (e.g. from locale or a settings toggle) — never from precise location.
SeasonalEvent activeSeasonalEvent(DateTime now) {
  switch (now.month) {
    case 3:
    case 4:
    case 5:
      return _spring;
    case 6:
    case 7:
    case 8:
      return _summer;
    case 9:
    case 10:
    case 11:
      return _autumn;
    default:
      return _winter;
  }
}
