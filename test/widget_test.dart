import 'package:catch_mobile/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the Explore (map) destination', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CatchApp()));
    // Bounded pumps rather than pumpAndSettle: the Explore map issues network
    // tile requests and a best-effort location lookup that never fully settle
    // in a test harness. The bottom-nav labels render on the first frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('CatDex'), findsOneWidget);
    expect(find.text('Guardian'), findsOneWidget);
  });
}
