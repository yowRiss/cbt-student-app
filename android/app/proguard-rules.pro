# ProGuard rules for CBT Mobile
-dontwarn io.flutter.**
-keep class io.flutter.** { *; }
-keep class id.sch.cbt.mobile.** { *; }

# Keep Flutter Plugins & AndroidX
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**
-keep class androidx.** { *; }
-dontwarn androidx.**
-dontwarn com.google.common.**
