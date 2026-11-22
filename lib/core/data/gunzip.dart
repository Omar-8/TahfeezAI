// A bundled gzipped asset's unzipping (the Qibla's cities, the athkar): Dart's own gzip on the phones, the browser's
// DecompressionStream on the web (no package for it).
export 'gunzip_io.dart' if (dart.library.js_interop) 'gunzip_web.dart';
