# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class **$$serializer { *; }
-keep,includedescriptorclasses class com.healthstats.app.**$$serializer { *; }
-keepclassmembers class com.healthstats.app.** { *** Companion; }

# Health Connect
-keep class androidx.health.connect.client.** { *; }

# osmdroid
-dontwarn org.osmdroid.**
