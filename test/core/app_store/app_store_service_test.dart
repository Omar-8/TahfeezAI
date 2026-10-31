import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tahfeez_ai/core/app_store/app_store_service.dart';

/// On iOS the update check asks the App Store listing's version (Apple's
/// lookup) and compares it with the installed one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('versions compare number by number', () {
    expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
    expect(isNewerVersion('1.1', '1.0.9'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.0.9', '1.0.9'), isFalse);
    expect(isNewerVersion('1.0.9', '1.0.10'), isFalse);
    expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.9', '1.0.9+12'), isFalse);
  });

  group('iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      PackageInfo.setMockInitialValues(
        appName: 'TahfeezAI',
        packageName: 'ai.tahfeez.tahfeezAi',
        version: '1.0.9',
        buildNumber: '12',
        buildSignature: '',
      );
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<bool?> check(Future<String?> Function() store) =>
        PlatformAppStoreService(appStoreVersion: store).updateAvailable();

    test('a newer version in the App Store: an update', () async {
      expect(await check(() async => '1.0.10'), isTrue);
    });

    test('the same version: none', () async {
      expect(await check(() async => '1.0.9'), isFalse);
    });

    test('offline or not listed yet: unknown, quietly', () async {
      expect(await check(() async => throw Exception('offline')), isNull);
      expect(await check(() async => null), isNull);
    });

    test('the listing is the App Store\'s', () {
      expect(PlatformAppStoreService().listingUrl, kAppStoreUrl);
    });
  });
}
