import 'package:catch_mobile/features/catdex/domain/idle_motion.dart';
import 'package:catch_mobile/features/catdex/presentation/cat_idle_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdleMotion', () {
    test('null and unknown traits use the calm default', () {
      expect(IdleMotion.forTrait(null), same(IdleMotion.calm));
      expect(IdleMotion.forTrait('made_up'), same(IdleMotion.calm));
    });

    test('a lazy cat breathes slower than a playful one', () {
      expect(
        IdleMotion.forTrait('lazy').period,
        greaterThan(IdleMotion.forTrait('playful').period),
      );
    });

    test('every profile is subtle and well-formed', () {
      for (final id in const [
        'lazy',
        'playful',
        'mischievous',
        'elegant',
        'brave',
        null,
      ]) {
        final m = IdleMotion.forTrait(id);
        expect(m.period.inMilliseconds, greaterThan(0), reason: '$id');
        expect(m.bobPixels, greaterThanOrEqualTo(0), reason: '$id');
        expect(m.bobPixels, lessThan(12), reason: '$id'); // stays subtle
        expect(m.scaleAmplitude, greaterThanOrEqualTo(0), reason: '$id');
        expect(m.scaleAmplitude, lessThan(0.1), reason: '$id');
      }
    });
  });

  group('CatIdleSprite', () {
    testWidgets('shows the child still when reduce-motion is on', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CatIdleSprite(traitId: 'playful', child: Text('kitty')),
          ),
        ),
      );
      expect(find.text('kitty'), findsOneWidget);
      // No animation is running, so the tree settles immediately.
      await tester.pumpAndSettle();
      expect(find.text('kitty'), findsOneWidget);
    });

    testWidgets('renders the child while animating', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CatIdleSprite(child: Text('kitty')),
          ),
        ),
      );
      expect(find.text('kitty'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('kitty'), findsOneWidget);
      // Replace the tree so the running controller is disposed cleanly.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
