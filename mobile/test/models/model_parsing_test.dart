import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/account_model.dart';
import 'package:hackathon_bank_mobile/models/ai_analysis_model.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/models/transaction_model.dart';
import 'package:hackathon_bank_mobile/models/transfer_result_model.dart';

void main() {
  test('parses account model', () {
    final account = AccountModel.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Main',
      'type': 'MAIN',
      'balance': 15000,
      'currency': 'KGS',
    });

    expect(account.name, 'Main');
    expect(account.currency, 'KGS');
  });

  test('parses transaction model and income flag', () {
    final transaction = TransactionModel.fromJson(<String, dynamic>{
      'id': 1,
      'title': 'Зарплата',
      'counterparty': 'Tech Corp',
      'amount': 23000,
      'category': 'Поступления',
      'iconKey': 'income',
      'type': 'INCOME',
      'status': 'COMPLETED',
      'accountName': 'Main',
      'occurredAt': '2026-03-12T09:05:00',
    });

    expect(transaction.isIncome, isTrue);
    expect(transaction.occurredAt.year, 2026);
  });

  test('parses dashboard and analysis models', () {
    final dashboard = AiDashboardModel.fromJson(<String, dynamic>{
      'currentBalance': 15000,
      'savingsBalance': 50000,
      'minimumProjectedBalance': -10000,
      'horizonDays': 10,
      'points': <Map<String, dynamic>>[
        <String, dynamic>{
          'dayOffset': 0,
          'isoDate': '2026-03-12',
          'label': '12 мар',
          'balance': 15000,
        },
      ],
      'scheduledPayments': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'accountId': 1,
          'accountName': 'Main',
          'title': 'Аренда',
          'counterparty': 'Landlord',
          'category': 'Аренда',
          'iconKey': 'home',
          'amount': 25000,
          'dueDate': '2026-03-16',
          'status': 'SCHEDULED',
        },
      ],
    });
    final analysis = AiAnalysisModel.fromJson(<String, dynamic>{
      'hasAlert': true,
      'message': 'Перевести 10000 KGS',
      'actionToken': 'token-1',
    });
    final execution = AiExecutionModel.fromJson(<String, dynamic>{
      'success': true,
      'message': 'Готово',
      'currentBalance': 25000,
      'savingsBalance': 40000,
    });

    expect(dashboard.points.single.balance, 15000);
    expect(dashboard.scheduledPayments.single.title, 'Аренда');
    expect(dashboard.scheduledPayments.single.accountName, 'Main');
    expect(analysis.hasAlert, isTrue);
    expect(execution.success, isTrue);
  });

  test('parses transfer result model', () {
    final transfer = TransferResultModel.fromJson(<String, dynamic>{
      'message': 'Перевод выполнен.',
      'fromAccount': <String, dynamic>{
        'id': 1,
        'name': 'Main',
        'type': 'MAIN',
        'balance': 13000,
        'currency': 'KGS',
      },
      'toAccount': <String, dynamic>{
        'id': 2,
        'name': 'Savings',
        'type': 'SAVINGS',
        'balance': 52000,
        'currency': 'KGS',
      },
      'recipientType': 'USER',
      'recipientName': 'Aigerim',
      'amount': 2000,
    });

    expect(transfer.message, 'Перевод выполнен.');
    expect(transfer.toAccount?.name, 'Savings');
    expect(transfer.recipientType, 'USER');
    expect(transfer.amount, 2000);
  });
}
