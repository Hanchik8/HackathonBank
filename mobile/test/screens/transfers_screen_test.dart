import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/smart_category_model.dart';
import 'package:hackathon_bank_mobile/screens/transfers_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('submits merchant transfer and refreshes data', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    var refreshCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TransfersScreen(
            apiService: apiService,
            refreshSignal: 0,
            onDataChanged: () => refreshCount += 1,
            preferredMode: TransferRecipientMode.merchant,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TransfersScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Globus');
    await tester.enterText(find.byType(TextField).at(1), '1250');
    await tester.enterText(find.byType(TextField).at(2), 'Покупка');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(apiService.externalTransferCalls, 1);
    expect(apiService.lastExternalTransfer?['recipientType'], 'MERCHANT');
    expect(apiService.lastExternalTransfer?['recipientName'], 'Globus');
    expect(apiService.lastExternalTransfer?['amount'], 1250.0);
    expect(refreshCount, 1);
    expect(find.textContaining('Aigerim'), findsOneWidget);
  });

  testWidgets('does not allow savings account as transfer source', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TransfersScreen(
            apiService: apiService,
            refreshSignal: 0,
            onDataChanged: () {},
            preferredMode: TransferRecipientMode.user,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('15,000.00 KGS'), findsWidgets);
    expect(find.textContaining('50,000.00 KGS'), findsNothing);
  });

  testWidgets('applies quick category from QR shortcut', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService(
      smartCategories: const <SmartCategory>[
        SmartCategory(
          id: 'smart-food',
          name: 'Еда',
          plannedMonthly: 12000,
          remaining: 9000,
          isFavorite: true,
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TransfersScreen(
            apiService: apiService,
            refreshSignal: 0,
            onDataChanged: () {},
            preferredMode: TransferRecipientMode.user,
            preferredSmartCategoryId: 'smart-food',
            quickCategorySignal: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Еда'), findsOneWidget);
  });
}
