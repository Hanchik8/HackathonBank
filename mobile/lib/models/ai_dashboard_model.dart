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
  });

  final int dayOffset;
  final String isoDate;
  final String label;
  final double balance;

  factory ForecastPointModel.fromJson(Map<String, dynamic> json) {
    return ForecastPointModel(
      dayOffset: json['dayOffset'] as int,
      isoDate: json['isoDate'] as String,
      label: json['label'] as String,
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class ScheduledPaymentModel {
  const ScheduledPaymentModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  final int id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String status;

  factory ScheduledPaymentModel.fromJson(Map<String, dynamic> json) {
    return ScheduledPaymentModel(
      id: json['id'] as int,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String,
    );
  }
}
