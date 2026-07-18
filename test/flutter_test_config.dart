import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs once before the whole test suite. Disable google_fonts' runtime HTTP
/// fetch so widget tests are deterministic and never touch the network (they
/// fall back to the platform font, which is fine for layout/text assertions).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
