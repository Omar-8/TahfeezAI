# Release builds shrink and rename the app's Java code (R8). ONNX Runtime's
# native library finds its Java classes by name (JNI FindClass / GetMethodID):
# renamed, it gets null and aborts the app — on the first recitation check
# (2026-10-29: "java_class == null in call to GetMethodID … OrtSession.run").
-keep class ai.onnxruntime.** { *; }
