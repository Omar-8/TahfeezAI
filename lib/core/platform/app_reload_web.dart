import 'package:web/web.dart' as web;

/// The web app started over: the page loaded again, everything read anew
/// from the browser's storage. `true`.
bool reloadApp() {
  web.window.location.reload();
  return true;
}
