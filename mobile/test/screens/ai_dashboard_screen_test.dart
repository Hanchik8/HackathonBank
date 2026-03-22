import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/ai_dashboard_screen.dart';
import 'package:hackathon_bank_mobile/services/bank_api_dashboard_repository.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:m_bank_dashboard/src/widgets/action_circle_button.dart';
import 'package:m_bank_dashboard/src/widgets/transaction_capture_sheet.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('dashboard reloads ai analysis when time machine changes', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final expectedHorizon = DateTime(now.year, now.month + 1, 0)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final apiService = FakeBankApiService();
    final repository = BankApiDashboardRepository(apiService: apiService);
    var refreshCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AiDashboardScreen(
            repository: repository,
            refreshSignal: 0,
            onDataChanged: () => refreshCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiDashboardScreen), findsOneWidget);
    expect(apiService.dashboardRequests, <int>[expectedHorizon]);
    expect(apiService.analyzeRequests, <int>[expectedHorizon]);
    expect(refreshCount, 0);

    await tester.scrollUntilVisible(
      find.byType(Slider),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final initialSlider = tester.widget<Slider>(find.byType(Slider).first);
    initialSlider.onChanged?.call(4);
    await tester.pump();

    final updatedSlider = tester.widget<Slider>(find.byType(Slider).first);
    updatedSlider.onChangeEnd?.call(4);
    await tester.pumpAndSettle();

    expect(apiService.dashboardRequests.last, 4);
    expect(apiService.analyzeRequests.last, 4);
    expect(refreshCount, 0);
  });

  testWidgets('dashboard creates scheduled payment and refreshes data', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    final repository = BankApiDashboardRepository(apiService: apiService);
    var refreshCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AiDashboardScreen(
            repository: repository,
            refreshSignal: 0,
            onDataChanged: () => refreshCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_alert_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Страхование');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Страховая компания',
    );
    await tester.enterText(find.byType(TextField).at(2), '4200');

    await tester.scrollUntilVisible(
      find.byType(ElevatedButton).last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(apiService.createScheduledPaymentCalls, 1);
    expect(apiService.lastScheduledPaymentDraft?['title'], 'Страхование');
    expect(apiService.dashboardRequests.length, greaterThan(1));
    expect(refreshCount, 1);
  });

  testWidgets('dashboard creates loan and refreshes data immediately', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    final repository = BankApiDashboardRepository(apiService: apiService);
    var refreshCount = 0;

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AiDashboardScreen(
            repository: repository,
            refreshSignal: 0,
            onDataChanged: () => refreshCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_balance_wallet_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Bridge loan');
    await tester.enterText(find.byType(TextField).at(1), '12500');

    final createLoanButton = find.byType(ElevatedButton).last;
    await tester.scrollUntilVisible(
      createLoanButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(createLoanButton);
    await tester.pumpAndSettle();

    expect(apiService.createLoanCalls, 1);
    expect(apiService.lastLoanDraft?['title'], 'Bridge loan');
    expect(apiService.dashboardRequests.length, greaterThan(1));
    expect(refreshCount, 1);
  });

  testWidgets('transaction sheet hides category picker when smart list disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TransactionCaptureSheet(
            accounts: sampleAccounts(),
            smartCategories: sampleSmartCategories(),
            smartListEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
  });

  testWidgets('dashboard toggles auto save and advances one day per tap', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    final repository = BankApiDashboardRepository(apiService: apiService);

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AiDashboardScreen(
            repository: repository,
            refreshSignal: 0,
            onDataChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final autoSaveSwitch = tester
        .widgetList<Switch>(find.byType(Switch, skipOffstage: false))
        .last;
    autoSaveSwitch.onChanged?.call(true);
    await tester.pumpAndSettle();

    expect(apiService.lastAutoDailySaveEnabled, isTrue);

    final demoButton = tester
        .widgetList<ActionCircleButton>(
          find.byType(ActionCircleButton, skipOffstage: false),
        )
        .first;
    demoButton.onTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(apiService.simulateDayCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
