import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/ai_chat_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';

import '../test_support/fake_bank_api_service.dart';

void main() {
  testWidgets('sends message and renders assistant reply', (
    WidgetTester tester,
  ) async {
    final apiService = FakeBankApiService();
    const message = 'Как безопасно откладывать деньги?';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: AiChatScreen(apiService: apiService),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), message);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(apiService.lastChatMessage, message);
    expect(apiService.lastChatHistory, isEmpty);
    expect(find.textContaining('Safe-to-Save'), findsOneWidget);
  });
}
