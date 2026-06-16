import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'database_helper.dart';
import 'webhook_service.dart';
import '../utils/sms_parser.dart';
import '../models/transaction_record.dart';

/// Handles notification listening from the MAIN Flutter engine isolate.
/// 
/// The notification_listener_service plugin uses EventChannel which only works
/// in the main Flutter engine — NOT in flutter_background_service's isolate.
/// This class ensures we listen from the correct context.
class NotificationHandler {
  static NotificationHandler? _instance;
  static StreamSubscription? _subscription;
  static bool _isListening = false;

  NotificationHandler._();

  static NotificationHandler get instance {
    _instance ??= NotificationHandler._();
    return _instance!;
  }

  /// Start listening to notification events.
  /// Must be called from the main Flutter engine (e.g., in main() or a widget).
  void startListening() {
    if (_isListening) {
      debugPrint('NotificationHandler: Already listening, skipping duplicate start');
      return;
    }

    _isListening = true;
    debugPrint('NotificationHandler: Starting notification listener from main isolate');

    try {
      _subscription = NotificationListenerService.notificationsStream.listen(
        (event) async {
          if (event.hasRemoved == true) return;

          final String packageName = event.packageName ?? "";
          final String title = event.title ?? "";
          final String body = event.content ?? "";

          debugPrint("NotificationHandler: Received notification - package=$packageName, title=$title, body=$body");

          await _handleNotification(title, body);
        },
        onError: (error) {
          debugPrint('NotificationHandler: Stream error: $error');
          _isListening = false;
        },
        onDone: () {
          debugPrint('NotificationHandler: Stream done');
          _isListening = false;
        },
      );
    } catch (e) {
      debugPrint('NotificationHandler: Failed to start listening: $e');
      _isListening = false;
    }
  }

  /// Stop listening to notification events.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    debugPrint('NotificationHandler: Stopped listening');
  }

  bool get isListening => _isListening;

  static Future<void> _handleNotification(String sender, String body) async {
    debugPrint("NotificationHandler: Processing - sender=$sender, body=$body");

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
      debugPrint("NotificationHandler: Transaction saved - trxId=${record.trxId}, success=$success");
    }
  }
}
