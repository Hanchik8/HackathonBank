import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/models/scheduled_payment_model.dart';
import 'package:hackathon_bank_mobile/models/smart_category_model.dart';
import 'package:hackathon_bank_mobile/screens/app_shell.dart';
import 'package:hackathon_bank_mobile/screens/ai_chat_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('shows favorite categories on QR long press', (
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
        SmartCategory(
          id: 'smart-taxi',
          name: 'Такси',
          plannedMonthly: 7000,
          remaining: 5500,
          isFavorite: true,
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: AppShell(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    final qrFinder = find.byIcon(Icons.qr_code_scanner_rounded);
    expect(qrFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(qrFinder));
    await tester.pump(const Duration(milliseconds: 650));

    expect(find.text('Еда'), findsOneWidget);
    expect(find.text('Такси'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('shows due payment banner and allows dismiss', (
    WidgetTester tester,
  ) async {
    final today = DateTime.now();
    final apiService = FakeBankApiService(
      dashboard: sampleDashboard(<ScheduledPaymentModel>[
        ScheduledPaymentModel(
          id: 77,
          accountId: 1,
          accountName: 'Main',
          title: '\u0410\u0440\u0435\u043d\u0434\u0430',
          counterparty: 'Landlord',
          category: '\u0410\u0440\u0435\u043d\u0434\u0430',
          iconKey: 'home',
          amount: 25000,
          dueDate: DateTime(today.year, today.month, today.day),
          status: 'SCHEDULED',
          isReminder: true,
        ),
      ]),
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: AppShell(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('due-payment-banner')), findsOneWidget);
    expect(find.text('\u041a \u0430\u043d\u0430\u043b\u0438\u0437\u0443'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('due-payment-banner-dismiss')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('due-payment-banner')), findsNothing);
  });

  testWidgets('opens analysis tab from due payment banner', (
    WidgetTester tester,
  ) async {
    final today = DateTime.now();
    final apiService = FakeBankApiService(
      dashboard: sampleDashboard(<ScheduledPaymentModel>[
        ScheduledPaymentModel(
          id: 88,
          accountId: 1,
          accountName: 'Main',
          title: '\u0414\u043e\u043b\u0433',
          counterparty: 'Friend',
          category: '\u041f\u0435\u0440\u0435\u0432\u043e\u0434\u044b',
          iconKey: 'shopping',
          amount: 10000,
          dueDate: DateTime(today.year, today.month, today.day),
          status: 'SCHEDULED',
          isReminder: true,
        ),
      ]),
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: AppShell(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('due-payment-banner-open-analysis')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
  });

  testWidgets('opens ai chat from home fab', (WidgetTester tester) async {
    final apiService = FakeBankApiService();

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: AppShell(apiService: apiService),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.smart_toy_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AiChatScreen), findsOneWidget);
  });
}
