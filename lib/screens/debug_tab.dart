import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import '../services/debug_logger.dart';

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
  bool _showGuide = true;
  String _filterType = 'ALL'; 
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _debug.addListener(_onDebugUpdate);
    _checkAllStatus();
    
    // Periodically fetch new logs/counters written by the background isolate
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _debug.loadFromPersisted();
        _checkAllStatus(logStatus: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _debug.removeListener(_onDebugUpdate);
    super.dispose();
  }

  void _onDebugUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAllStatus({bool logStatus = true}) async {
    if (logStatus) {
      setState(() => _checkingStatus = true);
      _debug.log('STATUS', 'Verifying running service components');
    }

    try {
      _permissionGranted = await NotificationListenerService.isPermissionGranted();
      _debug.permissionGranted = _permissionGranted;
    } catch (e) {
      if (logStatus) _debug.log('STATUS', 'Failed to check notification permission: $e', isError: true);
      _permissionGranted = false;
    }

    try {
      final service = FlutterBackgroundService();
      _bgServiceRunning = await service.isRunning();
      _debug.backgroundServiceRunning = _bgServiceRunning;
    } catch (e) {
      if (logStatus) _debug.log('STATUS', 'Failed to query background service status: $e', isError: true);
      _bgServiceRunning = false;
    }

    if (mounted) {
      setState(() {
        _checkingStatus = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    _debug.log('ACTION', 'Opening Android notification listener access settings');
    try {
      const platform = MethodChannel('com.xspoilt.takapay/sms');
      await platform.invokeMethod('requestNotificationListenerPermission');
    } catch (e) {
      _debug.log('ACTION', 'UI failed to open settings activity: $e', isError: true);
    }
  }

  Future<void> _restartBackgroundService() async {
    _debug.log('ACTION', 'Restarting background engine');
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke("stopService");
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await service.startService();
      _debug.log('ACTION', 'Background service start signal triggered');
      await _checkAllStatus();
    } catch (e) {
      _debug.log('ACTION', 'Error restarting service: $e', isError: true);
    }
  }

  Future<void> _fetchActiveNotifications() async {
    _debug.log('ACTION', 'Querying active status notifications from Android OS');
    try {
      final notifications = await NotificationListenerService.getActiveNotifications();
      _debug.log('ACTION', 'Retrieved ${notifications.length} active notification(s)');
      for (int i = 0; i < notifications.length; i++) {
        final n = notifications[i];
        _debug.log('ACTIVE_NOTIF', '  Package: ${n.packageName ?? "unknown"} | Title: ${n.title ?? "none"} | Content: ${n.content ?? "none"}');
      }
      if (notifications.isEmpty) {
        _debug.log('ACTION', 'No notifications in status bar');
      }
    } catch (e) {
      _debug.log('ACTION', 'Android Service query failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine filters
    final List<DebugLogEntry> filteredLogs = _debug.logs.where((log) {
      if (_filterType == 'ALL') return true;
      if (_filterType == 'ERRORS') return log.isError;
      if (_filterType == 'SUCCESS') {
        final msg = log.message.toLowerCase();
        return msg.contains('success') || msg.contains('ok') || msg.contains('granted') || msg.contains('active') || msg.contains('created successfully');
      }
      return log.category.toUpperCase() == _filterType.toUpperCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Elegant Header Status Cards
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dashboard_customize_rounded, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Service Diagnostics',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_checkingStatus ? Icons.refresh : Icons.autorenew_rounded, color: Colors.blueGrey, size: 20),
                          tooltip: 'Reload Status',
                          onPressed: _checkingStatus ? null : () => _checkAllStatus(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Clear Debug History',
                          onPressed: () => _confirmClearLogs(),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 4),
                // Components Status Badges
                Row(
                  children: [
                    Expanded(child: _statusCard('System Access', _permissionGranted, Icons.key_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusCard('Daemon Process', _bgServiceRunning, Icons.run_circle_outlined)),
                  ],
                ),

                if (_debug.lastError != null && _debug.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            'Error: ${_debug.lastError}',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _debug.lastError = null;
                            });
                          },
                          child: const Icon(Icons.close, size: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],

                // Background Keep-Alive Helper Box
                if (_showGuide) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Background Keep-Alive Guide',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showGuide = false),
                              child: Icon(Icons.close, size: 14, color: Colors.amber.shade800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To prevent Android from killing the forwarding daemon when you swipe this app away from the recent apps menu:',
                          style: TextStyle(fontSize: 10, color: Colors.amber.shade900, height: 1.35),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. Lock the app in your phone Recents screen (Tap the app icon in Recents and choose Lock).\n2. Set Battery Usage to Unrestricted under Settings -> Apps -> Takapay -> Battery.',
                          style: TextStyle(fontSize: 9.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // Counter Grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _counterColumn('Inbox Notif', _debug.totalNotificationsReceived, Colors.blue, Icons.notifications_active_rounded),
                          _counterColumn('Parsed OK', _debug.totalNotificationsParsed, Colors.green, Icons.fact_check_rounded),
                          _counterColumn('Ignored', _debug.totalParseSkipped, Colors.orange, Icons.next_plan_rounded),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _counterColumn('Webhook Out', _debug.totalWebhooksSent, Colors.teal, Icons.cloud_done_rounded),
                          _counterColumn('Failed', _debug.totalWebhooksFailed, Colors.red, Icons.cloud_off_rounded),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.blueGrey),
                                    const SizedBox(width: 4),
                                    Text(
                                      _debug.lastNotificationTime != null
                                          ? DateFormat('HH:mm:ss').format(_debug.lastNotificationTime!)
                                          : 'N/A',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Last Capture', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Action row
                Row(
                  children: [
                    Expanded(
                      child: _quickActionButton(
                        icon: Icons.search_rounded,
                        label: 'OS Active List',
                        color: Colors.blue,
                        onPressed: _fetchActiveNotifications,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quickActionButton(
                        icon: Icons.power_settings_new_rounded,
                        label: 'Reboot Daemon',
                        color: Colors.teal,
                        onPressed: _restartBackgroundService,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quickActionButton(
                        icon: Icons.vpn_key_rounded,
                        label: 'Grant Access',
                        color: Colors.purple,
                        onPressed: _requestPermission,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filter Chips Section
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade100),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                _filterChip('ALL', Icons.all_inclusive_rounded, Colors.grey.shade800),
                _filterChip('ERRORS', Icons.error_outline_rounded, Colors.red),
                _filterChip('SUCCESS', Icons.check_circle_outline_rounded, Colors.green),
                _filterChip('SYSTEM', Icons.dns_rounded, Colors.indigo),
                _filterChip('NOTIFICATION', Icons.notifications_none_rounded, Colors.blue),
                _filterChip('PARSER', Icons.terminal_rounded, Colors.orange),
                _filterChip('WEBHOOK', Icons.webhook_rounded, Colors.teal),
                _filterChip('DATABASE', Icons.storage_rounded, Colors.deepPurple),
                _filterChip('STATUS', Icons.network_check_rounded, Colors.blueGrey),
                _filterChip('ACTION', Icons.touch_app_rounded, Colors.brown),
              ],
            ),
          ),
          // Log console entries
          filteredLogs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: _emptyStateView(),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _logTile(log);
                  },
                ),
        ],
      ),
    );
  }

  Widget _statusCard(String label, bool active, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? Colors.green.shade200 : Colors.red.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: active ? Colors.green.shade800 : Colors.red.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  active ? 'RUNNING' : 'STOPPED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterColumn(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, Color color) {
    final isSelected = _filterType == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        avatar: Icon(icon, size: 12, color: isSelected ? Colors.white : color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
        onSelected: (bool selected) {
          setState(() {
            _filterType = label;
          });
        },
        selectedColor: color,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300, width: 0.8),
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _logTile(DebugLogEntry log) {
    final timeStr = DateFormat('HH:mm:ss.SS').format(log.timestamp);
    final categoryColor = _categoryColor(log.category);
    final categoryIcon = _categoryIcon(log.category);

    return InkWell(
      onTap: () => _showLogDetailsDialog(log),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: log.isError ? Colors.red.shade50.withOpacity(0.4) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time prefix
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            // Category Icon Badge
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon,
                size: 11,
                color: categoryColor,
              ),
            ),
            const SizedBox(width: 8),
            // Log message body (strip emojis dynamically just in case)
            Expanded(
              child: Text(
                _stripEmojis(log.message),
                style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: log.isError ? Colors.red.shade800 : Colors.blueGrey.shade900,
                  height: 1.3,
                ),
              ),
            ),
            if (log.message.length > 50)
              const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
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

  Widget _emptyStateView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'No matching log console entries\nfor filter category "$_filterType"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Debug Diagnostics?'),
        content: const Text('This will delete all persisted debug log files and reset counters from storage.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context);
              await _debug.clearLogs();
              await _debug.resetCounters();
              _debug.log('SYSTEM', 'Persisted log databases successfully cleared');
            },
          ),
        ],
      ),
    );
  }

  void _showLogDetailsDialog(DebugLogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_categoryIcon(log.category), color: _categoryColor(log.category)),
            const SizedBox(width: 8),
            Text(
              '${log.category} log entry detail',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SelectableText(
                  _stripEmojis(log.message),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Copy to Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _stripEmojis(log.message)));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied to clipboard')),
              );
            },
          ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'LISTENER':
        return Icons.hearing_rounded;
      case 'NOTIFICATION':
        return Icons.sms_rounded;
      case 'PARSER':
        return Icons.terminal_rounded;
      case 'WEBHOOK':
        return Icons.webhook_rounded;
      case 'DATABASE':
        return Icons.storage_rounded;
      case 'STATUS':
        return Icons.wifi_protected_setup_rounded;
      case 'ACTION':
        return Icons.touch_app_rounded;
      case 'ACTIVE_NOTIF':
        return Icons.pageview_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
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
        return Colors.blueGrey;
      case 'ACTION':
        return Colors.brown;
      case 'ACTIVE_NOTIF':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }
}
