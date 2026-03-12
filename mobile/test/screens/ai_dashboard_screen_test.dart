import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/ai_dashboard_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('renders dashboard alert and executes suggested action', (
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
          body: AiDashboardScreen(
            apiService: apiService,
            refreshSignal: 0,
            onDataChanged: () => refreshCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Финансовый анализ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('AI решение'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('AI решение'), findsOneWidget);
    expect(find.text('Выполнить'), findsOneWidget);

    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(apiService.executeCalls, 1);
    expect(apiService.lastActionToken, 'action-1');
    expect(refreshCount, 1);
    expect(find.text('Перевод выполнен.'), findsOneWidget);
  });
}
