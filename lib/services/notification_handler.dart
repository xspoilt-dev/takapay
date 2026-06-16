import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'database_helper.dart';
import 'webhook_service.dart';
import 'debug_logger.dart';
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
  static final _debug = DebugLogger.instance;

  NotificationHandler._();

  static NotificationHandler get instance {
    _instance ??= NotificationHandler._();
    return _instance!;
  }

  /// Start listening to notification events.
  /// Can be called from any isolate (e.g. background service).
  void startListening() {
    if (_isListening) {
      _debug.log('LISTENER', 'Already listening, skipping duplicate start');
      return;
    }

    _isListening = true;
    _debug.listenerStarted = true;
    _debug.serviceStartTime = DateTime.now();
    _debug.log('LISTENER', 'Starting notification listener stream');

    try {
      _subscription = NotificationListenerService.notificationsStream.listen(
        (event) async {
          _debug.listenerStreamActive = true;
          await _debug.incrementCounter('received');
          await _debug.updateLastNotificationInfo(event.packageName ?? 'unknown');

          if (event.hasRemoved == true) {
            _debug.log('NOTIFICATION', 'Notification removed (ignored) - pkg=${event.packageName}');
            return;
          }

          final String packageName = event.packageName ?? "";
          final String title = event.title ?? "";
          final String body = event.content ?? "";

          _debug.log('NOTIFICATION', 'Received notification: pkg=$packageName, title=$title, body=${body.length > 100 ? '${body.substring(0, 100)}...' : body}');

          await _handleNotification(title, body);
        },
        onError: (error) {
          _debug.log('LISTENER', 'Stream ERROR: $error', isError: true);
          _debug.lastError = 'Stream error: $error';
          _debug.listenerStreamActive = false;
          _isListening = false;
        },
        onDone: () {
          _debug.log('LISTENER', 'Stream DONE (closed unexpectedly)', isError: true);
          _debug.lastError = 'Stream closed';
          _debug.listenerStreamActive = false;
          _isListening = false;
        },
        cancelOnError: false,
      );
      _debug.log('LISTENER', 'Stream subscription created successfully');
      _debug.listenerStreamActive = true;
    } catch (e) {
      _debug.log('LISTENER', 'FAILED to create stream: $e', isError: true);
      _debug.lastError = 'Failed to start: $e';
      _debug.listenerStreamActive = false;
      _isListening = false;
    }
  }

  /// Stop listening to notification events.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _debug.listenerStarted = false;
    _debug.listenerStreamActive = false;
    _debug.log('LISTENER', 'Stopped listening');
  }

  bool get isListening => _isListening;

  static Future<void> _handleNotification(String sender, String body) async {
    _debug.log('PARSER', 'Parsing message - sender=$sender');

    try {
      final record = SMSParser.parse(sender, body);
      if (record != null) {
        await _debug.incrementCounter('parsed');
        _debug.log('PARSER', 'Parsed transaction: ${record.sender} - ${record.amount} TK - TrxID: ${record.trxId}');

        try {
          final String? errorReason = await WebhookService.sendPayload(record);
          final bool success = errorReason == null;

          if (success) {
            await _debug.incrementCounter('webhook_sent');
            _debug.log('WEBHOOK', 'Webhook sent successfully for TrxID: ${record.trxId}');
          } else {
            await _debug.incrementCounter('webhook_failed');
            _debug.lastError = 'Webhook: $errorReason';
            _debug.log('WEBHOOK', 'Webhook failed: $errorReason', isError: true);
          }

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
          _debug.log('DATABASE', 'Transaction saved to DB');
        } catch (e) {
          await _debug.incrementCounter('webhook_failed');
          _debug.lastError = 'Webhook exception: $e';
          _debug.log('WEBHOOK', 'Exception sending webhook: $e', isError: true);
        }
      } else {
        await _debug.incrementCounter('skipped');
        _debug.log('PARSER', 'Not a payment notification (no match) - sender=$sender');
      }
    } catch (e) {
      _debug.log('PARSER', 'Parse exception: $e', isError: true);
      _debug.lastError = 'Parse error: $e';
    }
  }
}
