import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';
import 'package:m_bank_dashboard/src/widgets/admin_mode_sheet.dart';

void main() {
  testWidgets('shows current date label in admin mode sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AdminModeSheet(
            accounts: const <AccountModel>[
              AccountModel(
                id: 1,
                name: 'Main',
                type: 'MAIN',
                balance: 26111,
                currency: 'KGS',
              ),
            ],
            effectiveDate: DateTime(2026, 4, 1),
          ),
        ),
      ),
    );

    expect(find.textContaining('Текущая дата:'), findsOneWidget);
  });
}
