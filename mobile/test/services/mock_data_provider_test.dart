import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/services/mock_data_provider.dart';

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

  test('setSmartListEnabled toggles suggestion reserve source', () async {
    MockDataProvider.initDemoData(
      accounts: sampleAccounts(),
      transactions: sampleTransactions(),
      scheduledPayments: const [],
    );

    final before = MockDataProvider.computeSuggestedSave();

    await MockDataProvider.setSmartListEnabled(false);

    final after = MockDataProvider.computeSuggestedSave();

    expect(MockDataProvider.smartListEnabled, isFalse);
    expect(after.amount, greaterThanOrEqualTo(before.amount));
  });
}
