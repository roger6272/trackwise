# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Crashlytics — preserve stack trace info
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# flutter_blue_plus (BLE) — verified package: com.lib.flutter_blue_plus
-keep class com.lib.flutter_blue_plus.** { *; }

# BouncyCastle (used by mailer/crypto)
-dontwarn org.bouncycastle.**
-keep class org.bouncycastle.** { *; }

# Play Core (referenced by Flutter engine for deferred components, not used at runtime)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Suppress common warnings
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.xmlpull.v1.**
-keep class org.xmlpull.v1.** { *; }
