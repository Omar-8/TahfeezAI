import 'package:flutter/material.dart';

import 'app.dart';

/// Shown for the (typically brief, but real on a cold/first launch — see
/// `bootstrap.dart`'s own doc comment) window while [BundledDatasetSeeder]
/// verifies/imports the bundled Quran dataset, before [TahfeezApp] itself
/// ever builds.
///
/// A real, measured cost this exists to stop from blocking the very first
/// Flutter frame: a cold seed (first launch, or a bundled-dataset version
/// bump) took ~1.3s for the canonical Quran alone and ~2.6s with the
/// (dev/profile-only) Mushaf dataset also included, timed against the real
/// bundled assets. Previously `bootstrap()` awaited this *before*
/// `runApp()`, so the OS's own native launch screen simply stayed up for
/// that whole window — on native that's an acceptable, if slow, "splash"
/// experience, but on Web (no native splash to lean on, and a real
/// possibility of paying the cold-seed cost on more than just the very
/// first visit, since browser storage/OPFS can be cleared) it read as a
/// blank/frozen tab. This shows *something* immediately instead, then
/// swaps to the real app the instant seeding finishes — never delaying it
/// further than the seeding itself already does.
class TahfeezBootstrapGate extends StatelessWidget {
  const TahfeezBootstrapGate({super.key, required this.seeding});

  /// The in-flight (already started in `bootstrap()`, before `runApp()`)
  /// [BundledDatasetSeeder.seedIfNeeded] call.
  final Future<void> seeding;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: seeding,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const TahfeezApp();
        }
        return const _BootstrapSplash();
      },
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    // Deliberately minimal and theme-independent: this shows before
    // `ThemeModeController`/locale/dynamic-color are ever read (that's
    // `TahfeezApp`'s own job, once seeding hands off to it), and only for
    // as long as seeding genuinely takes.
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
