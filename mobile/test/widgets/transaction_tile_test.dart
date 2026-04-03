import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/app_date_formatter.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:hackathon_bank_mobile/widgets/transaction_tile.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('renders transaction title and formatted date', (
    WidgetTester tester,
  ) async {
    final transaction = sampleTransactions().first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: TransactionTile(transaction: transaction)),
      ),
    );

    expect(find.text(transaction.title), findsOneWidget);
    expect(
      find.textContaining(AppDateFormatter.shortDateTime(transaction.occurredAt)),
      findsOneWidget,
    );
  });
}
