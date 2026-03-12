import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:hackathon_bank_mobile/widgets/transaction_tile.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('renders account label and formatted date', (
    WidgetTester tester,
  ) async {
    final transaction = sampleTransactions().first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: TransactionTile(transaction: transaction)),
      ),
    );

    expect(find.text('Продукты'), findsOneWidget);
    expect(find.textContaining('Main account'), findsOneWidget);
    expect(find.textContaining('12 Mar, 09:05'), findsOneWidget);
  });
}
