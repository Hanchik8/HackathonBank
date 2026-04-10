import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';

void main() {
  group('DetailedAnalyticsScreen', () {
    testWidgets('renders title and back button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DetailedAnalyticsScreen(transactions: [])),
      );

      expect(find.byType(DetailedAnalyticsScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('uses backend balance forecast when points are provided', (
      tester,
    ) async {
      final points = List<ForecastPointModel>.generate(
        5,
        (i) => ForecastPointModel(
          dayOffset: i,
          isoDate: '2026-04-0${i + 1}',
          label: '0${i + 1} апр.',
          balance: 10000.0 - i * 500,
          projectedIncome: i == 0 ? 24000 : 0,
          projectedExpense: i == 1 ? 1200 : 800,
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
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();

      final charts = tester.allWidgets.whereType<LineChart>().toList();
      final forecastChart = charts.last;

      expect(forecastChart.data.lineBarsData, hasLength(1));
      expect(forecastChart.data.lineBarsData.single.spots.first.y, 10000.0);
      expect(forecastChart.data.maxX, 4.0);
    });

    testWidgets('uses backend mode even with a single point', (tester) async {
      final points = <ForecastPointModel>[
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
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();

      final charts = tester.allWidgets.whereType<LineChart>().toList();
      final forecastChart = charts.last;

      expect(forecastChart.data.lineBarsData, hasLength(1));
      expect(forecastChart.data.maxX, 0.0);
    });
  });
}
