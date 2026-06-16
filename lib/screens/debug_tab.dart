import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import '../services/debug_logger.dart';
import '../services/notification_handler.dart';

class DebugTab extends StatefulWidget {
  const DebugTab({super.key});

  @override
  State<DebugTab> createState() => _DebugTabState();
}

class _DebugTabState extends State<DebugTab> {
  final _debug = DebugLogger.instance;
  bool _permissionGranted = false;
  bool _bgServiceRunning = false;
  bool _checkingStatus = false;
  String _filterCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _debug.addListener(_onDebugUpdate);
    _checkAllStatus();
  }

  @override
  void dispose() {
    _debug.removeListener(_onDebugUpdate);
    super.dispose();
  }

  void _onDebugUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAllStatus() async {
    setState(() => _checkingStatus = true);
    _debug.log('STATUS', '🔄 Checking all service statuses...');

    try {
      _permissionGranted = await NotificationListenerService.isPermissionGranted();
      _debug.permissionGranted = _permissionGranted;
      _debug.log('STATUS', 'Notification listener permission: ${_permissionGranted ? "✅ GRANTED" : "❌ DENIED"}');
    } catch (e) {
      _debug.log('STATUS', '❌ Error checking permission: $e', isError: true);
      _permissionGranted = false;
    }

    try {
      final service = FlutterBackgroundService();
      _bgServiceRunning = await service.isRunning();
      _debug.backgroundServiceRunning = _bgServiceRunning;
      _debug.log('STATUS', 'Background service: ${_bgServiceRunning ? "✅ RUNNING" : "❌ STOPPED"}');
    } catch (e) {
      _debug.log('STATUS', '❌ Error checking bg service: $e', isError: true);
      _bgServiceRunning = false;
    }

    _debug.log('STATUS', 'Notification handler listening: ${NotificationHandler.instance.isListening ? "✅ YES" : "❌ NO"}');
    _debug.log('STATUS', 'Stream active: ${_debug.listenerStreamActive ? "✅ YES" : "❌ NO"}');

    setState(() => _checkingStatus = false);
  }

  Future<void> _requestPermission() async {
    _debug.log('ACTION', '🔑 Requesting notification listener permission...');
    try {
      const platform = MethodChannel('com.xspoilt.takapay/sms');
      await platform.invokeMethod('requestNotificationListenerPermission');
      _debug.log('ACTION', 'Permission settings page opened');
    } catch (e) {
      _debug.log('ACTION', '❌ Failed to open permission settings: $e', isError: true);
    }
  }

  Future<void> _restartListener() async {
    _debug.log('ACTION', '🔄 Restarting notification listener...');
    NotificationHandler.instance.stopListening();
    await Future.delayed(const Duration(milliseconds: 500));
    NotificationHandler.instance.startListening();
    await _checkAllStatus();
  }

  Future<void> _fetchActiveNotifications() async {
    _debug.log('ACTION', '📋 Fetching active notifications from system...');
    try {
      final notifications = await NotificationListenerService.getActiveNotifications();
      _debug.log('ACTION', 'Found ${notifications.length} active notification(s):');
      for (int i = 0; i < notifications.length; i++) {
        final n = notifications[i];
        _debug.log('ACTIVE_NOTIF', '  [$i] pkg=${n.packageName ?? "?"}, title=${n.title ?? "?"}, content=${n.content ?? "?"}');
      }
      if (notifications.isEmpty) {
        _debug.log('ACTION', '⚠️ No active notifications found. This may mean the notification listener service is NOT connected to Android.');
      }
    } catch (e) {
      _debug.log('ACTION', '❌ Failed to fetch active notifications: $e', isError: true);
      _debug.log('ACTION', '⚠️ This usually means the NotificationListenerService is NOT running or permission is denied.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filterCategory == 'ALL'
        ? _debug.logs
        : _debug.logs.where((l) => l.category == _filterCategory).toList();

    return Scaffold(
      body: Column(
        children: [
          // Status Cards
          Container(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔍 Debug Dashboard',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_checkingStatus ? Icons.hourglass_top : Icons.refresh, size: 20),
                            tooltip: 'Refresh Status',
                            onPressed: _checkingStatus ? null : _checkAllStatus,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                            tooltip: 'Clear Logs',
                            onPressed: () {
                              _debug.clearLogs();
                              _debug.resetCounters();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Status indicators
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusChip('Permission', _permissionGranted),
                      _statusChip('BG Service', _bgServiceRunning),
                      _statusChip('Listener', NotificationHandler.instance.isListening),
                      _statusChip('Stream', _debug.listenerStreamActive),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Counters
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _counterTile('📩 Received', _debug.totalNotificationsReceived, Colors.blue),
                            _counterTile('✅ Parsed', _debug.totalNotificationsParsed, Colors.green),
                            _counterTile('⏭️ Skipped', _debug.totalParseSkipped, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _counterTile('🚀 Webhook OK', _debug.totalWebhooksSent, Colors.teal),
                            _counterTile('❌ Failed', _debug.totalWebhooksFailed, Colors.red),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _debug.lastNotificationTime != null
                                        ? DateFormat('HH:mm:ss').format(_debug.lastNotificationTime!)
                                        : '--:--',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Last Notif', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_debug.lastError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '⚠️ Last Error: ${_debug.lastError}',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _actionButton('📋 Fetch Active', _fetchActiveNotifications),
                        const SizedBox(width: 6),
                        _actionButton('🔄 Restart Listener', _restartListener),
                        const SizedBox(width: 6),
                        _actionButton('🔑 Permission', _requestPermission),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Filter bar
          Container(
            height: 36,
            color: Colors.grey.shade100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                _filterChip('ALL'),
                _filterChip('LISTENER'),
                _filterChip('NOTIFICATION'),
                _filterChip('PARSER'),
                _filterChip('WEBHOOK'),
                _filterChip('DATABASE'),
                _filterChip('STATUS'),
                _filterChip('ACTION'),
                _filterChip('ACTIVE_NOTIF'),
              ],
            ),
          ),
          // Log list
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bug_report, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'No logs yet.\nWaiting for activity...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[filteredLogs.length - 1 - index];
                      return _logTile(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? Colors.green : Colors.red, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterTile(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _filterChip(String category) {
    final isSelected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          ),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _logTile(DebugLogEntry log) {
    final timeStr = DateFormat('HH:mm:ss.S').format(log.timestamp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: log.isError ? Colors.red.shade50 : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _categoryColor(log.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              log.category,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _categoryColor(log.category),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                fontSize: 11,
                color: log.isError ? Colors.red.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'LISTENER':
        return Colors.purple;
      case 'NOTIFICATION':
        return Colors.blue;
      case 'PARSER':
        return Colors.orange;
      case 'WEBHOOK':
        return Colors.teal;
      case 'DATABASE':
        return Colors.indigo;
      case 'STATUS':
        return Colors.grey;
      case 'ACTION':
        return Colors.brown;
      case 'ACTIVE_NOTIF':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }
}
