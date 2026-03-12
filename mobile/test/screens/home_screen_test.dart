import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/home_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

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
          body: HomeScreen(apiService: FakeBankApiService(), refreshSignal: 0),
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
}
