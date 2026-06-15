import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'database_helper.dart';
import 'webhook_service.dart';
import '../utils/sms_parser.dart';
import '../models/transaction_record.dart';

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

  // Listen for system notifications
  NotificationListenerService.notificationsStream.listen((event) async {
    if (event.hasRemoved == true) return;

    final String packageName = event.packageName ?? "";
    final String title = event.title ?? "";
    final String body = event.content ?? "";

    print("Background Notification received: package=$packageName, title=$title, body=$body");

    // Treat title as the sender and content as the body of the message
    await _handleSms(title, body);
  });

  print("Background service started and listening for system notifications");
}

Future<void> _handleSms(String sender, String body) async {
  print("SMS Received: from $sender, body: $body");

  final record = SMSParser.parse(sender, body);
  if (record != null) {
    final String? errorReason = await WebhookService.sendPayload(record);
    final bool success = errorReason == null;
    
    final finalRecord = TransactionRecord(
      sender: record.sender,
      amount: record.amount,
      trxId: record.trxId,
      rawBody: record.rawBody,
      timestamp: record.timestamp,
      status: success ? 'SUCCESS' : 'FAILED',
      errorMessage: errorReason,
    );

    await DatabaseHelper.instance.insertTransaction(finalRecord);
  }
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
