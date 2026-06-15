import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/webhook_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _urlController = TextEditingController();
  String _webhookSecret = '';
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? secret = prefs.getString('webhook_secret');
    if (secret == null || secret.isEmpty) {
      secret = WebhookService.generateSecret();
      await prefs.setString('webhook_secret', secret);
    }
    setState(() {
      _urlController.text = prefs.getString('webhook_url') ?? '';
      _webhookSecret = secret!;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhook_url', _urlController.text.trim());
    await prefs.setString('webhook_secret', _webhookSecret);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  Future<void> _confirmRegenerateSecret() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Secret Token?'),
        content: const Text(
          'This will generate a new secret token. Any server validating webhooks with the old token will reject new payloads until updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _webhookSecret = WebhookService.generateSecret();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New secret generated. Don\'t forget to Save Settings!')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL first')),
      );
      return;
    }

    setState(() => _isTesting = true);
    final success = await WebhookService.testConnection(url, secret: _webhookSecret);
    setState(() => _isTesting = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(success ? 'Success' : 'Failed'),
          content: Text(success
              ? 'Webhook is reachable!'
              : 'Could not reach the webhook. Please check the URL and your server.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Webhook Configuration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://yourserver.com/api/webhook',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              const Text(
                'Webhook Secret Token',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _webhookSecret.isEmpty ? 'Generating...' : _webhookSecret,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy Secret Token',
                      onPressed: _webhookSecret.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: _webhookSecret));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Secret token copied to clipboard')),
                              );
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.redAccent),
                      tooltip: 'Regenerate Secret Token',
                      onPressed: _webhookSecret.isEmpty ? null : _confirmRegenerateSecret,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                child: _isTesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test Connection'),
              ),
              const SizedBox(height: 32),
              Card(
                color: const Color(0xFFE3F2FD),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Integration Instructions',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Ensure your server accepts POST requests with a JSON body.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '2. Verify that incoming webhook requests originate from this app by checking the secret token in one of two ways:',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HTTP Header:\n  X-Webhook-Secret: <your_secret>',
                              style: TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.3),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'JSON Request Body:\n  {\n    "secret": "<your_secret>",\n    ...\n  }',
                              style: TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
