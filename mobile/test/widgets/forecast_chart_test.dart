import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/widgets/forecast_chart.dart';

void main() {
  testWidgets('renders unique future date labels on chart axis beyond 10 days', (
    WidgetTester tester,
  ) async {
    final baseDate = DateTime(2026, 3, 12);
    final points = List<ForecastPointModel>.generate(
      18,
      (int index) => ForecastPointModel(
        dayOffset: index,
        isoDate: baseDate.add(Duration(days: index)).toIso8601String(),
        label: '${12 + index} мар.',
        balance: 15000 - (index * 700),
      ),
    );
    final dashboard = AiDashboardModel(
      currentBalance: 15000,
      savingsBalance: 50000,
      minimumProjectedBalance: 3100,
      horizonDays: 17,
      points: points,
      scheduledPayments: const <ScheduledPaymentModel>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: ForecastChart(dashboard: dashboard),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));

    expect(chart.data.minX, 0);
    expect(chart.data.maxX, 17);
    expect(find.text('12 мар.'), findsOneWidget);
  });
}
