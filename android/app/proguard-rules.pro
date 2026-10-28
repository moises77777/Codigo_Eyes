# Reglas de ProGuard/R8 para ML Kit y servicios de Google
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit.**

# speech_to_text / flutter_tts
-keep class android.speech.** { *; }
-keep class android.media.** { *; }

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Conectividad
-keep class com.heyzap.** { *; }
