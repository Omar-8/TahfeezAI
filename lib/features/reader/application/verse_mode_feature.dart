import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the verse-by-verse reading mode exists at all.
///
/// Off by default: the reader is Mushaf-only. When off, the mode switch is
/// hidden, a persisted verse-by-verse preference is ignored, and nothing the
/// mode needs is loaded -- in particular the per-location reading session
/// (`readerSessionProvider`, which loads a whole chapter's words and
/// translations) is never built, and the verse-by-verse font/display data
/// is never touched. Tests that exercise the mode override this to `true`.
final verseByVerseModeEnabledProvider = Provider<bool>((ref) => false);
