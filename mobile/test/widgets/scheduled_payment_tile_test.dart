import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';
import 'package:m_bank_dashboard/src/widgets/scheduled_payment_tile.dart';

void main() {
  testWidgets('uses provided reference date for due label', (
    WidgetTester tester,
  ) async {
    final payment = ScheduledPaymentModel(
      id: 1,
      accountId: 1,
      accountName: 'Main',
      title: 'Покупки',
      counterparty: '123',
      category: 'Покупки',
      iconKey: 'shopping',
      amount: 11111,
      dueDate: DateTime(2026, 4, 3),
      status: 'POSTPONED',
      isReminder: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ScheduledPaymentTile(
            payment: payment,
            referenceDate: DateTime(2026, 4, 1),
          ),
        ),
      ),
    );

    expect(find.textContaining('через 2 дн.'), findsOneWidget);
    expect(find.textContaining('03'), findsOneWidget);
  });
}
