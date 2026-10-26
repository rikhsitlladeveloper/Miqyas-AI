# Compose and AndroidX ship their own rules; nothing app-specific is reflected on yet.

# Vosk (offline voice numbers) calls its native library through JNA, which finds classes and fields by name
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
