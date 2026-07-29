import 'package:flutter/foundation.dart';

import 'collection_summary.dart';

/// A gentle, earnable milestone badge (roadmap p2: CatDex "achievement badges").
///
/// Every badge celebrates *care and collecting* — meeting cats, meeting new
/// personalities, walking new places, styling cosmetics. There is deliberately
/// **no** badge for spending, speed, streaks, or beating another player: in
/// keeping with the kindness-over-competition and no-pay-to-win pillars, and the
/// non-punitive design rule, a badge can only ever be *not yet earned* — never
/// lost, never time-pressured. All progress is derived purely from the player's
/// own [CollectionSummary].
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;

  /// Progress numerator (e.g. companions met so far) and the goal it counts
  /// toward. [current] is clamped for display; the raw value may exceed [goal].
  final int current;
  final int goal;

  bool get earned => current >= goal;

  /// Progress toward earning, 0–1. A zero goal reads as already complete so a
  /// misconfigured badge is never permanently locked.
  double get progress =>
      goal <= 0 ? 1.0 : (current / goal).clamp(0.0, 1.0);

  /// A soft "3 / 5" style label for the not-yet-earned state.
  String get progressLabel => '${current.clamp(0, goal)} / $goal';
}

/// The fixed catalogue of badges, plus the pure evaluator that scores them
/// against a collection. Kept deterministic: the same summary always yields the
/// same badges in the same order.
abstract final class AchievementBook {
  /// Score every badge against [summary]. Order is stable (catalogue order);
  /// the presentation layer chooses how to group earned vs. in-progress.
  static List<Achievement> evaluate(CollectionSummary summary) {
    return [
      Achievement(
        id: 'first_friend',
        emoji: '🐾',
        title: 'First Friend',
        description: 'Meet your very first companion.',
        current: summary.totalCats,
        goal: 1,
      ),
      Achievement(
        id: 'growing_family',
        emoji: '🏡',
        title: 'Growing Family',
        description: 'Share your days with five companions.',
        current: summary.totalCats,
        goal: 5,
      ),
      Achievement(
        id: 'full_house',
        emoji: '🐈',
        title: 'Full House',
        description: 'Ten companions call your CatDex home.',
        current: summary.totalCats,
        goal: 10,
      ),
      Achievement(
        id: 'personality_explorer',
        emoji: '✨',
        title: 'Personality Explorer',
        description: 'Meet cats of half the known personalities.',
        current: summary.traitsCollected,
        goal: (summary.traitsKnown / 2).ceil(),
      ),
      Achievement(
        id: 'every_personality',
        emoji: '🌈',
        title: 'Every Personality',
        description: 'Meet a cat of every known personality.',
        current: summary.traitsCollected,
        goal: summary.traitsKnown,
      ),
      Achievement(
        id: 'neighbourhood_wanderer',
        emoji: '🗺️',
        title: 'Neighbourhood Wanderer',
        description: 'Meet cats across five places on your walks.',
        current: summary.placesMet,
        goal: 5,
      ),
      Achievement(
        id: 'stylist',
        emoji: '🎀',
        title: 'Stylist',
        description: 'Style three companions with a cosmetic collar.',
        current: summary.collarsStyled,
        goal: 3,
      ),
    ];
  }

  /// How many badges are earned in [summary] — the "X of Y" showcase headline.
  static int earnedCount(CollectionSummary summary) =>
      evaluate(summary).where((a) => a.earned).length;
}
