# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep the pure-Kotlin XGBoost-style inference engine and its model data
# classes - they're reflectively (de)serialized from the bundled JSON model
# and from Tauri's Jackson-based Invoke argument parsing.
-keep class com.holywarrior.silence_of_salah_engine.** { *; }

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
