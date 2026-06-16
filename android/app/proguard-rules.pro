# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# ===== notification_listener_service plugin =====
# Keep ALL classes in the plugin package (services, receivers, models, constants)
-keep class notification.listener.service.** { *; }
-keepclassmembers class notification.listener.service.** { *; }

# The NotificationListenerService subclass MUST not be obfuscated
# Android system binds to it by class name from AndroidManifest
-keep public class notification.listener.service.NotificationListener {
    public *;
    protected *;
}

# Keep the BroadcastReceiver that relays notification data
-keep public class notification.listener.service.NotificationReceiver {
    public *;
}

# Keep NotificationConstants - R8 can inline/remove static fields
# breaking the broadcast intent action matching
-keepclassmembers class notification.listener.service.NotificationConstants {
    public static *;
}

# ===== flutter_background_service =====
-keep class id.flutter.flutter_background_service.** { *; }
-keepclassmembers class id.flutter.flutter_background_service.** { *; }

# ===== flutter_local_notifications =====
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# ===== shared_preferences =====
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ===== http / dart:io networking =====
-keep class io.flutter.plugins.urllauncher.** { *; }

# ===== Keep your app's native code =====
-keep class com.xspoilt.takapay.** { *; }

# ===== AndroidX and support libraries =====
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
-keep class androidx.localbroadcastmanager.** { *; }

# Keep NotificationListenerService (Android framework class)
-keep class android.service.notification.NotificationListenerService { *; }
-keep class android.service.notification.StatusBarNotification { *; }

# ===== EventChannel / MethodChannel - critical for plugin communication =====
-keep class io.flutter.plugin.common.EventChannel** { *; }
-keep class io.flutter.plugin.common.MethodChannel** { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }

# ===== Gson (used by some plugins internally) =====
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ===== General safety rules =====
# Don't remove Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Suppress R8 missing class warnings (very common in Flutter packages)
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit

# Keep annotations
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
