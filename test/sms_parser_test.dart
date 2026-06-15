import 'package:flutter_test/flutter_test.dart';
import 'package:takapay/utils/sms_parser.dart';

void main() {
  group('SMSParser Tests', () {
    test('Parse bKash Payment Message', () {
      const body = 'Payment Tk 500.00 to 017XXXXXXXX successful. Fee Tk 0.00. Balance Tk 1,200.00. TrxID 7L45K8J9 at 12/10/2023 14:30';
      const sender = 'bKash';
      
      final record = SMSParser.parse(sender, body);
      
      expect(record, isNotNull);
      expect(record!.sender, 'bKash');
      expect(record.amount, '500.00');
      expect(record.trxId, '7L45K8J9');
    });

    test('Parse Nagad Cash In Message', () {
      const body = 'Cash In Tk 2,000.00 from 019XXXXXXXX successful. Fee: Tk 0.00. Balance: Tk 2500.00. TxnID: 71M7890BC at 12/10/2023 16:20';
      const sender = 'Nagad';
      
      final record = SMSParser.parse(sender, body);
      
      expect(record, isNotNull);
      expect(record!.sender, 'Nagad');
      expect(record.amount, '2,000.00');
      expect(record.trxId, '71M7890BC');
    });

    test('Ignore non-payment message', () {
      const body = 'Your OTP is 123456. Do not share it with anyone.';
      const sender = 'AnySender';
      
      final record = SMSParser.parse(sender, body);
      
      expect(record, isNull);
    });
  });
}
