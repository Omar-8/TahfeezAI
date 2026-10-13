import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_turn.dart';
import '../domain/mushaf_appearance.dart';
import 'ayah_mode_page.dart';

/// Ayah mode's continuous layout: the Mushaf's pages one after another in a
/// single scroll, up into earlier pages and down into later ones.
///
/// Each page is still an [AyahModePage] — reporting its words, showing
/// hide mode and the recitation's marks — only laid in this one list
/// rather than its own. The page crossing the screen's upper quarter is
/// the page being read: reported through [onPageChanged] as a swipe
/// would, so the bar, its modes and Continue reading follow it. Page-turn
/// requests (the modes following the reciter, the reveal buttons) bring
/// that page — its ayah in turn, if it has one — into view.
class AyahModeContinuous extends ConsumerStatefulWidget {
  const AyahModeContinuous({
    super.key,
    required this.mushafId,
    required this.pageCount,
    required this.initialPageNumber,
    required this.onPageChanged,
  });

  final int mushafId;
  final int pageCount;
  final int initialPageNumber;
  final ValueChanged<int> onPageChanged;

  @override
  ConsumerState<AyahModeContinuous> createState() => _AyahModeContinuousState();
}

class _AyahModeContinuousState extends ConsumerState<AyahModeContinuous> {
  /// The page the list is laid out from: it starts at the top, earlier
  /// pages grow upwards from it (their loading never moves what is read).
  late int _anchor = widget.initialPageNumber;
  late int _current = widget.initialPageNumber;
  var _controller = ScrollController();
  var _pageKeys = <int, GlobalKey<AyahModePageState>>{};
  final _anchorKey = GlobalKey();

  /// The reader is dragging the list (not a scroll of ours).
  var _userScrolling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GlobalKey<AyahModePageState> _keyFor(int page) =>
      _pageKeys.putIfAbsent(page, GlobalKey<AyahModePageState>.new);

  var _updateScheduled = false;

  /// After the frame (the pages laid out where the scroll put them): the
  /// page crossing the screen's upper quarter.
  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updateCurrent();
    });
  }

  void _updateCurrent() {
    final list = context.findRenderObject();
    if (list is! RenderBox || !list.attached) return;
    final top = list.localToGlobal(Offset.zero).dy;
    final line = list.size.height / 4;
    for (final MapEntry(key: page, value: key) in _pageKeys.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy - top;
      if (y <= line && y + box.size.height > line) {
        if (page != _current) {
          setState(() => _current = page);
          widget.onPageChanged(page);
        }
        return;
      }
    }
  }

  /// Shows [page]: built nearby, scrolled to (its ayah in turn, or its
  /// top); farther, the list laid out afresh from it.
  void _goToPage(int page) {
    page = page.clamp(1, widget.pageCount);
    if (page == _current) return;
    final state = _pageKeys[page]?.currentState;
    if (state != null) {
      state.bringIntoView();
      return;
    }
    final old = _controller;
    setState(() {
      _anchor = page;
      _current = page;
      _controller = ScrollController();
      _pageKeys = {};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    widget.onPageChanged(page);
  }

  Widget _page(int page) => AyahModePage(
    key: _keyFor(page),
    mushafId: widget.mushafId,
    pageNumber: page,
    pageCount: widget.pageCount,
    colors: ref.watch(mushafAppearanceControllerProvider).colors,
    isCurrentPage: page == _current,
    scrollController: _controller,
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(mushafPageTurnRequestsProvider, (_, request) {
      if (request == null || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      _goToPage(request.page ?? _current + request.direction);
    });
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;
    return ColoredBox(
      color: colors.background,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth != 0) return false;
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _userScrolling = true;
            for (final key in _pageKeys.values) {
              key.currentState?.releasePin();
            }
          } else if (n is ScrollUpdateNotification) {
            _scheduleUpdate();
          } else if (n is ScrollEndNotification) {
            _scheduleUpdate();
            if (_userScrolling) {
              _userScrolling = false;
              // Where the reader stops is where Continue reading goes back to.
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _pageKeys[_current]?.currentState?.recordPosition(),
              );
            }
          }
          return false;
        },
        child: CustomScrollView(
          key: ValueKey('ayah-mode-continuous-$_anchor'),
          controller: _controller,
          center: _anchorKey,
          scrollCacheExtent: const ScrollCacheExtent.viewport(2),
          slivers: [
            // Earlier pages, upwards from the anchor.
            SliverList.builder(
              itemCount: _anchor - 1,
              itemBuilder: (context, i) => _page(_anchor - 1 - i),
            ),
            SliverList.builder(
              key: _anchorKey,
              itemCount: widget.pageCount - _anchor + 1,
              itemBuilder: (context, i) => _page(_anchor + i),
            ),
          ],
        ),
      ),
    );
  }
}
