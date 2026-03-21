import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/home_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:hackathon_bank_mobile/widgets/bank_card_preview.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('renders home screen with fetched data', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HomeScreen(
            apiService: FakeBankApiService(),
            refreshSignal: 0,
            onDataChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Азизхан'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Последние операции'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Поступления за март'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Последние операции'), findsOneWidget);
    expect(find.text('Продукты'), findsWidgets);
    expect(find.textContaining('Поступления за март'), findsOneWidget);
  });

  testWidgets('opens my bank screen from card preview and closes deposit', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    var dataChangedCalls = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HomeScreen(
            apiService: apiService,
            refreshSignal: 0,
            onDataChanged: () => dataChangedCalls += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BankCardPreview));
    await tester.pumpAndSettle();

    expect(find.text('Накопительный депозит'), findsOneWidget);
    final closeDepositButton = find.widgetWithText(
      ElevatedButton,
      'Закрыть депозит',
    );
    await tester.ensureVisible(closeDepositButton);
    await tester.pumpAndSettle();

    await tester.tap(closeDepositButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Открыть депозит'), findsOneWidget);
    expect(apiService.lastActionToken, 'CLOSE_DEPOSIT:2');
    expect(dataChangedCalls, 1);
  });
}
