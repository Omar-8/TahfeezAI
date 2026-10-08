import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One request to turn the page: [direction] is `1` for the next page (or
/// spread) in reading order, `-1` for the previous one; or, with [page], to
/// go straight to that page (its spread). [id] makes every request
/// distinct, so two identical requests in a row both fire.
typedef MushafPageTurnRequest = ({int id, int direction, int? page});

/// Lets controls outside the Mushaf screen (the shell's bottom bar) ask the
/// on-screen `MushafPager` to turn one page — or one spread — forward or
/// back, or to go to a page. The pager listens for new requests.
class MushafPageTurnRequests extends Notifier<MushafPageTurnRequest?> {
  @override
  MushafPageTurnRequest? build() => null;

  void next() => _turn(1);

  void previous() => _turn(-1);

  /// Straight to [page] (e.g. back to the start of a looped range).
  void toPage(int page) =>
      state = (id: (state?.id ?? 0) + 1, direction: 0, page: page);

  void _turn(int direction) =>
      state = (id: (state?.id ?? 0) + 1, direction: direction, page: null);
}

final mushafPageTurnRequestsProvider =
    NotifierProvider<MushafPageTurnRequests, MushafPageTurnRequest?>(
      MushafPageTurnRequests.new,
    );
