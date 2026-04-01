import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/account_model.dart';
import 'package:hackathon_bank_mobile/models/scheduled_payment_model.dart';
import 'package:hackathon_bank_mobile/models/transaction_model.dart';
import 'package:hackathon_bank_mobile/services/api_client.dart';
import '../test_support/mock_data_provider.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  setUp(() {
    MockDataProvider.resetForTest();
  });

  test('createReminderScheduledPayment changes dashboard forecast', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    final before = MockDataProvider.computeDashboard(5);

    await MockDataProvider.createReminderScheduledPayment(
      accountId: 1,
      title: 'Коммуналка',
      counterparty: 'Utility',
      category: 'Коммунальные',
      amount: 5000,
      dueDate: DateTime.now().add(const Duration(days: 2)),
      isReminder: true,
    );

    final after = MockDataProvider.computeDashboard(5);
    final beforeDayTwo = before.points.firstWhere((point) => point.dayOffset == 2);
    final afterDayTwo = after.points.firstWhere((point) => point.dayOffset == 2);

    expect(after.scheduledPayments.length, before.scheduledPayments.length + 1);
    expect(afterDayTwo.balance, beforeDayTwo.balance - 5000);
  });

  test('createTransaction updates smart category remaining', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    final before = MockDataProvider.smartCategories.firstWhere(
      (category) => category.id == 'food',
    );

    await MockDataProvider.createTransaction(
      accountId: 1,
      title: 'Кофейня',
      counterparty: 'Coffee',
      amount: 900,
      type: 'QR_TRANSFER',
      category: 'Еда',
      iconKey: 'food',
      smartCategoryId: 'food',
    );

    final after = MockDataProvider.smartCategories.firstWhere(
      (category) => category.id == 'food',
    );

    expect(after.remaining, before.remaining - 900);
  });

  test('deleteSmartCategory removes category from smart list', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    expect(
      MockDataProvider.smartCategories.any((category) => category.id == 'food'),
      isTrue,
    );

    await MockDataProvider.deleteSmartCategory('food');

    expect(
      MockDataProvider.smartCategories.any((category) => category.id == 'food'),
      isFalse,
    );
  });

  test('setSmartListEnabled updates smart list state', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    await MockDataProvider.setSmartListEnabled(false);

    expect(MockDataProvider.smartListEnabled, isFalse);
  });

  test('setSmartCategoryFavorite persists favorite flag in smart list', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    final created = await MockDataProvider.createSmartCategory(
      name: 'Транспорт',
      plannedMonthly: 6000,
    );

    await MockDataProvider.setSmartCategoryFavorite(created.id, true);

    final updated = MockDataProvider.smartCategories.firstWhere(
      (category) => category.id == created.id,
    );
    expect(updated.isFavorite, isTrue);
  });

  test('setSmartCategoryFavorite rejects more than three favorites', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    final first = await MockDataProvider.createSmartCategory(
      name: 'Транспорт',
      plannedMonthly: 6000,
    );
    final second = await MockDataProvider.createSmartCategory(
      name: 'Дом',
      plannedMonthly: 8000,
    );
    final third = await MockDataProvider.createSmartCategory(
      name: 'Маркет',
      plannedMonthly: 4000,
    );
    final fourth = await MockDataProvider.createSmartCategory(
      name: 'Подарки',
      plannedMonthly: 5000,
    );

    await MockDataProvider.setSmartCategoryFavorite(first.id, true);
    await MockDataProvider.setSmartCategoryFavorite(second.id, true);
    await MockDataProvider.setSmartCategoryFavorite(third.id, true);

    expect(
      () => MockDataProvider.setSmartCategoryFavorite(fourth.id, true),
      throwsA(isA<ApiException>()),
    );
  });

  test('computeBalanceAdvice avoids duplicate postpone suggestions', () {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: sampleScheduledPayments(),
    );

    final analysis = MockDataProvider.computeBalanceAdvice(horizonDays: 10);
    final postponeSuggestions = analysis.suggestions
        .where((suggestion) => suggestion.actionToken.startsWith('POSTPONE'))
        .toList(growable: false);

    expect(postponeSuggestions, hasLength(1));
  });

  test('computeBalanceAdvice uses recurring income date for postpone target', () async {
    MockDataProvider.initDemoData(
      accounts: const <AccountModel>[
        AccountModel(
          id: 1,
          name: 'Main',
          type: 'MAIN',
          balance: 15000,
          currency: 'KGS',
        ),
        AccountModel(
          id: 2,
          name: 'Savings',
          type: 'SAVINGS',
          balance: 0,
          currency: 'KGS',
        ),
      ],
      transactions: <TransactionModel>[
        TransactionModel(
          id: 1,
          title: 'Зарплата',
          counterparty: 'Tech Corp',
          amount: 25000,
          category: 'Поступления',
          iconKey: 'income',
          type: 'INCOME',
          status: 'COMPLETED',
          accountName: 'Main',
          occurredAt: DateTime(2026, 1, 5, 10),
        ),
        TransactionModel(
          id: 2,
          title: 'Зарплата',
          counterparty: 'Tech Corp',
          amount: 25000,
          category: 'Поступления',
          iconKey: 'income',
          type: 'INCOME',
          status: 'COMPLETED',
          accountName: 'Main',
          occurredAt: DateTime(2026, 2, 5, 10),
        ),
        TransactionModel(
          id: 3,
          title: 'Зарплата',
          counterparty: 'Tech Corp',
          amount: 25000,
          category: 'Поступления',
          iconKey: 'income',
          type: 'INCOME',
          status: 'COMPLETED',
          accountName: 'Main',
          occurredAt: DateTime(2026, 3, 5, 10),
        ),
      ],
      scheduledPayments: <ScheduledPaymentModel>[
        ScheduledPaymentModel(
          id: 77,
          accountId: 1,
          accountName: 'Main',
          title: 'Подписка',
          counterparty: 'Service',
          category: 'Подписки',
          iconKey: 'subscription',
          amount: 20000,
          dueDate: DateTime(2026, 3, 18),
          status: 'SCHEDULED',
          isReminder: true,
        ),
      ],
    );
    await MockDataProvider.setEffectiveDate(DateTime(2026, 3, 15));

    final analysis = MockDataProvider.computeBalanceAdvice(horizonDays: 16);
    final postponeSuggestion = analysis.suggestions.firstWhere(
      (suggestion) => suggestion.actionToken.startsWith('POSTPONE:'),
    );

    expect(postponeSuggestion.actionToken, contains('2026-04-05'));
  });

  test('deleteScheduledPayment removes planned payment from mock state', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: sampleScheduledPayments(),
    );

    await MockDataProvider.deleteScheduledPayment(10);

    expect(
      MockDataProvider.scheduledPayments.any((payment) => payment.id == 10),
      isFalse,
    );
  });

  test('admin adjustment uses effective date for created transaction', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const <ScheduledPaymentModel>[],
    );
    await MockDataProvider.setEffectiveDate(DateTime(2026, 3, 15));

    final transaction = await MockDataProvider.adjustAccountBalance(
      accountId: 1,
      delta: 12000,
      title: 'Премия',
    );

    expect(transaction.amount, 12000);
    expect(transaction.occurredAt, DateTime(2026, 3, 15, 12));
  });
}
