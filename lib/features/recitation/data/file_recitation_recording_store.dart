import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/storage/file_storage.dart';
import '../domain/recitation_audio_format.dart';
import '../domain/recitation_recording_store.dart';
import 'wav_header.dart';

/// Native (Android) store: streams each session to
/// `<app data>/recitations/<sessionId>.wav`, so memory use stays flat no
/// matter how long the session runs.
class FileRecitationRecordingStore implements RecitationRecordingStore {
  const FileRecitationRecordingStore(this._fileStorage);

  final FileStorage _fileStorage;

  @override
  Future<RecitationRecordingSink> open({
    required String sessionId,
    required RecitationAudioFormat format,
  }) async {
    final root = await _fileStorage.appDataDirectoryPath();
    final dir = Directory(p.join(root, 'recitations'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$sessionId.wav'));
    final sink = file.openWrite()..add(wavHeader(format, 0));
    return _WavFileSink(file, sink, format);
  }
}

class _WavFileSink implements RecitationRecordingSink {
  _WavFileSink(this._file, this._sink, this._format);

  final File _file;
  final IOSink _sink;
  final RecitationAudioFormat _format;
  int _dataLength = 0;
  bool _closed = false;

  @override
  void add(Uint8List chunk) {
    if (_closed) return;
    _sink.add(chunk);
    _dataLength += chunk.length;
  }

  @override
  Future<String?> close() async {
    if (_closed) return null;
    _closed = true;
    await _sink.flush();
    await _sink.close();
    // Patch the placeholder header with the real data length.
    final raf = await _file.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(wavHeader(_format, _dataLength));
    } finally {
      await raf.close();
    }
    return _file.path;
  }

  @override
  Future<void> discard() async {
    if (!_closed) {
      _closed = true;
      await _sink.close();
    }
    if (await _file.exists()) await _file.delete();
  }
}
