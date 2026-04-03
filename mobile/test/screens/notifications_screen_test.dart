import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/screens/notifications_screen.dart';
import 'package:hackathon_bank_mobile/theme/app_theme.dart';
import 'package:hackathon_bank_mobile/widgets/notification_tile.dart';

void main() {
  testWidgets('renders grouped notifications', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: NotificationsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NotificationTile), findsAtLeastNWidgets(3));
  });
}
