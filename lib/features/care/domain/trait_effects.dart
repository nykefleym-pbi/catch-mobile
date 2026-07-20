import 'package:flutter/foundation.dart';

/// How a cat's personality [trait] gently modulates its care (roadmap p2:
/// "Personality effects: traits meaningfully modulate interactions and care").
///
/// Design rule, straight from the product's welfare-first pillar: personality
/// only ever makes a cat's life **kinder**, never harsher. Every decay
/// multiplier here is <= 1.0 (a trait can slow a need's drift, never speed it)
/// and every action bonus is >= 0 (a trait can deepen a reward, never dock it).
/// So a trait can never leave a cat worse cared-for than a trait-less one —
/// "when gameplay and welfare conflict, welfare wins."
///
/// The baseline (used for an unknown or absent trait) is the identity: all
/// multipliers 1.0, all bonuses 0, so care behaves exactly as before.
@immutable
class TraitCareEffects {
  const TraitCareEffects({
    this.hungerDecayMult = 1.0,
    this.happinessDecayMult = 1.0,
    this.hygieneDecayMult = 1.0,
    this.playDecayMult = 1.0,
    this.sleepRegenMult = 1.0,
    this.feedBondBonus = 0,
    this.feedHappinessBonus = 0,
    this.playBondBonus = 0,
    this.groomBondBonus = 0,
    this.groomHappinessBonus = 0,
  })  : assert(hungerDecayMult <= 1.0),
        assert(happinessDecayMult <= 1.0),
        assert(hygieneDecayMult <= 1.0),
        assert(playDecayMult <= 1.0),
        assert(sleepRegenMult >= 1.0),
        assert(feedBondBonus >= 0),
        assert(feedHappinessBonus >= 0),
        assert(playBondBonus >= 0),
        assert(groomBondBonus >= 0),
        assert(groomHappinessBonus >= 0);

  /// Per-need decay multipliers (<= 1.0 = drifts more slowly).
  final double hungerDecayMult;
  final double happinessDecayMult;
  final double hygieneDecayMult;
  final double playDecayMult;

  /// Sleep *recovers* while away; a multiplier >= 1.0 means it recovers faster.
  final double sleepRegenMult;

  /// Extra bond / happiness a care action grants for this personality.
  final int feedBondBonus;
  final int feedHappinessBonus;
  final int playBondBonus;
  final int groomBondBonus;
  final int groomHappinessBonus;

  static const TraitCareEffects baseline = TraitCareEffects();

  /// Warm, character-appropriate nudges. Kept intentionally small so care stays
  /// about the daily ritual, not min-maxing a trait.
  static const Map<String, TraitCareEffects> _byTrait = {
    // Loves mealtimes — feeding lands a little sweeter.
    'foodie': TraitCareEffects(feedHappinessBonus: 3, feedBondBonus: 1),
    // A champion napper — rests faster and barely frets about playtime.
    'lazy': TraitCareEffects(sleepRegenMult: 1.3, playDecayMult: 0.7),
    // Always up for a game — play deepens the bond that bit more.
    'playful': TraitCareEffects(playBondBonus: 1, happinessDecayMult: 0.85),
    // Unflappable — stays content and clean between fusses.
    'brave': TraitCareEffects(hygieneDecayMult: 0.8, happinessDecayMult: 0.9),
    // Endlessly entertained by the world — slower to crave play.
    'curious': TraitCareEffects(playDecayMult: 0.8),
    // Fastidious — keeps tidy far longer.
    'elegant': TraitCareEffects(hygieneDecayMult: 0.7),
    // Amuses itself — playtime need drifts gently.
    'mischievous': TraitCareEffects(playDecayMult: 0.85),
    // Loyal to the bone — every interaction bonds a touch more.
    'protective': TraitCareEffects(feedBondBonus: 1, playBondBonus: 1),
    // Self-sufficient wanderer — content and unhurried for play.
    'explorer': TraitCareEffects(happinessDecayMult: 0.85, playDecayMult: 0.9),
    // Soothed by gentle care — grooming reassures this one most.
    'shy': TraitCareEffects(groomHappinessBonus: 3, happinessDecayMult: 0.9),
  };

  /// The effects for [traitId], or the identity [baseline] for null/unknown.
  static TraitCareEffects forTrait(String? traitId) =>
      traitId == null ? baseline : (_byTrait[traitId] ?? baseline);
}
