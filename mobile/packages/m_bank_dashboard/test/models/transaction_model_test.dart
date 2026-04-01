import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/src/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'id': 10,
        'title': 'Salary',
        'counterparty': 'Employer',
        'amount': 50000.0,
        'category': 'Income',
        'iconKey': 'income',
        'type': 'INCOME',
        'status': 'COMPLETED',
        'accountName': 'Main Account',
        'occurredAt': '2026-03-15T12:00:00',
      };

      final model = TransactionModel.fromJson(json);

      expect(model.id, 10);
      expect(model.title, 'Salary');
      expect(model.counterparty, 'Employer');
      expect(model.amount, 50000.0);
      expect(model.category, 'Income');
      expect(model.iconKey, 'income');
      expect(model.type, 'INCOME');
      expect(model.status, 'COMPLETED');
      expect(model.accountName, 'Main Account');
      expect(model.occurredAt, DateTime(2026, 3, 15, 12));
      expect(model.isIncome, isTrue);
    });

    test('negative amount is not income', () {
      final json = <String, dynamic>{
        'id': 11,
        'title': 'Rent',
        'counterparty': 'Landlord',
        'amount': -25000.0,
        'category': 'Housing',
        'iconKey': 'rent',
        'type': 'EXPENSE',
        'status': 'COMPLETED',
        'accountName': 'Main Account',
        'occurredAt': '2026-03-01T12:00:00',
      };

      final model = TransactionModel.fromJson(json);

      expect(model.isIncome, isFalse);
      expect(model.amount, -25000.0);
    });

    test('zero amount is considered income', () {
      final json = <String, dynamic>{
        'id': 12,
        'title': 'Refund',
        'counterparty': 'Shop',
        'amount': 0.0,
        'category': 'Other',
        'iconKey': 'other',
        'type': 'INCOME',
        'status': 'COMPLETED',
        'accountName': 'Main Account',
        'occurredAt': '2026-03-10T08:00:00',
      };

      final model = TransactionModel.fromJson(json);

      expect(model.isIncome, isTrue);
    });
  });
}
