import 'package:flutter/material.dart';

/// A single-select segmented control (mode switches — verse-by-verse /
/// Mushaf / translation reading mode is the canonical future use, per
/// `docs/reference/04_READER_SPEC.md` §3's mode tabs). A thin, generically-
/// typed wrapper over [SegmentedButton] so call sites don't repeat its
/// verbose segment-building boilerplate.
class TahfeezSegmentedControl<T extends Object> extends StatelessWidget {
  const TahfeezSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: [
        for (final entry in options.entries)
          ButtonSegment(value: entry.key, label: Text(entry.value)),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
