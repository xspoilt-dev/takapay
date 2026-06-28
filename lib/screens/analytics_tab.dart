import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_record.dart';
import '../services/database_helper.dart';
import '../services/notification_handler.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class SenderStat {
  final String number;
  double totalAmount;
  int count;
  DateTime lastTime;
  final Set<String> channels;

  SenderStat({
    required this.number,
    required this.totalAmount,
    required this.count,
    required this.lastTime,
    required this.channels,
  });
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  late Future<List<TransactionRecord>> _transactionsFuture;
  String _searchQuery = '';
  String _channelFilter = 'ALL';
  StreamSubscription? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _refreshSubscription = NotificationHandler.onTransactionCaptured.stream.listen((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _transactionsFuture = DatabaseHelper.instance.getAllTransactions();
    });
  }

  Future<void> _dialNumber(String number) async {
    try {
      const platform = MethodChannel('com.xspoilt.takapay/sms');
      await platform.invokeMethod('dialNumber', {'number': number});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open dialer: $e')),
        );
      }
    }
  }

  String? _fallbackSenderNumber(String body) {
    final fromPhoneRegex = RegExp(r'(?:from|by)\s*(?:\+?88)?(01[3-9]\d{8})', caseSensitive: false);
    final fromPhoneMatch = fromPhoneRegex.firstMatch(body);
    if (fromPhoneMatch != null) {
      return fromPhoneMatch.group(1);
    }
    final phoneRegex = RegExp(r'\b(01[3-9]\d{8})\b');
    final phoneMatch = phoneRegex.firstMatch(body);
    if (phoneMatch != null) {
      return phoneMatch.group(1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder<List<TransactionRecord>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];
          final successRecords = records.where((r) => r.status == 'SUCCESS').toList();

          // Calculate general stats
          double totalReceived = 0;
          double bkashTotal = 0;
          double nagadTotal = 0;
          double rocketTotal = 0;

          final Map<String, SenderStat> senderStatsMap = {};

          for (final record in successRecords) {
            final double amt = double.tryParse(record.amount.replaceAll(',', '')) ?? 0;
            totalReceived += amt;

            if (record.sender.toLowerCase().contains('bkash')) {
              bkashTotal += amt;
            } else if (record.sender.toLowerCase().contains('nagad')) {
              nagadTotal += amt;
            } else if (record.sender.toLowerCase().contains('rocket')) {
              rocketTotal += amt;
            }

            final number = record.senderNumber ?? _fallbackSenderNumber(record.rawBody) ?? 'Unknown';
            if (senderStatsMap.containsKey(number)) {
              final stat = senderStatsMap[number]!;
              stat.totalAmount += amt;
              stat.count += 1;
              if (record.timestamp.isAfter(stat.lastTime)) {
                stat.lastTime = record.timestamp;
              }
              stat.channels.add(record.sender);
            } else {
              senderStatsMap[number] = SenderStat(
                number: number,
                totalAmount: amt,
                count: 1,
                lastTime: record.timestamp,
                channels: {record.sender},
              );
            }
          }

          // Convert to list & filter
          final senderStats = senderStatsMap.values.where((stat) {
            if (_searchQuery.isNotEmpty && !stat.number.contains(_searchQuery)) {
              return false;
            }
            if (_channelFilter != 'ALL') {
              final matchesFilter = stat.channels.any((c) => c.toUpperCase() == _channelFilter.toUpperCase());
              if (!matchesFilter) return false;
            }
            return true;
          }).toList();

          // Sort by total amount descending
          senderStats.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
            },
            child: CustomScrollView(
              slivers: [
                // Top Summary Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Total Money Banner
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blueAccent, Colors.blue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL REVENUE RECEIVED',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${NumberFormat('#,##,##0.00').format(totalReceived)} TK',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${successRecords.length} Successful Payments',
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                                  ),
                                  Text(
                                    'Customers: ${senderStatsMap.length}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Channel Breakdown Cards
                        Row(
                          children: [
                            Expanded(
                              child: _channelStatCard('bKash', bkashTotal, Colors.pink.shade50, Colors.pink.shade700),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _channelStatCard('Nagad', nagadTotal, Colors.orange.shade50, Colors.orange.shade800),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _channelStatCard('Rocket', rocketTotal, Colors.purple.shade50, Colors.purple.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search & Filter header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        // Search field
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search customer numbers...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        // Channel Filter Selector Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _filterButton('ALL', Colors.blueGrey),
                            const SizedBox(width: 6),
                            _filterButton('BKASH', Colors.pink),
                            const SizedBox(width: 6),
                            _filterButton('NAGAD', Colors.orange),
                            const SizedBox(width: 6),
                            _filterButton('ROCKET', Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Customer List Title
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Customer Rankings (by Amount)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                    ),
                  ),
                ),

                // Sender Directory List
                senderStats.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text('No customers match the criteria.'),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final stat = senderStats[index];
                            return _buildCustomerTile(stat, index + 1);
                          },
                          childCount: senderStats.length,
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _channelStatCard(String channel, double amount, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            channel,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,##0').format(amount)} ৳',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String val, Color color) {
    final bool isSelected = _channelFilter == val;
    return GestureDetector(
      onTap: () {
        setState(() {
          _channelFilter = val;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(
          val,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerTile(SenderStat stat, int rank) {
    final bool isUnknown = stat.number == 'Unknown';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              stat.number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isUnknown ? Colors.grey : Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(width: 8),
            // Badges for channels
            ...stat.channels.map((ch) {
              Color badgeColor = Colors.grey;
              if (ch.toLowerCase().contains('bkash')) badgeColor = Colors.pink;
              else if (ch.toLowerCase().contains('nagad')) badgeColor = Colors.orange;
              else if (ch.toLowerCase().contains('rocket')) badgeColor = Colors.purple;

              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ch[0].toUpperCase() + ch.substring(1).toLowerCase(),
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              );
            }),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${stat.count} txs',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              'Last: ${DateFormat('dd MMM').format(stat.lastTime)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${NumberFormat('#,##0').format(stat.totalAmount)} ৳',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
            ),
            if (!isUnknown) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone_enabled_rounded, color: Colors.green, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _dialNumber(stat.number),
                  tooltip: 'Call Customer',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
