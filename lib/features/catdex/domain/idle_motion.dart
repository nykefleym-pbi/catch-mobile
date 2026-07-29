import 'package:flutter/foundation.dart';

/// A gentle idle-animation profile for a cat sprite (roadmap p2: "skeletal/frame
/// idle animations"). We don't ship a real skeletal rig; instead each cat
/// breathes and bobs with a soft, looping motion whose pace and size are
/// flavoured by its personality — a lazy cat drifts slowly, a playful one has a
/// livelier bounce. Deliberately subtle: cozy ambient life, never distracting.
@immutable
class IdleMotion {
  const IdleMotion({
    required this.period,
    required this.bobPixels,
    required this.scaleAmplitude,
  });

  /// One full breath in/out cycle.
  final Duration period;

  /// Vertical bob amplitude in logical pixels.
  final double bobPixels;

  /// How much the sprite scales at the peak of a breath (e.g. 0.03 = +3%).
  final double scaleAmplitude;

  static const IdleMotion calm = IdleMotion(
    period: Duration(milliseconds: 1800),
    bobPixels: 2.5,
    scaleAmplitude: 0.025,
  );

  static const Map<String, IdleMotion> _byTrait = {
    'lazy': IdleMotion(
      period: Duration(milliseconds: 2600),
      bobPixels: 1.5,
      scaleAmplitude: 0.02,
    ),
    'playful': IdleMotion(
      period: Duration(milliseconds: 950),
      bobPixels: 4,
      scaleAmplitude: 0.045,
    ),
    'mischievous': IdleMotion(
      period: Duration(milliseconds: 1050),
      bobPixels: 3.5,
      scaleAmplitude: 0.04,
    ),
    'elegant': IdleMotion(
      period: Duration(milliseconds: 2000),
      bobPixels: 2,
      scaleAmplitude: 0.022,
    ),
    'brave': IdleMotion(
      period: Duration(milliseconds: 1600),
      bobPixels: 3,
      scaleAmplitude: 0.03,
    ),
  };

  /// The motion for [traitId], or the gentle [calm] default for null/unknown.
  static IdleMotion forTrait(String? traitId) =>
      traitId == null ? calm : (_byTrait[traitId] ?? calm);
}
