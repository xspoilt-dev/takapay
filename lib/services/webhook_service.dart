import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_record.dart';

class WebhookService {
  static String generateSecret() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<String?> sendPayload(TransactionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webhook_url');
    final secret = prefs.getString('webhook_secret') ?? '';

    if (url == null || url.isEmpty) {
      return 'Webhook URL not configured';
    }

    String? fromNumber;
    final fromRegex = RegExp(r'from\s+([a-zA-Z0-9\-\+\s]{5,17})', caseSensitive: false);
    final match = fromRegex.firstMatch(record.rawBody);
    if (match != null) {
      fromNumber = match.group(1)?.trim();
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Secret': secret,
        },
        body: jsonEncode({
          'sender': record.sender,
          'amount': record.amount,
          'trx_id': record.trxId,
          'raw_body': record.rawBody,
          'timestamp': record.timestamp.toIso8601String(),
          'from': fromNumber ?? 'Unknown',
          'secret': secret,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      } else {
        return 'HTTP ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      print('Webhook error: $e');
      return 'Error: $e';
    }
  }

  static Future<bool> testConnection(String url, {String? secret}) async {
    try {
      final actualSecret = secret ?? (await SharedPreferences.getInstance()).getString('webhook_secret') ?? '';
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

