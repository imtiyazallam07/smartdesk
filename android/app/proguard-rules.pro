# 1. Flutter Base - Keep all Flutter internal classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.common.annotation.KeepName { *; }

# 2. Workmanager Plugin
# Standard official package name for flutter_workmanager
-keep class be.tramckas.workmanager.** { *; }
# Legacy/Alternative package name (keeping your original just in case)
-keep class com.be2ps.workmanager.** { *; }

# 3. Flutter Local Notifications Plugin
# This ensures the OS can find the classes referenced in your AndroidManifest
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }

# 4. GSON / JSON Protection (Critical for background data passing)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }

# 5. Method Channels & Background Isolates
# Prevents stripping of handles used to communicate between Dart and Java
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$ActivityResultListener { *; }

# 6. HTTP & Networking (If using http package)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# 7. Kotlin Coroutines (Used by many modern plugins)
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.coroutines.android.HandlerContext {
    private final android.os.Handler handler;
}

# 8. Ignore missing non-critical classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**