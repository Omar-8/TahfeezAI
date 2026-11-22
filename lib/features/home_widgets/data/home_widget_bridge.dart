import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/home_widget_payload.dart';

/// The home-screen widgets' platform adapter (owner, 2026-11-22): writes
/// what they show where Android's and the iPhone's widget code read it,
/// asks them to redraw, and says which one was tapped. Nothing else in the
/// app calls `home_widget`.
abstract class HomeWidgetBridge {
  /// Whether this platform has home-screen widgets (not the browser).
  bool get supported;

  /// Writes [payload] and redraws every widget.
  Future<void> publish(HomeWidgetPayload payload);

  /// Redraws the prayer widget at [prayerTimes] and the date-bound ones
  /// (the date, the daily ayah, memorization, the khatmah) at [midnights]
  /// (Android: while the app is closed; the iPhone's widgets keep their
  /// own timeline).
  Future<void> scheduleRedraws(
    List<DateTime> prayerTimes,
    List<DateTime> midnights,
  );

  /// The link the app was opened with from a widget, if it was.
  Future<Uri?> launchedWith();

  /// The links of the widgets tapped while the app runs.
  Stream<Uri?> get taps;
}

/// The App Group the iPhone's widget extension shares data through.
const homeWidgetAppGroup = 'group.ai.tahfeez.tahfeezAi';

/// Each widget's class on Android and kind on the iPhone.
String androidWidgetName(HomeWidgetKind kind) =>
    'ai.tahfeez.tahfeez_ai.widgets.${_pascal(kind.name)}Widget';
String iosWidgetKind(HomeWidgetKind kind) => 'Tahfeez${_pascal(kind.name)}';

String _pascal(String s) => s[0].toUpperCase() + s.substring(1);

/// The app's icons the widgets draw (from the app's own icon font, which
/// keeps only the icons the app uses): listed here so they stay in it.
const homeWidgetIcons = <IconData>[
  Icons.explore_outlined,
  Icons.record_voice_over_outlined,
  Icons.event_available_outlined,
  Icons.auto_stories_outlined,
  Icons.menu_book_outlined,
  Icons.school_outlined,
  Icons.auto_awesome_outlined,
  Icons.mosque_outlined,
  Icons.bookmark_outline,
  Icons.calendar_month_outlined,
  Icons.check_circle_rounded,
  Icons.radio_button_unchecked,
  Icons.wb_twilight_rounded,
  Icons.wb_sunny_rounded,
  Icons.nightlight_round,
  Icons.event_outlined,
];

/// The key the payload is stored under.
const homeWidgetDataKey = 'tahfeez.widgets';

class PluginHomeWidgetBridge implements HomeWidgetBridge {
  var _grouped = false;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _group() async {
    if (_grouped || defaultTargetPlatform != TargetPlatform.iOS) return;
    await HomeWidget.setAppGroupId(homeWidgetAppGroup);
    _grouped = true;
  }

  @override
  Future<void> publish(HomeWidgetPayload payload) async {
    // (Their icons kept in the app's font: see [homeWidgetIcons].)
    if (homeWidgetIcons.isEmpty) return;
    await _group();
    await HomeWidget.saveWidgetData<String>(
      homeWidgetDataKey,
      payload.encode(),
    );
    for (final kind in HomeWidgetKind.values) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidWidgetName(kind),
        iOSName: iosWidgetKind(kind),
      );
    }
  }

  @override
  Future<void> scheduleRedraws(
    List<DateTime> prayerTimes,
    List<DateTime> midnights,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    // The prayer times move on at each prayer; Home's (date, times,
    // buttons) at both.
    await HomeWidget.scheduleWidgetUpdates(
      [...prayerTimes, ...midnights]..sort(),
      qualifiedAndroidName: androidWidgetName(HomeWidgetKind.prayer),
    );
    await HomeWidget.scheduleWidgetUpdates(
      [...prayerTimes, ...midnights]..sort(),
      qualifiedAndroidName: androidWidgetName(HomeWidgetKind.home),
    );
    for (final kind in const [
      HomeWidgetKind.date,
      HomeWidgetKind.ayah,
      HomeWidgetKind.memorize,
      HomeWidgetKind.khatmah,
    ]) {
      await HomeWidget.scheduleWidgetUpdates(
        midnights,
        qualifiedAndroidName: androidWidgetName(kind),
      );
    }
  }

  @override
  Future<Uri?> launchedWith() async {
    try {
      await _group();
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } on Object {
      return null;
    }
  }

  // (No plugin — a build without it: no taps, not an error.)
  @override
  Stream<Uri?> get taps => HomeWidget.widgetClicked.handleError((Object _) {});
}

class UnsupportedHomeWidgetBridge implements HomeWidgetBridge {
  const UnsupportedHomeWidgetBridge();
  @override
  bool get supported => false;
  @override
  Future<void> publish(HomeWidgetPayload payload) async {}
  @override
  Future<void> scheduleRedraws(
    List<DateTime> prayerTimes,
    List<DateTime> midnights,
  ) async {}
  @override
  Future<Uri?> launchedWith() async => null;
  @override
  Stream<Uri?> get taps => const Stream.empty();
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) {
  final plugin = PluginHomeWidgetBridge();
  return plugin.supported ? plugin : const UnsupportedHomeWidgetBridge();
});
