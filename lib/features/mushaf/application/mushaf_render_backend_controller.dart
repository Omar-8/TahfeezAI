import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/mushaf_render_backend.dart';

part 'mushaf_render_backend_controller.g.dart';

const _mushafRenderBackendPrefKey = 'mushaf.renderBackend';

/// The persisted Mushaf rendering backend selection —
/// [MushafRenderBackend.qpcV2] by default, matching the current, unchanged
/// production behavior (per the migration's Stage 1: "old QPC still
/// available internally," never flipped as a side effect of adding the new
/// backend).
///
/// [MushafRenderBackend.quranEngine] can only ever be selected in a
/// non-release build (`!kReleaseMode`) — this is deliberately *not* a
/// user-facing Settings toggle yet: exposing an in-progress rendering
/// backend as a real preference before the full feature-parity acceptance
/// matrix passes (`docs/QURAN_ENGINE_MIGRATION.md`) would let a production
/// user land on an incomplete experience. [setBackend] silently refuses a
/// [MushafRenderBackend.quranEngine] request in a release build rather than
/// throwing, so a stray internal call path can never crash a release build
/// — it simply has no effect, leaving the persisted QPC V2 selection
/// unchanged.
@Riverpod(keepAlive: true)
class MushafRenderBackendController extends _$MushafRenderBackendController {
  @override
  MushafRenderBackend build() {
    _restore();
    return MushafRenderBackend.qpcV2;
  }

  Future<void> _restore() async {
    if (kReleaseMode) return;
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_mushafRenderBackendPrefKey);
    for (final backend in MushafRenderBackend.values) {
      if (backend.name == stored && backend != state) {
        state = backend;
        return;
      }
    }
  }

  Future<void> setBackend(MushafRenderBackend backend) async {
    if (backend == MushafRenderBackend.quranEngine && kReleaseMode) return;
    state = backend;
    await ref
        .read(browserStorageProvider)
        .setString(_mushafRenderBackendPrefKey, backend.name);
  }
}
