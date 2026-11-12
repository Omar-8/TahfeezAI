import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/listen/domain/quran_audio_sources.dart';
import 'package:tahfeez_ai/features/listen/presentation/reciter_avatar.dart';
import 'package:tahfeez_ai/features/settings/domain/credits.dart';

/// A reciter is shown by his photo where a free one exists, else by his
/// initial on a colour of his own.
void main() {
  Reciter byEdition(String e) => reciters.firstWhere((r) => r.edition == e);

  test('every photo is a reciter of the app, its file shipped and small', () {
    final editions = {for (final r in reciters) r.edition};
    for (final MapEntry(:key, :value) in reciterPhotos.entries) {
      expect(editions, contains(key));
      final file = File('assets/reciters/$value.jpg');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), lessThan(30 * 1024), reason: file.path);
    }
  });

  test('every photo is credited (its licence asks for it)', () {
    final names = {for (final c in credits) c.name};
    for (final edition in reciterPhotos.keys.where(
      (e) => !e.startsWith('ar.husary') || e == 'ar.husary',
    )) {
      final reciter = byEdition(edition);
      expect(
        names.any(
          (n) => n.startsWith('Photo of ') && n.contains(_last(reciter)),
        ),
        isTrue,
        reason: reciter.nameEn,
      );
    }
  });

  test('the initial: the Arabic name\'s first letter, alef plain', () {
    expect(reciterInitial(byEdition('ar.alafasy')), 'م');
    expect(reciterInitial(byEdition('ar.ahmedajamy')), 'ا');
    expect(reciterInitial(byEdition('ar.shaatree')), 'ا');
  });

  test('a reciter keeps his colour; reciters differ', () {
    final a = ReciterAvatar.hueOf(byEdition('ar.alafasy'));
    expect(ReciterAvatar.hueOf(byEdition('ar.alafasy')), a);
    final hues = {for (final r in reciters) ReciterAvatar.hueOf(r).round()};
    expect(hues.length, greaterThan(reciters.length * 2 ~/ 3));
  });

  Future<void> pump(WidgetTester tester, Reciter reciter, Brightness b) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: b),
          home: Scaffold(
            body: Center(child: ReciterAvatar(reciter: reciter)),
          ),
        ),
      );

  testWidgets('a reciter with a photo shows it', (tester) async {
    await pump(tester, byEdition('ar.dossary'), Brightness.light);
    expect(find.byKey(const ValueKey('reciter-photo-ar.dossary')), findsOne);
    expect(
      find.byKey(const ValueKey('reciter-initial-ar.dossary')),
      findsNothing,
    );
  });

  testWidgets('Al-Husary\'s three recitations share his photo', (tester) async {
    for (final e in ['ar.husarymujawwad', 'ar.husarymuallim']) {
      expect(reciterPhotoAsset(byEdition(e)), 'assets/reciters/husary.jpg');
    }
  });

  testWidgets('one without shows his initial, in light and dark', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await pump(tester, byEdition('ar.hudhaify'), b);
      expect(
        find.byKey(const ValueKey('reciter-initial-ar.hudhaify')),
        findsOne,
      );
      expect(find.text('ع'), findsOne);
    }
  });

  testWidgets('decorative: the name beside it is what is read out', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, byEdition('ar.hudhaify'), Brightness.light);
    expect(find.bySemanticsLabel('ع'), findsNothing);
    handle.dispose();
  });

  testWidgets('the chosen reciter: his picture beside his name', (
    tester,
  ) async {
    final r = byEdition('ar.dossary');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReciterNameWithAvatar(reciter: r, name: r.nameEn),
        ),
      ),
    );
    final photo = tester.getCenter(
      find.byKey(const ValueKey('reciter-photo-ar.dossary')),
    );
    final name = tester.getCenter(find.text('Yasser Al-Dossary'));
    expect(photo.dx, lessThan(name.dx), reason: 'before it, in English');
    expect((photo.dy - name.dy).abs(), lessThan(4), reason: 'on its line');
  });
}

/// The last word of [reciter]'s English name ("Al-Dossary").
String _last(Reciter reciter) =>
    reciter.nameEn.replaceAll(RegExp(r'\s*\(.*\)'), '').split(' ').last;
