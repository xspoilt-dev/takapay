import '../models/transaction_record.dart';

class SMSParser {
  static TransactionRecord? parse(String sender, String body) {
    String? amount;
    String? trxId;
    String cleanSender = 'Unknown';

    String lowerBody = body.toLowerCase();
    String lowerSender = sender.toLowerCase();

    if (lowerBody.contains('bkash') || lowerSender.contains('bkash')) {
      cleanSender = 'bKash';
      // bKash pattern: Tk 500.00 ... TrxID 7L45K8J9
      final amountRegex = RegExp(r'Tk\s+([\d,]+\.\d{2})', caseSensitive: false);
      final trxRegex = RegExp(r'TrxID\s+([A-Z0-9]{8,11})', caseSensitive: false);

      final amountMatch = amountRegex.firstMatch(body);
      final trxMatch = trxRegex.firstMatch(body);

      if (amountMatch != null) amount = amountMatch.group(1);
      if (trxMatch != null) trxId = trxMatch.group(1);
    } else if (lowerBody.contains('nagad') || lowerSender.contains('nagad')) {
      cleanSender = 'Nagad';
      // Nagad pattern: Tk 2,000.00 ... TxnID: 71M7890BC
      final amountRegex = RegExp(r'Tk\s+([\d,]+\.\d{2})', caseSensitive: false);
      final trxRegex = RegExp(r'TxnID:\s+([A-Z0-9]{8,12})', caseSensitive: false);

      final amountMatch = amountRegex.firstMatch(body);
      final trxMatch = trxRegex.firstMatch(body);

      if (amountMatch != null) amount = amountMatch.group(1);
      if (trxMatch != null) trxId = trxMatch.group(1);
    }

    if (amount != null && trxId != null) {
      return TransactionRecord(
        sender: cleanSender,
        amount: amount,
        trxId: trxId,
        rawBody: body,
        timestamp: DateTime.now(),
        status: 'PENDING',
      );
    }

    return null;
  }
}
