import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';

/// The destination for [QuranLocation.page] results specifically — every
/// other [QuranLocation] variant now opens the real
/// `lib/features/reader/presentation/reader_screen.dart` (Milestone 6).
/// Mushaf paging itself is Milestone 7's job, so this stays the same
/// "honest placeholder, not a fake screen" pattern
/// `QuranPlaceholderScreen`/`SearchPlaceholderScreen` used in Milestone 4,
/// narrowed to the one variant the reader still can't serve.
class QuranLocationStubScreen extends StatelessWidget {
  const QuranLocationStubScreen({super.key, required this.location});

  final QuranLocation location;

  String _describe() {
    return switch (location) {
      QuranLocationPage(:final pageNumber) => 'Page $pageNumber',
      _ => 'This location',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TahfeezAppBar(title: Text(_describe())),
      body: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: TahfeezEmptyView(
          icon: Icons.auto_stories_outlined,
          message:
              'Opening ${_describe()}.\n'
              'Mushaf paging arrives in a later milestone.',
        ),
      ),
    );
  }
}
