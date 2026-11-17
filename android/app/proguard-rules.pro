# SDK consumer rules and @Keep annotations preserve Flutter JNI and SDK entry points.
# Repackage obfuscated classes into a single flat package to reduce DEX size.
-repackageclasses
# Flutter loads this generated entry point by name through reflection.
-keep class io.flutter.plugins.GeneratedPluginRegistrant {
    public static void registerWith(io.flutter.embedding.engine.FlutterEngine);
}

# Native method names must remain stable for JNI registration.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# flutter_local_notifications 18.x persists these models using Gson reflection.
# Allow unused classes/methods to be shrunk while preserving fields and constructors of used models.
-keep,allowshrinking class com.dexterous.flutterlocalnotifications.models.** {
    <fields>;
    <init>(...);
}
-keep,allowshrinking,allowobfuscation class com.google.gson.reflect.TypeToken { *; }
-keep,allowshrinking,allowobfuscation class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Scoped replacement for firebase-auth consumer rules (fixes upstream bug where
# `-keep class com.google.android.gms.internal.** { *; }` prevented shrinking AdMob/GMS):
-dontwarn com.google.appengine.api.**
-dontwarn okio.**
-dontwarn org.apache.**
-dontwarn retrofit.android.**
-dontwarn retrofit.appengine.**
-dontwarn retrofit.client.**
-dontwarn rx.**
-keepclasseswithmembernames interface * {
    @retrofit.http.* <methods>;
}
-keep,allowshrinking class com.google.android.gms.internal.firebase-auth-api.** {
    <fields>;
    <methods>;
}
-keepclassmembers class * extends com.google.android.gms.internal.firebase-auth-api.zzalf {
    <fields>;
}

# Scoped replacement for recaptcha consumer rules:
-dontwarn kotlinx.coroutines.internal.ClassValueCtorCache
-dontwarn java.lang.ClassValue
-dontwarn kotlinx.coroutines.flow.**
-dontwarn com.squareup.okhttp3.**
-dontwarn okhttp3.**
-keepclassmembers class * extends com.google.android.recaptcha.internal.zznd {
    <fields>;
}
-keep,allowshrinking,allowobfuscation class com.google.android.recaptcha.** { *; }

# Optional Play Core APIs referenced by Flutter; this app has no deferred components.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.integrity.**
-dontwarn org.sqlite.**
-dontwarn com.simonbinder.sqlite3_flutter_libs.**
