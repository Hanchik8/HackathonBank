import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';

void main() {
  group('DetailedAnalyticsScreen', () {
    testWidgets('renders title and back button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DetailedAnalyticsScreen(transactions: []),
        ),
      );

      expect(find.text('Подробная аналитика'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('uses backend forecast when points are provided',
        (tester) async {
      final points = List<ForecastPointModel>.generate(
        5,
        (i) => ForecastPointModel(
          dayOffset: i,
          isoDate: '2026-04-0${i + 1}',
          label: '0${i + 1} апр.',
          balance: 10000.0 - i * 500,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DetailedAnalyticsScreen(
            transactions: const [],
            backendForecastPoints: points,
          ),
        ),
      );

      final screen =
          tester.widget<DetailedAnalyticsScreen>(find.byType(DetailedAnalyticsScreen));
      expect(screen.backendForecastPoints, isNotNull);
      expect(screen.backendForecastPoints!.length, 5);
    });

    testWidgets('falls back to client regression when forecast has < 2 points',
        (tester) async {
      final points = [
        const ForecastPointModel(
          dayOffset: 0,
          isoDate: '2026-04-01',
          label: '01 апр.',
          balance: 10000.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DetailedAnalyticsScreen(
            transactions: const [],
            backendForecastPoints: points,
          ),
        ),
      );

      final screen =
          tester.widget<DetailedAnalyticsScreen>(find.byType(DetailedAnalyticsScreen));
      expect(screen.backendForecastPoints!.length, lessThan(2));
    });
  });
}
