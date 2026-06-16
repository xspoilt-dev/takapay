import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background service entry point.
/// 
/// IMPORTANT: This runs in a SEPARATE Dart isolate. EventChannel-based plugins
/// (like notification_listener_service) do NOT work here because their native
/// side is only registered with the main Flutter engine.
/// 
/// This service only handles:
/// - Keeping the app alive with a foreground notification
/// - Responding to start/stop commands
/// 
/// Actual notification listening is handled by NotificationHandler in the 
/// main isolate (see notification_handler.dart).
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Takapay Active',
      content: 'Listening for payment notifications in background',
    );

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Periodic keepalive - update notification to show service is running
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'Takapay Active',
          content: 'Listening for payment notifications in background',
        );
      }
    }
  });

  print("Background service started (foreground notification only)");
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Initialize notifications channel for android
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'takapay_service', // id
    'Takapay SMS Forwarder Service', // title
    description: 'This channel is used for the foreground SMS forwarding service.',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'takapay_service',
      initialNotificationTitle: 'Takapay Service Active',
      initialNotificationContent: 'Listening for payment notifications in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
