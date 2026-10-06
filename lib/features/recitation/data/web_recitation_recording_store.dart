import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/recitation_audio_format.dart';
import '../domain/recitation_recording_store.dart';
import 'wav_header.dart';

/// Web store: keeps the session's PCM chunks in memory and, on close,
/// wraps them in a single WAV `Blob` and returns its object URL.
///
/// The URL is only valid for the lifetime of the page — persisting web
/// recordings across reloads needs the IndexedDB/OPFS large-blob strategy
/// `BrowserStorage`'s doc comment defers to the Resource Manager milestone.
class WebRecitationRecordingStore implements RecitationRecordingStore {
  const WebRecitationRecordingStore();

  @override
  Future<RecitationRecordingSink> open({
    required String sessionId,
    required RecitationAudioFormat format,
  }) async => _WavBlobSink(format);
}

class _WavBlobSink implements RecitationRecordingSink {
  _WavBlobSink(this._format);

  final RecitationAudioFormat _format;
  final List<Uint8List> _chunks = [];
  int _dataLength = 0;
  bool _closed = false;

  @override
  void add(Uint8List chunk) {
    if (_closed) return;
    // The recorder may reuse its buffer; keep our own copy.
    _chunks.add(Uint8List.fromList(chunk));
    _dataLength += chunk.length;
  }

  @override
  Future<String?> close() async {
    if (_closed) return null;
    _closed = true;
    final parts = <JSAny>[
      wavHeader(_format, _dataLength).toJS,
      for (final chunk in _chunks) chunk.toJS,
    ].toJS;
    _chunks.clear();
    final blob = web.Blob(parts, web.BlobPropertyBag(type: 'audio/wav'));
    return web.URL.createObjectURL(blob);
  }

  @override
  Future<void> discard() async {
    _closed = true;
    _chunks.clear();
  }
}
