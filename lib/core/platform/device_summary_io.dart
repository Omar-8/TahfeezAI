import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

String deviceSummary() =>
    '${Platform.operatingSystem} ${Platform.operatingSystemVersion} · '
    '${Abi.current()}';
