Pod::Spec.new do |s|
  s.name             = 'tahfeez_ios'
  s.version          = '0.1.0'
  s.summary          = "Tahfeez AI's iOS platform channels."
  s.description      = 'The on-device acoustic model (ONNX Runtime), the mistake alert and keeping the screen on.'
  s.homepage         = 'http://example.com' # local pod, not published
  s.license          = { :type => 'AGPL-3.0' }
  s.author           = 'Tahfeez AI'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # ONNX Runtime with its Objective-C API (CPU, CoreML, XNNPACK).
  s.dependency 'onnxruntime-objc', '1.30.0' # the version Android ships
  s.platform         = :ios, '15.1' # onnxruntime-objc 1.30.0's minimum
  s.swift_version    = '5.0'
  # ONNX Runtime's pods are static libraries: so is this one (CocoaPods
  # refuses a dynamic framework over them).
  s.static_framework = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
