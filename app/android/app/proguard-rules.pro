# ONNX Runtime resolves these through JNI, so R8 must not rename or strip them.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Sign in with Apple and Google Sign-In use reflection over their model types.
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.**
