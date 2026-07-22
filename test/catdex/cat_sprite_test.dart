import 'package:catch_mobile/features/catdex/presentation/cat_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a null url renders a paw fallback, never a broken image',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CatSprite(url: null, size: 40)),
    ));
    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an empty url also falls back to the paw', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CatSprite(url: '', size: 40)),
    ));
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}
