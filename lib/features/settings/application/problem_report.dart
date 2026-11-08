import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

import '../../../core/app_store/app_store_service.dart';
import '../../../core/logging/recent_log.dart';

/// Where problem reports go (the store listings' feedback address).
const kSupportEmail = 'tahfeez.ai.app@gmail.com';

/// A problem report's text: room for the user's words first, then the app
/// and device, then the app's latest messages ([RecentLog]) — nothing more
/// (no recitation audio, no memorization data).
String problemReportBody({
  required String prompt,
  required String version,
  required String locale,
  String? log,
}) {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  final recent = log ?? RecentLog.instance.latest();
  return [
    prompt,
    '',
    '',
    '— — —',
    'Tahfeez AI $version · $platform · $locale',
    if (recent.isNotEmpty) ...['', recent],
  ].join('\n');
}

/// Opens the user's mail app with a report addressed to [kSupportEmail];
/// with none (or in a browser that cannot), the share sheet with the same
/// text. The user sees and sends it — nothing is sent by the app.
Future<void> sendProblemReport(
  AppStoreService store, {
  required String subject,
  required String body,
}) async {
  final mail = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: _query({'subject': subject, 'body': body}),
  );
  if (await store.openUrl(mail.toString())) return;
  await store.share('$kSupportEmail\n$subject\n\n$body');
}

/// mailto's query: spaces as %20 (not +, which mail apps keep).
String _query(Map<String, String> params) => params.entries
    .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
    .join('&');
