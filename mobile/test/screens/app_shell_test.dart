import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/smart_category_model.dart';
import 'package:hackathon_bank_mobile/screens/app_shell.dart';
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
}
