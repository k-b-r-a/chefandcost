## Stacktrace symbolication for Google Play Console (preserves line numbers, hides filenames)
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,EnclosingMethod,InnerClasses,Exceptions

## Flutter engine, plugins & app native entrypoints
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.chefandcost.app.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

## Play Core & Play Integrity API
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.integrity.** { *; }

## Core library desugaring & OkHttp optional platform hooks
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn sun.misc.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

## Gson & flutter_local_notifications reflection models
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## WorkManager, Room (used by WorkManager/AdMob on startup) & VersionedParcelable
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.WorkerParameters
-keep public class androidx.versionedparcelable.ParcelImpl { *; }
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
