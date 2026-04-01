import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/src/models/account_model.dart';

void main() {
  group('AccountModel', () {
    test('fromJson parses all fields correctly', () {
      final json = <String, dynamic>{
        'id': 1,
        'name': 'Main',
        'type': 'MAIN',
        'balance': 15000.50,
        'currency': 'KGS',
      };

      final model = AccountModel.fromJson(json);

      expect(model.id, 1);
      expect(model.name, 'Main');
      expect(model.type, 'MAIN');
      expect(model.balance, 15000.50);
      expect(model.currency, 'KGS');
    });

    test('fromJson handles integer balance', () {
      final json = <String, dynamic>{
        'id': 2,
        'name': 'Savings',
        'type': 'SAVINGS',
        'balance': 50000,
        'currency': 'KGS',
      };

      final model = AccountModel.fromJson(json);

      expect(model.balance, 50000.0);
    });
  });
}
