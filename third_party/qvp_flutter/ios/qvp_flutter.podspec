# Tahfeez patch 0004: the engine on iOS. `libqvp_ffi` as a dynamic
# framework (ios/Frameworks/qvp_ffi.xcframework, built on a Mac with
# scripts/build-engine-ios.sh), linked into the app so that
# `DynamicLibrary.process()` (QvpEngine.resolveLibrary) finds its symbols.
Pod::Spec.new do |s|
  s.name             = 'qvp_flutter'
  s.version          = '0.2.2'
  s.summary          = 'The QVP vector mushaf engine (dart:ffi).'
  s.homepage         = 'https://quran.ws/blocks/quran-engine'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'quran-ws'
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.vendored_frameworks = 'Frameworks/qvp_ffi.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
