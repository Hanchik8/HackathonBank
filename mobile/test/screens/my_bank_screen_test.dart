import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/account_model.dart';
import 'package:hackathon_bank_mobile/screens/my_bank_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('opens deposit by transferring from main account', (
    WidgetTester tester,
  ) async {
    const initialAccounts = <AccountModel>[
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
    ];
    final apiService = FakeBankApiService(
      accounts: initialAccounts,
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MyBankScreen(
          apiService: apiService,
          accounts: initialAccounts,
          onAccountsChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openDepositButton = find.widgetWithText(
      ElevatedButton,
      'Открыть депозит',
    );
    await tester.ensureVisible(openDepositButton);
    await tester.pumpAndSettle();
    await tester.tap(openDepositButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '3000');
    await tester.tap(find.text('Перевести в депозит'));
    await tester.pumpAndSettle();

    expect(apiService.internalTransferCalls, 1);
    expect(apiService.lastInternalTransfer?['fromAccountId'], 1);
    expect(apiService.lastInternalTransfer?['toAccountId'], 2);
    expect(find.text('Закрыть депозит'), findsOneWidget);
  });
}
