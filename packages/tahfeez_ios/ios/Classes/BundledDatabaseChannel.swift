import CommonCrypto
import Compression
import Flutter
import Foundation

/// Unpacks a ready-made Quran database — a zlib- (the main ones) or
/// xz-compressed (the meaning packs) Flutter asset (assets/quran/db/) —
/// into a file, for BundledDatabaseInstaller in Dart: the iOS twin of
/// Android's `BundledDatabaseChannel.kt`. Streamed (Apple's Compression
/// framework: `COMPRESSION_ZLIB`, `COMPRESSION_LZMA`), on background
/// threads (several at once), hashing what it writes. Returns the SHA-256, in hex.
enum BundledDatabaseChannel {
  private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  // Concurrent: the databases are unpacked all at once, each on its own
  // thread.
  private static let worker = DispatchQueue(
    label: "tahfeez.bundled_db", qos: .userInitiated, attributes: .concurrent)

  static func attach(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "tahfeez/bundled_db", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "unpack",
          let args = call.arguments as? [String: Any],
          let asset = args["asset"] as? String,
          let dest = args["dest"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        worker.async {
          do {
            let key = FlutterDartProject.lookupKey(forAsset: asset)
            guard let source = Bundle.main.path(forResource: key, ofType: nil) else {
              throw Failure("\(asset): not in the app")
            }
            let hash = try unpack(source, to: dest)
            DispatchQueue.main.async { result(hash) }
          } catch {
            // A full phone shows here as the write's error.
            DispatchQueue.main.async {
              result(FlutterError(code: "unpack", message: "\(error)", details: nil))
            }
          }
        }
      }
  }

  private static func unpack(_ source: String, to dest: String) throws -> String {
    guard let input = InputStream(fileAtPath: source) else {
      throw Failure("cannot read \(source)")
    }
    input.open()
    defer { input.close() }
    guard FileManager.default.createFile(atPath: dest, contents: nil),
      let output = FileHandle(forWritingAtPath: dest)
    else {
      throw Failure("cannot write \(dest)")
    }
    defer { try? output.close() }

    let size = 1 << 16
    let src = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
    let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
    let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
    defer {
      src.deallocate()
      dst.deallocate()
      stream.deallocate()
    }
    // The main databases are zlib (quick); the meaning packs xz (smaller).
    // Apple's ZLIB is raw deflate: the zlib header's 2 bytes are skipped
    // (its checksum at the end is never reached; the SHA-256 checks it all).
    let zlib = source.hasSuffix(".zlib")
    if zlib {
      var header = [UInt8](repeating: 0, count: 2)
      guard input.read(&header, maxLength: 2) == 2 else { throw Failure("\(source): empty") }
    }
    guard compression_stream_init(
      stream, COMPRESSION_STREAM_DECODE, zlib ? COMPRESSION_ZLIB : COMPRESSION_LZMA)
      == COMPRESSION_STATUS_OK
    else {
      throw Failure("cannot start unpacking")
    }
    defer { compression_stream_destroy(stream) }

    var context = CC_SHA256_CTX()
    CC_SHA256_Init(&context)
    stream.pointee.src_ptr = UnsafePointer(src)
    stream.pointee.src_size = 0
    stream.pointee.dst_ptr = dst
    stream.pointee.dst_size = size
    var eof = false
    while true {
      if stream.pointee.src_size == 0 && !eof {
        let n = input.read(src, maxLength: size)
        if n < 0 { throw Failure("reading \(source): \(String(describing: input.streamError))") }
        eof = n == 0
        stream.pointee.src_ptr = UnsafePointer(src)
        stream.pointee.src_size = n
      }
      let flags = eof ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
      let status = compression_stream_process(stream, flags)
      let produced = size - stream.pointee.dst_size
      if produced > 0 {
        CC_SHA256_Update(&context, dst, CC_LONG(produced))
        try output.write(contentsOf: Data(bytesNoCopy: dst, count: produced, deallocator: .none))
        stream.pointee.dst_ptr = dst
        stream.pointee.dst_size = size
      }
      if status == COMPRESSION_STATUS_END { break }
      if status != COMPRESSION_STATUS_OK { throw Failure("\(source): not valid xz") }
    }
    try output.synchronize()

    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256_Final(&digest, &context)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
