import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Each surah's name as the Mushaf writes it, in calligraphy: outlines
/// taken from the Quran Engine page corpus
/// (`tool/quran_engine/extract_surah_names.mjs`;
/// `docs/THIRD_PARTY_RESOURCES.md`).
class SurahNameArt {
  SurahNameArt(this.size, this._d, {required this.evenOdd});

  /// Its box, in page units.
  final Size size;
  final String _d;
  final bool evenOdd;

  late final Path path = _parse(_d)
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;

  /// An SVG path of absolute M, L, Q, C and Z commands.
  static Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[MLQCZ]|-?[\d.]+').allMatches(d);
    var command = '';
    final args = <double>[];
    void flush() {
      switch (command) {
        case 'M':
          path.moveTo(args[0], args[1]);
        case 'L':
          path.lineTo(args[0], args[1]);
        case 'Q':
          path.quadraticBezierTo(args[0], args[1], args[2], args[3]);
        case 'C':
          path.cubicTo(args[0], args[1], args[2], args[3], args[4], args[5]);
      }
      args.clear();
    }

    for (final t in tokens) {
      final s = t.group(0)!;
      if (s == 'Z') {
        flush();
        path.close();
        command = '';
      } else if ('MLQC'.contains(s)) {
        flush();
        command = s;
      } else {
        args.add(double.parse(s));
      }
    }
    flush();
    return path;
  }
}

/// The 114 surahs' names in calligraphy, by number.
final surahNameArtProvider = FutureProvider<Map<int, SurahNameArt>>((
  ref,
) async {
  final raw = jsonDecode(
    await rootBundle.loadString('assets/quran/surah_names/surah_names.json'),
  ) as Map<String, Object?>;
  return {
    for (final MapEntry(key: n, value: v)
        in (raw['names']! as Map<String, Object?>).entries)
      int.parse(n): switch (v! as Map<String, Object?>) {
        final m => SurahNameArt(
          Size((m['w']! as num).toDouble(), (m['h']! as num).toDouble()),
          m['d']! as String,
          evenOdd: m['evenOdd'] == true,
        ),
      },
  };
});

/// Surah [surahNo]'s name in the Mushaf's calligraphy, [height] tall (its
/// width as the name needs, up to [maxWidth]), in [color] — else the
/// text's colour. Nothing until the names are loaded.
class SurahNameCalligraphy extends ConsumerWidget {
  const SurahNameCalligraphy({
    super.key,
    required this.surahNo,
    this.height = 28,
    this.maxWidth = 110,
    this.color,
    this.semanticLabel,
  });

  final int surahNo;
  final double height, maxWidth;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(surahNameArtProvider).value?[surahNo];
    if (art == null) return const SizedBox.shrink();
    final scale = height / art.size.height;
    final width = (art.size.width * scale).clamp(0.0, maxWidth);
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          child: CustomPaint(
            size: art.size,
            painter: _ArtPainter(
              art,
              color ??
                  DefaultTextStyle.of(context).style.color ??
                  Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.color);

  final SurahNameArt art;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    art.path,
    Paint()
      ..color = color
      ..isAntiAlias = true,
  );

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art || old.color != color;
}
