import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

/// Debug logger that persists logs to database and counters to shared preferences.
/// Survives app kills, restarts, and works across isolates.
class DebugLogger {
  static final DebugLogger instance = DebugLogger._();
  DebugLogger._();

  final List<DebugLogEntry> _logs = [];
  final int _maxLogs = 500;

  // Counters
  int totalNotificationsReceived = 0;
  int totalNotificationsParsed = 0;
  int totalWebhooksSent = 0;
  int totalWebhooksFailed = 0;
  int totalParseSkipped = 0;

  // State tracking
  String? lastError;
  DateTime? serviceStartTime;
  DateTime? lastNotificationTime;
  String? lastNotificationPackage;
  bool listenerStarted = false;
  bool listenerStreamActive = false;
  bool permissionGranted = false;
  bool backgroundServiceRunning = false;

  /// All registered listeners for real-time updates
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Load persisted logs and counters.
  Future<void> loadFromPersisted() async {
    try {
      // Load counters
      final prefs = await SharedPreferences.getInstance();
      totalNotificationsReceived = prefs.getInt('dbg_total_received') ?? 0;
      totalNotificationsParsed = prefs.getInt('dbg_total_parsed') ?? 0;
      totalWebhooksSent = prefs.getInt('dbg_total_webhooks_sent') ?? 0;
      totalWebhooksFailed = prefs.getInt('dbg_total_webhooks_failed') ?? 0;
      totalParseSkipped = prefs.getInt('dbg_total_parse_skipped') ?? 0;

      final lastErrorSaved = prefs.getString('dbg_last_error');
      if (lastErrorSaved != null && lastErrorSaved.isNotEmpty) {
        lastError = lastErrorSaved;
      }

      final lastTimeSaved = prefs.getString('dbg_last_notif_time');
      if (lastTimeSaved != null && lastTimeSaved.isNotEmpty) {
        lastNotificationTime = DateTime.tryParse(lastTimeSaved);
      }
      lastNotificationPackage = prefs.getString('dbg_last_notif_pkg');

      // Load logs from DB
      final dbLogs = await DatabaseHelper.instance.getDebugLogs(limit: _maxLogs);
      _logs.clear();
      for (final row in dbLogs) {
        _logs.add(DebugLogEntry(
          timestamp: DateTime.parse(row['timestamp']),
          category: row['category'],
          message: row['message'],
          isError: row['is_error'] == 1,
        ));
      }
      _notifyListeners();
    } catch (e) {
      lastError = 'Load error: $e';
      _notifyListeners();
      print('DebugLogger: Error loading persisted state: $e');
    }
  }

  String _stripEmojis(String input) {
    try {
      final emojiPattern = RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F018}-\u{1F0F5}]|[\u{1F004}]|[\u{1F170}-\u{1F0C0}]|[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{1F100}-\u{1F1FF}]|[\u{25AA}-\u{25AB}]|[\u{25B6}]|[\u{25C0}]|[\u{25FB}-\u{25FE}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|[\u{2B50}]|[\u{2B55}]|[\u{3030}]|[\u{303D}]|[\u{3297}]|[\u{3299}]|[\u{23E9}-\u{23EF}]|[\u{23F0}]|[\u{23F3}]',
        unicode: true,
      );
      return input.replaceAll(emojiPattern, '').trim();
    } catch (e) {
      return input;
    }
  }

  void log(String category, String message, {bool isError = false}) {
    final cleanMessage = _stripEmojis(message);
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: cleanMessage,
      isError: isError,
    );
    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    _notifyListeners();

    // Async persist to SQLite
    DatabaseHelper.instance.insertDebugLog(category, cleanMessage, isError: isError).catchError((e) {
      print('DebugLogger: Failed to save log to SQLite: $e');
      return 0;
    });

    if (isError) {
      lastError = cleanMessage;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('dbg_last_error', cleanMessage);
      });
    }
  }

  /// Increments a counter and persists it to SharedPreferences
  Future<void> incrementCounter(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name == 'received') {
        totalNotificationsReceived++;
        await prefs.setInt('dbg_total_received', totalNotificationsReceived);
      } else if (name == 'parsed') {
        totalNotificationsParsed++;
        await prefs.setInt('dbg_total_parsed', totalNotificationsParsed);
      } else if (name == 'webhook_sent') {
        totalWebhooksSent++;
        await prefs.setInt('dbg_total_webhooks_sent', totalWebhooksSent);
      } else if (name == 'webhook_failed') {
        totalWebhooksFailed++;
        await prefs.setInt('dbg_total_webhooks_failed', totalWebhooksFailed);
      } else if (name == 'skipped') {
        totalParseSkipped++;
        await prefs.setInt('dbg_total_parse_skipped', totalParseSkipped);
      }
      _notifyListeners();
    } catch (e) {
      print('DebugLogger: Error incrementing counter $name: $e');
    }
  }

  Future<void> updateLastNotificationInfo(String packageName) async {
    lastNotificationTime = DateTime.now();
    lastNotificationPackage = packageName;
    _notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dbg_last_notif_time', lastNotificationTime!.toIso8601String());
      await prefs.setString('dbg_last_notif_pkg', packageName);
    } catch (e) {
      print('DebugLogger: Error updating last notification info: $e');
    }
  }

  List<DebugLogEntry> get logs => UnmodifiableListView(_logs);

  Future<void> clearLogs() async {
    _logs.clear();
    _notifyListeners();
    try {
      await DatabaseHelper.instance.clearDebugLogs();
    } catch (e) {
      print('DebugLogger: Error clearing DB logs: $e');
    }
  }

  Future<void> resetCounters() async {
    totalNotificationsReceived = 0;
    totalNotificationsParsed = 0;
    totalWebhooksSent = 0;
    totalWebhooksFailed = 0;
    totalParseSkipped = 0;
    lastError = null;
    lastNotificationTime = null;
    lastNotificationPackage = null;
    _notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dbg_total_received');
      await prefs.remove('dbg_total_parsed');
      await prefs.remove('dbg_total_webhooks_sent');
      await prefs.remove('dbg_total_webhooks_failed');
      await prefs.remove('dbg_total_parse_skipped');
      await prefs.remove('dbg_last_error');
      await prefs.remove('dbg_last_notif_time');
      await prefs.remove('dbg_last_notif_pkg');
    } catch (e) {
      print('DebugLogger: Error resetting persisted counters: $e');
    }
  }
}

class DebugLogEntry {
  final DateTime timestamp;
  final String category;
  final String message;
  final bool isError;

  DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.isError = false,
  });
}
