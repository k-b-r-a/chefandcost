# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Drift & SQLite3 Native Bindings
-keepclasseswithmembers class * {
    native <methods>;
}
-keep class org.sqlite.** { *; }
-keep class com.simolus3.sqlite3_flutter_libs.** { *; }
-keep class sqlite3.** { *; }
-dontwarn org.sqlite.**

# Firebase Core, Auth, Firestore
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.api.signin.** { *; }

# Desugaring & Java Time
-dontwarn java.time.**

# Play Core Split Install (Flutter Deferred Components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
