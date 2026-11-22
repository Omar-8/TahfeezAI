import 'dart:async';

import 'package:tahfeez_ai/features/qibla/data/qibla_sensors.dart';

/// The phone's location and compass, for tests: a fixed result for
/// [locate], and a heading stream the test drives ([setHeading]).
class FakeQiblaSensors implements QiblaSensors {
  FakeQiblaSensors({
    this.result = const Located(51.5072, -0.1276), // London
    this.hasCompass = true,
  });

  LocateResult result;
  int locateCalls = 0;
  int settingsOpened = 0;

  @override
  final bool hasCompass;

  final _headings = StreamController<double?>.broadcast();

  void setHeading(double? heading) => _headings.add(heading);

  @override
  Stream<double?> heading({
    required double latitude,
    required double longitude,
  }) => _headings.stream;

  @override
  Future<LocateResult> locate() async {
    locateCalls++;
    return result;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}
