import 'package:flutter_test/flutter_test.dart';
import 'package:m_bank_dashboard/src/models/ai_dashboard_model.dart';

void main() {
  group('AiDashboardModel', () {
    test('fromJson parses dashboard with points', () {
      final json = <String, dynamic>{
        'currentBalance': 15000.0,
        'savingsBalance': 50000.0,
        'minimumProjectedBalance': -5000.0,
        'horizonDays': 30,
        'points': <Map<String, dynamic>>[
          {
            'dayOffset': 0,
            'isoDate': '2026-03-15',
            'label': '15 мар.',
            'balance': 15000.0,
            'projectedIncome': 24000.0,
            'projectedExpense': 1200.0,
          },
          {
            'dayOffset': 1,
            'isoDate': '2026-03-16',
            'label': '16 мар.',
            'balance': 14000.0,
            'projectedIncome': 0.0,
            'projectedExpense': 1000.0,
          },
        ],
        'scheduledPayments': <Map<String, dynamic>>[],
      };

      final model = AiDashboardModel.fromJson(json);

      expect(model.currentBalance, 15000.0);
      expect(model.savingsBalance, 50000.0);
      expect(model.minimumProjectedBalance, -5000.0);
      expect(model.horizonDays, 30);
      expect(model.points, hasLength(2));
      expect(model.points.first.dayOffset, 0);
      expect(model.points.first.projectedIncome, 24000.0);
      expect(model.points.last.balance, 14000.0);
      expect(model.points.last.projectedExpense, 1000.0);
      expect(model.scheduledPayments, isEmpty);
    });

    test('copyWith replaces specified fields', () {
      final original = AiDashboardModel(
        currentBalance: 10000.0,
        savingsBalance: 5000.0,
        minimumProjectedBalance: -1000.0,
        horizonDays: 14,
        points: const [],
        scheduledPayments: const [],
      );

      final updated = original.copyWith(
        currentBalance: 20000.0,
        horizonDays: 30,
      );

      expect(updated.currentBalance, 20000.0);
      expect(updated.horizonDays, 30);
      expect(updated.savingsBalance, 5000.0);
      expect(updated.minimumProjectedBalance, -1000.0);
    });
  });

  group('ForecastPointModel', () {
    test('fromJson parses all fields', () {
      final json = <String, dynamic>{
        'dayOffset': 5,
        'isoDate': '2026-03-20',
        'label': '20 мар.',
        'balance': 8000.0,
        'projectedIncome': 500.0,
        'projectedExpense': 1200.0,
      };

      final model = ForecastPointModel.fromJson(json);

      expect(model.dayOffset, 5);
      expect(model.isoDate, '2026-03-20');
      expect(model.label, '20 мар.');
      expect(model.balance, 8000.0);
      expect(model.projectedIncome, 500.0);
      expect(model.projectedExpense, 1200.0);
    });

    test('fromJson handles integer balance and missing projected fields', () {
      final json = <String, dynamic>{
        'dayOffset': 0,
        'isoDate': '2026-03-15',
        'label': '15 мар.',
        'balance': 12000,
      };

      final model = ForecastPointModel.fromJson(json);

      expect(model.balance, 12000.0);
      expect(model.projectedIncome, 0.0);
      expect(model.projectedExpense, 0.0);
    });
  });
}
