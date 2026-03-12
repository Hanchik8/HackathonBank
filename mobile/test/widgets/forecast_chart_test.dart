import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/widgets/forecast_chart.dart';

void main() {
  testWidgets('renders unique future date labels on chart axis', (
    WidgetTester tester,
  ) async {
    final dashboard = AiDashboardModel(
      currentBalance: 15000,
      savingsBalance: 50000,
      minimumProjectedBalance: -10000,
      horizonDays: 10,
      points: const <ForecastPointModel>[
        ForecastPointModel(
          dayOffset: 0,
          isoDate: '2026-03-12',
          label: '12 мар.',
          balance: 15000,
        ),
        ForecastPointModel(
          dayOffset: 1,
          isoDate: '2026-03-13',
          label: '13 мар.',
          balance: 14000,
        ),
        ForecastPointModel(
          dayOffset: 2,
          isoDate: '2026-03-14',
          label: '14 мар.',
          balance: 13000,
        ),
        ForecastPointModel(
          dayOffset: 3,
          isoDate: '2026-03-15',
          label: '15 мар.',
          balance: 12000,
        ),
        ForecastPointModel(
          dayOffset: 4,
          isoDate: '2026-03-16',
          label: '16 мар.',
          balance: 11000,
        ),
        ForecastPointModel(
          dayOffset: 5,
          isoDate: '2026-03-17',
          label: '17 мар.',
          balance: 10000,
        ),
        ForecastPointModel(
          dayOffset: 6,
          isoDate: '2026-03-18',
          label: '18 мар.',
          balance: 9000,
        ),
        ForecastPointModel(
          dayOffset: 7,
          isoDate: '2026-03-19',
          label: '19 мар.',
          balance: 8000,
        ),
        ForecastPointModel(
          dayOffset: 8,
          isoDate: '2026-03-20',
          label: '20 мар.',
          balance: 7000,
        ),
        ForecastPointModel(
          dayOffset: 9,
          isoDate: '2026-03-21',
          label: '21 мар.',
          balance: 6000,
        ),
        ForecastPointModel(
          dayOffset: 10,
          isoDate: '2026-03-22',
          label: '22 мар.',
          balance: 5000,
        ),
      ],
      scheduledPayments: const <ScheduledPaymentModel>[],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, height: 220, child: Placeholder()),
        ),
      ),
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

    expect(find.text('12 мар.'), findsOneWidget);
    expect(find.text('14 мар.'), findsOneWidget);
    expect(find.text('16 мар.'), findsOneWidget);
    expect(find.text('18 мар.'), findsOneWidget);
    expect(find.text('20 мар.'), findsOneWidget);
    expect(find.text('22 мар.'), findsOneWidget);
  });
}
