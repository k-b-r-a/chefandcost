## Flutter wrapper & engine rules (critico para JNI y GeneratedPluginRegistrant)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.chefandcost.app.** { *; }

# Play Core (compatibilidad con dependencias divididas)
-dontwarn com.google.android.play.core.**

# Play Integrity API (usado en PlayIntegrityHandler.kt)
-keep class com.google.android.play.core.integrity.** { *; }

# Desugaring
-dontwarn java.lang.invoke.StringConcatFactory

# Prevencion de fallos con Gson y flutter_local_notifications en modo Release (R8)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
