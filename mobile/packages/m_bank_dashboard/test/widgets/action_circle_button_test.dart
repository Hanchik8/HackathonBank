import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/src/widgets/action_circle_button.dart';

void main() {
  group('ActionCircleButton', () {
    testWidgets('renders icon when not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCircleButton(
              icon: Icons.add,
              onTap: () {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCircleButton(
              icon: Icons.add,
              onTap: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCircleButton(
              icon: Icons.add,
              onTap: () => tapped = true,
              isLoading: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionCircleButton));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionCircleButton(
              icon: Icons.send,
              onTap: () => tapped = true,
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionCircleButton));
      expect(tapped, isFalse);
    });
  });
}
