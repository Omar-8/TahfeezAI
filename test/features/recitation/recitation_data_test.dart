import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/file_storage.dart';
import 'package:tahfeez_ai/features/recitation/data/browser_storage_recitation_session_repository.dart';
import 'package:tahfeez_ai/features/recitation/data/file_recitation_recording_store.dart';
import 'package:tahfeez_ai/features/recitation/data/wav_header.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_audio_format.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_session.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

class _TempFileStorage implements FileStorage {
  _TempFileStorage(this.root);
  final String root;

  @override
  Future<String> appDataDirectoryPath() async => root;
  @override
  Future<String> cacheDirectoryPath() async => root;
  @override
  Future<String> temporaryExportDirectoryPath() async => root;
}

class _MemoryBrowserStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}

  final values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  const format = RecitationAudioFormat.speech;

  test('wavHeader describes 16 kHz mono PCM16 with the given length', () {
    final header = ByteData.sublistView(wavHeader(format, 32000));

    expect(String.fromCharCodes(header.buffer.asUint8List(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), 36 + 32000);
    expect(String.fromCharCodes(header.buffer.asUint8List(8, 4)), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 32000);
  });

  group('FileRecitationRecordingStore', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('recitation'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('streams chunks into one WAV file and patches its header', () async {
      final store = FileRecitationRecordingStore(_TempFileStorage(temp.path));
      final sink = await store.open(sessionId: 's1', format: format);
      sink.add(Uint8List(1000)..fillRange(0, 1000, 7));
      sink.add(Uint8List(600)..fillRange(0, 600, 8));

      final path = await sink.close();

      final bytes = File(path!).readAsBytesSync();
      expect(path, endsWith('recitations/s1.wav'));
      expect(bytes.length, wavHeaderLength + 1600);
      expect(bytes.sublist(0, wavHeaderLength), wavHeader(format, 1600));
      expect(bytes[wavHeaderLength], 7);
      expect(bytes.last, 8);
    });

    test('discard deletes the partial file', () async {
      final store = FileRecitationRecordingStore(_TempFileStorage(temp.path));
      final sink = await store.open(sessionId: 's2', format: format);
      sink.add(Uint8List(10));

      await sink.discard();

      expect(File('${temp.path}/recitations/s2.wav').existsSync(), isFalse);
    });
  });

  test('session repository round-trips sessions, newest first', () async {
    final storage = _MemoryBrowserStorage();
    final repository = BrowserStorageRecitationSessionRepository(storage);
    final older = RecitationSession(
      id: 'a',
      startedAt: DateTime.utc(2026, 9, 1),
      endedAt: DateTime.utc(2026, 9, 1, 0, 5),
      duration: const Duration(minutes: 4),
      recordingReference: '/data/recitations/a.wav',
      startLocation: const QuranLocation.page(1, 3),
    );
    final newer = RecitationSession(
      id: 'b',
      startedAt: DateTime.utc(2026, 9, 2),
    );

    await repository.save(older);
    await repository.save(newer);
    await repository.save(older.copyWith(duration: const Duration(minutes: 5)));

    final sessions = await repository.list();
    expect(sessions.map((s) => s.id), ['b', 'a']);
    final a = sessions.last;
    expect(a.startedAt, older.startedAt);
    expect(a.endedAt, older.endedAt);
    expect(a.duration, const Duration(minutes: 5));
    expect(a.recordingReference, older.recordingReference);
    expect(a.startLocation, const QuranLocation.page(1, 3));
  });

  test('session repository tolerates corrupt storage', () async {
    final storage = _MemoryBrowserStorage()
      ..values[BrowserStorageRecitationSessionRepository.storageKey] = '{nope';
    final repository = BrowserStorageRecitationSessionRepository(storage);

    expect(await repository.list(), isEmpty);
  });
}
