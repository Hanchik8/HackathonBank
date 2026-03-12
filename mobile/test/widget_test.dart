import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/main.dart';

import 'test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('application shell renders navigation labels', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(HackathonBankApp(apiService: FakeBankApiService()));
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Анализ'), findsOneWidget);
    expect(find.text('Платежи'), findsOneWidget);
    expect(find.text('Еще'), findsOneWidget);

    await tester.tap(find.text('Анализ'));
    await tester.pumpAndSettle();

    expect(find.text('Финансовый анализ'), findsOneWidget);

    await tester.tap(find.text('Платежи'));
    await tester.pumpAndSettle();

    expect(find.text('Платежи'), findsWidgets);
  });
}
