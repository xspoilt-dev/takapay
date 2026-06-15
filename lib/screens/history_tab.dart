import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../services/database_helper.dart';
import '../services/webhook_service.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late Future<List<TransactionRecord>> _historyFuture;
  final Set<int> _retryingIds = {};

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = DatabaseHelper.instance.getAllTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<TransactionRecord>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return const Center(child: Text('No transactions yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshHistory();
            },
            child: ListView.builder(
              itemCount: records.size,
              itemBuilder: (context, index) {
                final record = records[index];
                final bool isSuccess = record.status == 'SUCCESS';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    onTap: () => _showTransactionDetails(record),
                    leading: CircleAvatar(
                      backgroundColor: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isSuccess ? Icons.check : Icons.error,
                        color: isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text('${record.sender}: ${record.amount} TK'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TrxID: ${record.trxId}'),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(record.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (!isSuccess && record.errorMessage != null)
                          Text(
                            record.errorMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.red, fontSize: 11),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshHistory,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  void _showTransactionDetails(TransactionRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isSuccess = record.status == 'SUCCESS';
            final bool isRetrying = _retryingIds.contains(record.id);

            String? fromNumber;
            final fromRegex = RegExp(r'from\s+([a-zA-Z0-9\-\+\s]{5,17})', caseSensitive: false);
            final match = fromRegex.firstMatch(record.rawBody);
            if (match != null) {
              fromNumber = match.group(1)?.trim();
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Transaction Log Detail',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('Sender', record.sender),
                    _detailRow('From Number', fromNumber ?? 'Unknown'),
                    _detailRow('Amount', '${record.amount} TK'),
                    _detailRow('Transaction ID', record.trxId),
                    _detailRow('Time', DateFormat('dd MMM yyyy, hh:mm:ss a').format(record.timestamp)),
                    _detailRow('Status', record.status, color: isSuccess ? Colors.green : Colors.red),
                    if (record.errorMessage != null)
                      _detailRow('Webhook Delivery Logs', record.errorMessage!, isBold: true, color: Colors.red),
                    const Divider(),
                    const Text('Raw Notification Body:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        record.rawBody,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isSuccess)
                  TextButton(
                    onPressed: isRetrying
                        ? null
                        : () async {
                            setDialogState(() {
                              _retryingIds.add(record.id!);
                            });

                            // Retry sending to webhook
                            final errorReason = await WebhookService.sendPayload(record);
                            final bool retrySuccess = errorReason == null;

                            final updatedRecord = TransactionRecord(
                              id: record.id,
                              sender: record.sender,
                              amount: record.amount,
                              trxId: record.trxId,
                              rawBody: record.rawBody,
                              timestamp: record.timestamp,
                              status: retrySuccess ? 'SUCCESS' : 'FAILED',
                              errorMessage: errorReason,
                            );

                            await DatabaseHelper.instance.updateTransaction(updatedRecord);

                            // Update local variables
                            if (mounted) {
                              setState(() {
                                _refreshHistory();
                              });
                            }

                            setDialogState(() {
                              _retryingIds.remove(record.id);
                              record = updatedRecord; // Update dialog view
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(retrySuccess
                                      ? 'Sent successfully to server!'
                                      : 'Resend failed: $errorReason'),
                                  backgroundColor: retrySuccess ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                    child: isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend to Server'),
                  ),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

extension on List<TransactionRecord> {
  int get size => length;
}
