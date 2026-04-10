import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/notifications_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:hackathon_bank_mobile/widgets/notification_tile.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('renders grouped notifications', (WidgetTester tester) async {
    final apiService = FakeBankApiService();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NotificationsScreen(
          apiService: apiService,
          transactions: sampleTransactions(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NotificationTile), findsAtLeastNWidgets(3));
  });

  testWidgets('adds expense notification to smart list', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NotificationsScreen(
          apiService: apiService,
          transactions: sampleTransactions(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionFinder = find.byKey(
      const ValueKey<String>('notification-smart-list-transaction-1'),
    );
    expect(actionFinder, findsOneWidget);

    await tester.tap(actionFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c'));
    await tester.pumpAndSettle();

    expect(apiService.createSmartCategoryFromTransactionCalls, 1);
    expect(
      apiService.lastSmartCategoryFromTransactionDraft?['transactionId'],
      1,
    );
  });
}
