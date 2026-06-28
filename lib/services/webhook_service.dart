import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_record.dart';

class WebhookConfig {
  final String id;
  final String url;
  final String secret;
  final String name;

  WebhookConfig({
    required this.id,
    required this.url,
    required this.secret,
    required this.name,
  });

  Map<String, String> toMap() {
    return {
      'id': id,
      'url': url,
      'secret': secret,
      'name': name,
    };
  }

  factory WebhookConfig.fromMap(Map<String, dynamic> map) {
    return WebhookConfig(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      secret: map['secret'] ?? '',
      name: map['name'] ?? '',
    );
  }
}

class WebhookResult {
  final bool isSuccess;
  final String report;

  WebhookResult({required this.isSuccess, required this.report});
}

class WebhookService {
  static const String _webhooksKey = 'webhooks_list';

  static String generateSecret() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Retrieves list of all configured webhooks
  static Future<List<WebhookConfig>> getWebhooks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_webhooksKey);
    
    // Backwards compatibility migration
    final legacyUrl = prefs.getString('webhook_url');
    final legacySecret = prefs.getString('webhook_secret') ?? '';

    List<WebhookConfig> list = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonStr);
        list = decoded.map((item) => WebhookConfig.fromMap(item)).toList();
      } catch (e) {
        print('Error decoding webhooks list: $e');
      }
    }

    // If no webhooks are configured but legacy exists, migrate it
    if (list.isEmpty && legacyUrl != null && legacyUrl.isNotEmpty) {
      final legacyConfig = WebhookConfig(
        id: 'legacy',
        url: legacyUrl,
        secret: legacySecret,
        name: 'Primary Webhook (Legacy)',
      );
      list.add(legacyConfig);
      await saveWebhooks(list);
    }

    return list;
  }

  /// Saves the list of webhooks to storage
  static Future<void> saveWebhooks(List<WebhookConfig> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((item) => item.toMap()).toList());
    await prefs.setString(_webhooksKey, jsonStr);
  }

  /// Adds a new webhook endpoint
  static Future<void> addWebhook(String name, String url, String secret) async {
    final list = await getWebhooks();
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    list.add(WebhookConfig(
      id: newId,
      url: url,
      secret: secret,
      name: name.isEmpty ? 'Webhook Endpoint' : name,
    ));
    await saveWebhooks(list);
  }

  /// Deletes a webhook endpoint by ID
  static Future<void> deleteWebhook(String id) async {
    final list = await getWebhooks();
    list.removeWhere((item) => item.id == id);
    await saveWebhooks(list);
  }

  /// Sends a transaction payload to all active webhooks in parallel
  static Future<WebhookResult> sendPayload(TransactionRecord record) async {
    final webhooks = await getWebhooks();
    if (webhooks.isEmpty) {
      return WebhookResult(
        isSuccess: false,
        report: 'No webhook endpoints configured',
      );
    }

    final List<Future<String?>> dispatches = webhooks.map((webhook) async {
      try {
        final response = await http.post(
          Uri.parse(webhook.url),
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Secret': webhook.secret,
          },
          body: jsonEncode({
            'sender': record.sender,
            'amount': record.amount,
            'trx_id': record.trxId,
            'raw_body': record.rawBody,
            'timestamp': record.timestamp.toIso8601String(),
            'from': record.senderNumber ?? 'Unknown',
            'secret': webhook.secret,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return null; // Success
        } else {
          return 'HTTP ${response.statusCode}';
        }
      } catch (e) {
        return 'Error ($e)';
      }
    }).toList();

    // Execute all posts in parallel
    final results = await Future.wait(dispatches);
    
    final List<String> reports = [];
    bool allSuccess = true;
    
    for (int i = 0; i < webhooks.length; i++) {
      final name = webhooks[i].name;
      final error = results[i];
      if (error == null) {
        reports.add('● $name: SUCCESS');
      } else {
        allSuccess = false;
        reports.add('● $name: FAILED ($error)');
      }
    }
    
    return WebhookResult(
      isSuccess: allSuccess,
      report: reports.join('\n'),
    );
  }

  /// Test connection to a specific URL
  static Future<bool> testConnection(String url, {String? secret}) async {
    try {
      final actualSecret = secret ?? '';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Secret': actualSecret,
        },
        body: jsonEncode({
          'test': 'connection',
          'secret': actualSecret,
        }),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
