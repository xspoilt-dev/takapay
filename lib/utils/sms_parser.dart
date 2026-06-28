import '../models/transaction_record.dart';

class SMSParser {
  static TransactionRecord? parse(String sender, String body) {
    String? amount;
    String? trxId;
    String? senderNumber;
    String cleanSender = 'Unknown';

    String lowerBody = body.toLowerCase();
    String lowerSender = sender.toLowerCase();

    bool isMfs = false;
    
    // Support bKash, Nagad, and Rocket
    if (lowerBody.contains('bkash') || lowerSender.contains('bkash')) {
      cleanSender = 'bKash';
      isMfs = true;
    } else if (lowerBody.contains('nagad') || lowerSender.contains('nagad')) {
      cleanSender = 'Nagad';
      isMfs = true;
    } else if (lowerBody.contains('rocket') || lowerSender.contains('rocket') || lowerSender.contains('dbbl') || lowerSender.contains('16216')) {
      cleanSender = 'Rocket';
      isMfs = true;
    }

    if (!isMfs) return null;

    // Generic robust amount extraction
    // Matches Tk 500.00, Tk. 5,000.00, Tk.5,000.00, Tk 10000.00, etc.
    final amountRegex = RegExp(r'Tk\.?\s*([\d,]+\.\d{2})', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch != null) {
      amount = amountMatch.group(1);
    }

    // Generic robust transaction ID extraction
    // Matches TrxID 7L45K8J9, TxnID: 71M7890BC, Txn ID: 2212345678, Trx ID: 2212345678, TxnId: ABC123XYZ, etc.
    final trxRegex = RegExp(r'(?:TrxID|TxnID|Txn\s+ID|Trx\s+ID)\s*:?\s*([A-Za-z0-9]+)', caseSensitive: false);
    final trxMatch = trxRegex.firstMatch(body);
    if (trxMatch != null) {
      trxId = trxMatch.group(1);
    }

    // Extract sender phone number (e.g. from 017xxxxxxxx)
    final fromPhoneRegex = RegExp(r'(?:from|by)\s*(?:\+?88)?(01[3-9]\d{8})', caseSensitive: false);
    final fromPhoneMatch = fromPhoneRegex.firstMatch(body);
    if (fromPhoneMatch != null) {
      senderNumber = fromPhoneMatch.group(1);
    } else {
      // Fallback: search for any 11-digit Bangladeshi number starting with 01
      final phoneRegex = RegExp(r'\b(01[3-9]\d{8})\b');
      final phoneMatch = phoneRegex.firstMatch(body);
      if (phoneMatch != null) {
        senderNumber = phoneMatch.group(1);
      }
    }

    if (amount != null && trxId != null) {
      return TransactionRecord(
        sender: cleanSender,
        amount: amount,
        trxId: trxId,
        rawBody: body,
        timestamp: DateTime.now(),
        status: 'PENDING',
        senderNumber: senderNumber,
      );
    }

    return null;
  }
}
