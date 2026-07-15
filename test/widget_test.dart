import 'package:catch_mobile/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the Explore (map) destination', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CatchApp()));
    await tester.pumpAndSettle();

    // The bottom navigation and the landing placeholder should be present.
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('CatDex'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
  });
}
