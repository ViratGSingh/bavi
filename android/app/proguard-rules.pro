############################################
# Flutter & Dart Essentials
############################################
# Keep all Flutter/Dart bindings
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.util.** { *; }

# Keep Dart entry points
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}

# Don't warn about generated classes
-dontwarn io.flutter.embedding.**

############################################
# TensorFlow Lite & GPU Delegates
############################################
# Keep TensorFlow Lite and suppress warnings
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Specifically keep GPU delegate related classes
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

############################################
# Android Support Library & Jetpack
############################################
-dontwarn android.support.**
-dontwarn androidx.**
-keep class androidx.lifecycle.** { *; }

############################################
# Gson (if used in your model loading)
############################################
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

############################################
# Optional: Prevent stripping of native libraries
############################################
-keepclassmembers class * {
    native <methods>;
}

############################################
# Google Play Core & SplitCompat Support
############################################
-keep class com.google.android.play.core.splitcompat.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter compatibility for SplitCompat
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }