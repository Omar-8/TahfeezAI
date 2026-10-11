import CommonCrypto
import Flutter
import Foundation
import UIKit
import onnxruntime_objc

/// The on-device Quran acoustic model (`LocalQuranAcousticModel` in Dart):
/// ONNX Runtime, loaded once and reused for every window — the iOS twin of
/// Android's `QuranAcousticModelChannel.kt`, method for method.
///
/// The model is never bundled. A development build finds it sideloaded at
/// `Documents/models/quran_acoustic.onnx` or
/// `Library/Application Support/models/quran_acoustic.onnx`, with its
/// manifest `quran_acoustic.json` beside it — copied in with
/// `xcrun devicectl device copy to --domain-type appDataContainer ...`.
/// The file's SHA-256 must match the manifest; a verified hash is
/// remembered by size and modification time, so it is hashed once.
final class QuranAcousticModelChannel {
  private static var instance: QuranAcousticModelChannel?

  private static let model = "quran_acoustic.onnx"
  private static let manifestName = "quran_acoustic.json"

  /// Serves the channel on [messenger]; one instance per process (the
  /// loaded session outlives an engine's re-creation).
  static func attach(_ messenger: FlutterBinaryMessenger) {
    let handler = instance ?? QuranAcousticModelChannel()
    instance = handler
    FlutterMethodChannel(
      name: "tahfeez/quran_acoustic_model",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in handler.handle(call, result) }
  }

  private let worker = DispatchQueue(label: "tahfeez.acoustic", qos: .userInitiated)
  private var env: ORTEnv?
  private var session: ORTSession?
  private var loadedProvider: String?

  /// A streaming model's state (manifest "stream"): one buffer per state
  /// input, the ONNX value reading it, and its starting values.
  private final class StreamSlot {
    let name: String
    let buffer: NSMutableData
    let value: ORTValue
    let initial: [Float]?

    init(name: String, buffer: NSMutableData, value: ORTValue, initial: [Float]?) {
      self.name = name
      self.buffer = buffer
      self.value = value
      self.initial = initial
    }
  }
  private var stream: [StreamSlot]?

  private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    worker.async {
      do {
        let value: Any?
        switch call.method {
        case "status": value = self.status()
        case "load":
          value = try self.load(
            provider: args["provider"] as? String ?? "cpu",
            threads: args["threads"] as? Int ?? 0)
        case "run": value = try self.run(Self.floats(args["samples"]))
        case "streamReset":
          try self.streamReset()
          value = nil
        case "streamRun":
          value = try self.streamRun(
            Self.floats(args["samples"]), commit: args["commit"] as? Bool ?? true)
        case "unload":
          self.close()
          value = nil
        case "stats": value = self.stats()
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "acoustic_model", message: "\(error)", details: nil))
        }
      }
    }
  }

  private static func floats(_ arg: Any?) throws -> Data {
    guard let typed = arg as? FlutterStandardTypedData else {
      throw Failure("samples must be a Float32List")
    }
    return typed.data
  }

  private func directories() -> [URL] {
    let fm = FileManager.default
    return [
      fm.urls(for: .documentDirectory, in: .userDomainMask).first,
      fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
    ].compactMap { $0?.appendingPathComponent("models", isDirectory: true) }
  }

  private func candidates() -> [URL] {
    directories().map { $0.appendingPathComponent(Self.model) }
  }

  private func manifestOf(_ model: URL) -> URL {
    model.deletingLastPathComponent().appendingPathComponent(Self.manifestName)
  }

  private func isFile(_ url: URL) -> Bool {
    var directory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
      && !directory.boolValue
  }

  private func size(_ url: URL) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
  }

  private func status() -> [String: Any?] {
    let searched = candidates()
    guard let model = searched.first(where: isFile) else {
      return ["state": "absent", "searched": searched.map { $0.path }]
    }
    let manifest = manifestOf(model)
    guard isFile(manifest), let text = try? String(contentsOf: manifest, encoding: .utf8)
    else {
      return [
        "state": "invalid",
        "path": model.path,
        "detail": "No manifest (\(Self.manifestName)) beside the model",
      ]
    }
    return [
      "state": session != nil ? "loaded" : "present",
      "path": model.path,
      "bytes": size(model),
      "manifest": text,
      "provider": loadedProvider,
    ]
  }

  private func millis(since start: DispatchTime) -> Int {
    Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
  }

  private func load(provider: String, threads: Int) throws -> [String: Any?] {
    if session != nil && provider == loadedProvider {
      return ["provider": loadedProvider, "loadMs": 0, "cached": true]
    }
    close()
    guard let model = candidates().first(where: isFile) else {
      throw Failure("No acoustic model on this device")
    }
    let started = DispatchTime.now()
    guard
      let manifest = try JSONSerialization.jsonObject(
        with: Data(contentsOf: manifestOf(model))) as? [String: Any],
      let expected = (manifest["sha256"] as? String)?.lowercased(),
      let bytes = manifest["bytes"] as? Int
    else { throw Failure("Unreadable manifest") }
    if size(model) != bytes {
      throw Failure("Model is \(size(model)) bytes, manifest says \(bytes)")
    }
    let hashStarted = DispatchTime.now()
    let actual = try verifiedHash(model)
    let hashMs = millis(since: hashStarted)
    if actual != expected {
      throw Failure("Model SHA-256 \(actual) does not match the manifest")
    }
    let environment = try env ?? ORTEnv(loggingLevel: .warning)
    let options = try ORTSessionOptions()
    try options.setGraphOptimizationLevel(.all)
    if threads > 0 { try options.setIntraOpNumThreads(Int32(threads)) }
    switch provider {
    case "cpu": break
    // Android's NNAPI: on iOS, Core ML.
    case "nnapi", "coreml":
      try options.appendCoreMLExecutionProvider(with: ORTCoreMLExecutionProviderOptions())
    case "xnnpack":
      let xnn = ORTXnnpackExecutionProviderOptions()
      xnn.intra_op_num_threads = Int32(threads > 0 ? threads : 4)
      try options.appendXnnpackExecutionProvider(with: xnn)
    default: throw Failure("Unknown provider \(provider)")
    }
    let sessionStarted = DispatchTime.now()
    let loaded = try ORTSession(env: environment, modelPath: model.path, sessionOptions: options)
    session = loaded
    env = environment
    loadedProvider = provider
    if let config = manifest["stream"] as? [String: Any] {
      stream = try streamSlots(config)
      try streamReset()
    }
    return [
      "provider": provider,
      "loadMs": millis(since: started),
      "hashMs": hashMs,
      "sessionMs": millis(since: sessionStarted),
      "inputs": try loaded.inputNames(),
      "outputs": try loaded.outputNames(),
    ]
  }

  /// SHA-256 of [model], computed once per size + modification time.
  private func verifiedHash(_ model: URL) throws -> String {
    let attributes = try FileManager.default.attributesOfItem(atPath: model.path)
    let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    let key = "\(model.path):\(size(model)):\(modified)"
    let cache = directories()[1].appendingPathComponent("verified.txt")
    if let lines = try? String(contentsOf: cache, encoding: .utf8)
      .split(separator: "\n", omittingEmptySubsequences: false),
      lines.count == 2, lines[0] == key
    {
      return String(lines[1])
    }
    guard let input = InputStream(url: model) else { throw Failure("Can't read the model") }
    input.open()
    defer { input.close() }
    var context = CC_SHA256_CTX()
    CC_SHA256_Init(&context)
    let chunk = 1 << 20
    var buffer = [UInt8](repeating: 0, count: chunk)
    while true {
      let n = input.read(&buffer, maxLength: chunk)
      if n < 0 { throw Failure("Can't read the model") }
      if n == 0 { break }
      CC_SHA256_Update(&context, buffer, CC_LONG(n))
    }
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256_Final(&digest, &context)
    let hash = digest.map { String(format: "%02x", $0) }.joined()
    try FileManager.default.createDirectory(
      at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "\(key)\n\(hash)".write(to: cache, atomically: true, encoding: .utf8)
    return hash
  }

  private func cpuMillis() -> Int {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let user = Int(usage.ru_utime.tv_sec) * 1000 + Int(usage.ru_utime.tv_usec) / 1000
    let system = Int(usage.ru_stime.tv_sec) * 1000 + Int(usage.ru_stime.tv_usec) / 1000
    return user + system
  }

  private func tensor(_ samples: Data) throws -> ORTValue {
    try ORTValue(
      tensorData: NSMutableData(data: samples),
      elementType: .float,
      shape: [1, NSNumber(value: samples.count / 4)])
  }

  /// [value]'s frames, classes and log-probabilities, as Dart reads them.
  private func output(_ value: ORTValue, started: DispatchTime, cpu: Int) throws -> [String: Any] {
    let shape = try value.tensorTypeAndShapeInfo().shape  // [1, frames, classes]
    let data = try value.tensorData() as Data
    return [
      "frames": shape[1].intValue,
      "classes": shape[2].intValue,
      "logProbs": FlutterStandardTypedData(float32: data),
      "ms": millis(since: started),
      "cpuMs": cpuMillis() - cpu,
    ]
  }

  private func run(_ samples: Data) throws -> [String: Any] {
    guard let s = session else { throw Failure("Acoustic model not loaded") }
    let started = DispatchTime.now()
    let cpu = cpuMillis()
    let inputName = try s.inputNames()[0]
    let outputName = try s.outputNames()[0]
    let out = try s.run(
      withInputs: [inputName: tensor(samples)], outputNames: [outputName], runOptions: nil)
    guard let value = out[outputName] else { throw Failure("No output") }
    return try output(value, started: started, cpu: cpu)
  }

  /// The graph's state order (stream_model.STATE); unknown names last.
  private func order(_ name: String) -> Int {
    ["sums", "count", "kv", "conv", "akv", "aconv", "valid"].firstIndex(of: name) ?? 99
  }

  private func flat(_ x: Any) -> [Float] {
    if let a = x as? [Any] { return a.flatMap(flat) }
    return [(x as? NSNumber)?.floatValue ?? 0]
  }

  /// The state buffers a streaming manifest describes (shapes, starting values).
  private func streamSlots(_ config: [String: Any]) throws -> [StreamSlot] {
    guard let shapes = config["state"] as? [String: [Int]] else {
      throw Failure("Streaming manifest without state shapes")
    }
    let initial = config["initial"] as? [String: Any] ?? [:]
    return try shapes.keys.sorted { order($0) < order($1) }.map { name in
      let dims = shapes[name]!
      let count = dims.reduce(1, *)
      let buffer = NSMutableData(length: count * 4)!
      let value = try ORTValue(
        tensorData: buffer, elementType: .float, shape: dims.map { NSNumber(value: $0) })
      return StreamSlot(
        name: name, buffer: buffer, value: value, initial: initial[name].map(flat))
    }
  }

  /// A new recitation: the state back to its starting values.
  private func streamReset() throws {
    guard let slots = stream else { throw Failure("Not a streaming model") }
    for slot in slots {
      let pointer = slot.buffer.mutableBytes.assumingMemoryBound(to: Float.self)
      let count = slot.buffer.length / 4
      if let start = slot.initial {
        for i in 0..<count { pointer[i] = i < start.count ? start[i] : 0 }
      } else {
        memset(slot.buffer.mutableBytes, 0, slot.buffer.length)
      }
    }
  }

  /// One chunk of a streaming model: [samples] (the chunk and the 240
  /// samples after it) with the state; with [commit], the state is
  /// replaced by the graph's new one (without: a provisional look at a
  /// partial chunk, the state left as it was).
  private func streamRun(_ samples: Data, commit: Bool) throws -> [String: Any] {
    guard let s = session else { throw Failure("Acoustic model not loaded") }
    guard let slots = stream else { throw Failure("Not a streaming model") }
    let started = DispatchTime.now()
    let cpu = cpuMillis()
    var inputs: [String: ORTValue] = ["samples": try tensor(samples)]
    for slot in slots { inputs[slot.name] = slot.value }
    var names: Set<String> = ["log_probs"]
    if commit { for slot in slots { names.insert("\(slot.name)_out") } }
    let out = try s.run(withInputs: inputs, outputNames: names, runOptions: nil)
    guard let logProbs = out["log_probs"] else { throw Failure("No log_probs") }
    let result = try output(logProbs, started: started, cpu: cpu)
    if commit {
      for slot in slots {
        guard let next = out["\(slot.name)_out"] else {
          throw Failure("No \(slot.name)_out")
        }
        let data = try next.tensorData()
        slot.buffer.replaceBytes(
          in: NSRange(location: 0, length: min(slot.buffer.length, data.length)),
          withBytes: data.bytes)
      }
    }
    return result
  }

  /// Memory, CPU time, battery and temperature, for measurements.
  private func stats() -> [String: Any?] {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    let footprint = kr == KERN_SUCCESS ? Int(info.phys_footprint) : nil
    var battery: Double?
    DispatchQueue.main.sync {
      UIDevice.current.isBatteryMonitoringEnabled = true
      let level = UIDevice.current.batteryLevel
      battery = level >= 0 ? Double(level) * 100 : nil
    }
    return [
      // The memory the system charges the app (Android: PSS).
      "pssKb": footprint.map { $0 / 1024 },
      "nativeHeapBytes": nil,
      "cpuMs": cpuMillis(),
      "batteryPercent": battery,
      "batteryMicroAmps": nil,
      "batteryTenthsC": nil,
      "cores": ProcessInfo.processInfo.activeProcessorCount,
    ]
  }

  private func close() {
    stream = nil
    session = nil
    loadedProvider = nil
  }
}
