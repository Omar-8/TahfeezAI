import 'package:flutter/material.dart';

import '../domain/quran_audio_sources.dart';

/// The reciters with a photo from Wikimedia Commons
/// (`docs/THIRD_PARTY_RESOURCES.md`: ten with a checked source, eight more
/// whose uploader's licence could not be verified — used by the owner's
/// decision, 2026-11-11, and removed if their rights holder asks), by
/// edition → the photo's file in `assets/reciters/`. Al-Husary's three
/// recitations share one. Any other reciter gets his initial.
const reciterPhotos = {
  'ar.husary': 'husary',
  'ar.husarymujawwad': 'husary',
  'ar.husarymuallim': 'husary',
  'ar.minshawi': 'minshawi',
  'ar.abdulbasitmurattal': 'abdulbasit',
  'ar.abdurrahmaansudais': 'sudais',
  'ar.saoodshuraym': 'shuraym',
  'ar.dossary': 'dossary',
  'ar.qatami': 'qatami',
  'ar.parhizgar': 'parhizgar',
  'ar.mansoori': 'mansoori',
  'ar.muhammadjibreel': 'jibreel',
  'ar.alafasy': 'alafasy',
  'ar.mahermuaiqly': 'muaiqly',
  'ar.ghamdi': 'ghamdi',
  'ar.ahmedajamy': 'ajamy',
  'ar.aymanswoaid': 'suwaid',
  'ar.alijaber': 'alijaber',
  'ar.juhani': 'juhani',
  'ar.matroud': 'matroud',
};

/// [reciter]'s photo's asset, if he has one.
String? reciterPhotoAsset(Reciter reciter) =>
    switch (reciterPhotos[reciter.edition]) {
      final name? => 'assets/reciters/$name.jpg',
      null => null,
    };

/// The letter a reciter without a photo is shown by: his Arabic name's
/// first letter (an alef with hamza as a plain alef).
String reciterInitial(Reciter reciter) {
  final first = reciter.nameAr.trim().characters.first;
  return switch (first) {
    'أ' || 'إ' || 'آ' => 'ا',
    _ => first,
  };
}

/// A reciter's round picture: his photo where a free one exists, else his
/// initial on a soft colour of his own (the same every time, light or
/// dark) — decorative, his name being beside it.
class ReciterAvatar extends StatelessWidget {
  const ReciterAvatar({super.key, required this.reciter, this.size = 40});

  final Reciter reciter;
  final double size;

  /// [reciter]'s hue, 0–360: from his edition, so the same each run.
  static double hueOf(Reciter reciter) {
    var h = 0;
    for (final c in reciter.edition.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 360).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final asset = reciterPhotoAsset(reciter);
    final initial = _Initial(reciter: reciter, size: size);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: asset == null
              ? initial
              : Image.asset(
                  asset,
                  key: ValueKey('reciter-photo-${reciter.edition}'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  errorBuilder: (_, _, _) => initial,
                ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.reciter, required this.size});

  final Reciter reciter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = ReciterAvatar.hueOf(reciter);
    final background = HSLColor.fromAHSL(
      1,
      hue,
      dark ? 0.28 : 0.42,
      dark ? 0.26 : 0.88,
    ).toColor();
    final foreground = HSLColor.fromAHSL(
      1,
      hue,
      dark ? 0.45 : 0.40,
      dark ? 0.82 : 0.30,
    ).toColor();
    return ColoredBox(
      key: ValueKey('reciter-initial-${reciter.edition}'),
      color: background,
      child: Center(
        child: Text(
          reciterInitial(reciter),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: foreground,
            fontSize: size * 0.48,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// [reciter]'s small picture beside [name] (the reciter chosen, under a
/// "Reciter" title).
class ReciterNameWithAvatar extends StatelessWidget {
  const ReciterNameWithAvatar({
    super.key,
    required this.reciter,
    required this.name,
  });

  final Reciter reciter;
  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      spacing: 8,
      children: [
        ReciterAvatar(reciter: reciter, size: 24),
        Flexible(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
