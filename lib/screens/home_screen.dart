import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../services/background_service.dart';
import '../services/notification_handler.dart';
import '../services/debug_logger.dart';
import 'history_tab.dart';
import 'settings_tab.dart';
import 'debug_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.sms,
        Permission.ignoreBatteryOptimizations,
        Permission.notification,
      ].request();
    } catch (e) {
      debugPrint("Standard permission request error: $e");
    }

    // Check & request notification listener permission
    try {
      bool isGranted = await NotificationListenerService.isPermissionGranted();
      if (!isGranted) {
        const platform = MethodChannel('com.xspoilt.takapay/sms');
        await platform.invokeMethod('requestNotificationListenerPermission');
      }
    } catch (e) {
      debugPrint("NotificationListenerService permission error: $e");
    }

    // Safely initialize the background service after granting notification permissions
    try {
      await initializeService();
    } catch (e) {
      debugPrint("Error initializing background service: $e");
    }

    // Load persisted debug logs on startup
    try {
      await DebugLogger.instance.loadFromPersisted();
      debugPrint('Persisted debug logs loaded successfully');
    } catch (e) {
      debugPrint('Error loading debug logs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.all(10.0),
            child: TakaLogo(size: 32),
          ),
          title: const Text(
            'Takapay',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'History'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
              Tab(icon: Icon(Icons.bug_report), text: 'Debug'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HistoryTab(),
            SettingsTab(),
            DebugTab(),
          ],
        ),
      ),
    );
  }
}

class TakaLogo extends StatelessWidget {
  final double size;
  const TakaLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '৳',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
