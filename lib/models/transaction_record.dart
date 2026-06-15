class TransactionRecord {
  final int? id;
  final String sender;
  final String amount;
  final String trxId;
  final String rawBody;
  final DateTime timestamp;
  final String status; // 'SUCCESS', 'FAILED', 'PENDING'
  final String? errorMessage;

  TransactionRecord({
    this.id,
    required this.sender,
    required this.amount,
    required this.trxId,
    required this.rawBody,
    required this.timestamp,
    required this.status,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'amount': amount,
      'trx_id': trxId,
      'raw_body': rawBody,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'error_message': errorMessage,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'],
      sender: map['sender'],
      amount: map['amount'],
      trxId: map['trx_id'],
      rawBody: map['raw_body'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
      errorMessage: map['error_message'],
    );
  }
}
