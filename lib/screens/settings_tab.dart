import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/webhook_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  List<WebhookConfig> _webhooks = [];
  bool _isLoading = true;
  final Map<String, bool> _testingStatus = {};

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  Future<void> _loadWebhooks() async {
    setState(() => _isLoading = true);
    final list = await WebhookService.getWebhooks();
    setState(() {
      _webhooks = list;
      _isLoading = false;
    });
  }

  Future<void> _testConnection(WebhookConfig webhook) async {
    setState(() => _testingStatus[webhook.id] = true);
    
    final success = await WebhookService.testConnection(webhook.url, secret: webhook.secret);
    
    setState(() => _testingStatus[webhook.id] = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? 'Successfully reached "${webhook.name}"'
                      : 'Failed to reach "${webhook.name}" (check URL/server)',
                ),
              ),
            ],
          ),
          backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddWebhookDialog() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final secretController = TextEditingController(text: WebhookService.generateSecret());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_link_rounded, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add Webhook Endpoint',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Endpoint Name',
                      hintText: 'e.g. Shop 1, Analytics System',
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter an endpoint name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'Webhook URL',
                      hintText: 'https://example.com/api/webhook',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the URL';
                      }
                      if (!value.trim().startsWith('http://') &&
                          !value.trim().startsWith('https://')) {
                        return 'URL must start with http:// or https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: secretController,
                    decoration: InputDecoration(
                      labelText: 'Secret Token',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.autorenew_rounded, size: 20),
                        tooltip: 'Generate Random Secret',
                        onPressed: () {
                          secretController.text = WebhookService.generateSecret();
                        },
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter a secret token'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await WebhookService.addWebhook(
                              nameController.text.trim(),
                              urlController.text.trim(),
                              secretController.text.trim(),
                            );
                            Navigator.pop(context);
                            _loadWebhooks();
                          }
                        },
                        child: const Text('Add Endpoint'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteWebhook(WebhookConfig webhook) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Webhook Endpoint?'),
        content: Text('Are you sure you want to remove "${webhook.name}"?\nThis endpoint will stop receiving transaction payloads immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WebhookService.deleteWebhook(webhook.id);
      _loadWebhooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook endpoint deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Webhook Destinations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddWebhookDialog,
            tooltip: 'Add Endpoint',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _webhooks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _webhooks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _webhooks.length) {
                      return _buildInstructionCard();
                    }
                    final webhook = _webhooks[index];
                    final isTesting = _testingStatus[webhook.id] ?? false;
                    return _buildWebhookCard(webhook, isTesting);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.webhook_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No Webhook Endpoints Configured',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Forward incoming payments to your servers. Add your first webhook endpoint now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddWebhookDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Endpoint'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookCard(WebhookConfig webhook, bool isTesting) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.webhook_rounded, color: Colors.blue, size: 20),
        ),
        title: Text(
          webhook.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          webhook.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontFamily: 'monospace'),
        ),
        trailing: isTesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                const SizedBox(height: 4),
                const Text(
                  'Secret Token',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          webhook.secret,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Copy Secret',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: webhook.secret));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Secret token copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: isTesting ? null : () => _testConnection(webhook),
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text('Test Connection', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteWebhook(webhook),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      color: const Color(0xFFE3F2FD),
      elevation: 0,
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Multi-Webhook Integration',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Incoming transactions will be forwarded to ALL configured webhooks in parallel.',
              style: TextStyle(fontSize: 12, height: 1.45, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            const Text(
              '2. Each endpoint will receive a POST request with the following headers and JSON body:',
              style: TextStyle(fontSize: 12, height: 1.45, color: Colors.black87),
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
                    'Header:\n  X-Webhook-Secret: <webhook_secret>',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Body:\n  {\n    "sender": "bKash",\n    "amount": "1000.00",\n    "from": "017XXXXXXXX",\n    "trx_id": "7L45K8J9",\n    "raw_body": "...",\n    "timestamp": "...",\n    "secret": "<webhook_secret>"\n  }',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
