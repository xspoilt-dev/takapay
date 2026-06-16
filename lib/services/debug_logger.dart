import 'dart:collection';

/// In-memory debug logger that survives navigation but not app restarts.
/// Shows real-time diagnostic info about notification detection pipeline.
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

  void log(String category, String message, {bool isError = false}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
      isError: isError,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    _notifyListeners();
  }

  List<DebugLogEntry> get logs => UnmodifiableListView(_logs);

  void clearLogs() {
    _logs.clear();
    _notifyListeners();
  }

  void resetCounters() {
    totalNotificationsReceived = 0;
    totalNotificationsParsed = 0;
    totalWebhooksSent = 0;
    totalWebhooksFailed = 0;
    totalParseSkipped = 0;
    lastError = null;
    lastNotificationTime = null;
    lastNotificationPackage = null;
    _notifyListeners();
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
