import 'scheduled_payment_model.dart';

class AiDashboardModel {
  const AiDashboardModel({
    required this.currentBalance,
    required this.savingsBalance,
    required this.minimumProjectedBalance,
    required this.horizonDays,
    required this.points,
    required this.scheduledPayments,
  });

  final double currentBalance;
  final double savingsBalance;
  final double minimumProjectedBalance;
  final int horizonDays;
  final List<ForecastPointModel> points;
  final List<ScheduledPaymentModel> scheduledPayments;

  AiDashboardModel copyWith({
    double? currentBalance,
    double? savingsBalance,
    double? minimumProjectedBalance,
    int? horizonDays,
    List<ForecastPointModel>? points,
    List<ScheduledPaymentModel>? scheduledPayments,
  }) {
    return AiDashboardModel(
      currentBalance: currentBalance ?? this.currentBalance,
      savingsBalance: savingsBalance ?? this.savingsBalance,
      minimumProjectedBalance:
          minimumProjectedBalance ?? this.minimumProjectedBalance,
      horizonDays: horizonDays ?? this.horizonDays,
      points: points ?? this.points,
      scheduledPayments: scheduledPayments ?? this.scheduledPayments,
    );
  }

  factory AiDashboardModel.fromJson(Map<String, dynamic> json) {
    return AiDashboardModel(
      currentBalance: (json['currentBalance'] as num).toDouble(),
      savingsBalance: (json['savingsBalance'] as num).toDouble(),
      minimumProjectedBalance: (json['minimumProjectedBalance'] as num)
          .toDouble(),
      horizonDays: json['horizonDays'] as int,
      points: (json['points'] as List<dynamic>)
          .map(
            (item) => ForecastPointModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      scheduledPayments: (json['scheduledPayments'] as List<dynamic>)
          .map(
            (item) =>
                ScheduledPaymentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ForecastPointModel {
  const ForecastPointModel({
    required this.dayOffset,
    required this.isoDate,
    required this.label,
    required this.balance,
    this.projectedIncome = 0,
    this.projectedExpense = 0,
  });

  final int dayOffset;
  final String isoDate;
  final String label;
  final double balance;
  final double projectedIncome;
  final double projectedExpense;

  factory ForecastPointModel.fromJson(Map<String, dynamic> json) {
    return ForecastPointModel(
      dayOffset: json['dayOffset'] as int,
      isoDate: json['isoDate'] as String,
      label: json['label'] as String,
      balance: (json['balance'] as num).toDouble(),
      projectedIncome: ((json['projectedIncome'] ?? 0) as num).toDouble(),
      projectedExpense: ((json['projectedExpense'] ?? 0) as num).toDouble(),
    );
  }
}
