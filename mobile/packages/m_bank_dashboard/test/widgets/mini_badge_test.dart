import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/src/widgets/mini_badge.dart';

void main() {
  group('MiniBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MiniBadge(label: 'NEW', color: Colors.green),
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('applies color to container decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MiniBadge(label: 'HOT', color: Colors.red),
          ),
        ),
      );

      expect(find.text('HOT'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
    });
  });
}
