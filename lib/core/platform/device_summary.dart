import 'device_summary_web.dart'
    if (dart.library.io) 'device_summary_io.dart'
    as impl;

/// One line about the device for an error report: the system and its
/// version, and on native the processor architecture (a 32-bit phone runs
/// a different build of the app's native code).
String deviceSummary() => impl.deviceSummary();
