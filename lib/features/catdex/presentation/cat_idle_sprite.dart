import 'package:flutter/material.dart';

import '../domain/idle_motion.dart';

/// Wraps a cat sprite in a soft, looping idle animation (a gentle breathe + bob)
/// flavoured by the cat's personality via [IdleMotion]. Respects the platform
/// "reduce motion" accessibility setting: when animations are disabled the
/// [child] is shown perfectly still, no controller runs.
class CatIdleSprite extends StatefulWidget {
  const CatIdleSprite({
    super.key,
    required this.child,
    this.traitId,
  });

  final Widget child;
  final String? traitId;

  @override
  State<CatIdleSprite> createState() => _CatIdleSpriteState();
}

class _CatIdleSpriteState extends State<CatIdleSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  IdleMotion get _motion => IdleMotion.forTrait(widget.traitId);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _motion.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the accessibility preference here (context is ready) and start or
    // stop the loop accordingly — this also re-runs if the setting changes.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    // A smooth ease so the breath feels alive, not mechanical.
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final t = curved.value; // 0..1..0 with reverse
        final scale = 1.0 + _motion.scaleAmplitude * t;
        final dy = -_motion.bobPixels * t;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
