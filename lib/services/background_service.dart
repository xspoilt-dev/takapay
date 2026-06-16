import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_handler.dart';
import 'debug_logger.dart';

/// Background service entry point.
/// 
/// Runs in a separate Dart isolate, keeping the process alive 24/7.
/// Listens to notifications in the background, parses them, sends webhooks,
/// and saves transactions to sqlite database.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Load persisted logs and state for this isolate
  await DebugLogger.instance.loadFromPersisted();
  DebugLogger.instance.log('SYSTEM', 'Background service isolate initialized');

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Takapay Active',
      content: 'Forwarding payment notifications in background',
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

  // Start notification listener in this background isolate
  try {
    NotificationHandler.instance.startListening();
    DebugLogger.instance.log('SYSTEM', 'Notification listener stream started in background isolate');
  } catch (e) {
    DebugLogger.instance.log('SYSTEM', 'Failed to start listener stream in background: $e', isError: true);
  }

  // Periodic keepalive - update notification to show service is running
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'Takapay Active',
          content: 'Forwarding payment notifications in background',
        );
      }
    }
  });

  print("Background service started and notification listener active");
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
