# SDK consumer rules and @Keep annotations preserve Flutter JNI and SDK entry points.
# Flutter loads this generated entry point by name through reflection.
-keep class io.flutter.plugins.GeneratedPluginRegistrant {
    public static void registerWith(io.flutter.embedding.engine.FlutterEngine);
}

# Native method names must remain stable for JNI registration.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# flutter_local_notifications 18.x persists these models using Gson reflection.
# Keep model names and fields stable across upgrades of persisted notifications.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep,allowobfuscation class com.google.gson.reflect.TypeToken { *; }
-keep,allowobfuscation class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Optional Play Core APIs referenced by Flutter; this app has no deferred components.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Google Play Integrity API
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**

# Google Play Billing Library
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Keeps Android Credential Manager Play Services integration classes from being stripped or obfuscated
-keep class androidx.credentials.** { *; }
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }

# Drift & SQLite native bindings (prevent stripping during R8 minification)
-keep class org.sqlite.** { *; }
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }
-keep class androidx.sqlite.db.** { *; }
-dontwarn org.sqlite.**
-dontwarn com.simonbinder.sqlite3_flutter_libs.**
