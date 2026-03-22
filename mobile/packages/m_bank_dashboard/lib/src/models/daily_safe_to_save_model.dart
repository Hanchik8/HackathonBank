class DailySafeToSaveModel {
  const DailySafeToSaveModel({
    required this.enabled,
    required this.suggestedAmount,
    required this.safeBalance,
    required this.currentBalance,
    required this.requiredPayments,
    required this.lifeBuffer,
    required this.nextIncomeDate,
    required this.daysToNextIncome,
    required this.status,
  });

  final bool enabled;
  final double suggestedAmount;
  final double safeBalance;
  final double currentBalance;
  final double requiredPayments;
  final double lifeBuffer;
  final DateTime? nextIncomeDate;
  final int daysToNextIncome;
  final String status;

  factory DailySafeToSaveModel.fromJson(Map<String, dynamic> json) {
    return DailySafeToSaveModel(
      enabled: json['enabled'] as bool? ?? false,
      suggestedAmount: (json['suggestedAmount'] as num?)?.toDouble() ?? 0.0,
      safeBalance: (json['safeBalance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      requiredPayments: (json['requiredPayments'] as num?)?.toDouble() ?? 0.0,
      lifeBuffer: (json['lifeBuffer'] as num?)?.toDouble() ?? 0.0,
      nextIncomeDate: json['nextIncomeDate'] == null
          ? null
          : DateTime.tryParse(json['nextIncomeDate'] as String? ?? ''),
      daysToNextIncome: (json['daysToNextIncome'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'suggestedAmount': suggestedAmount,
      'safeBalance': safeBalance,
      'currentBalance': currentBalance,
      'requiredPayments': requiredPayments,
      'lifeBuffer': lifeBuffer,
      'nextIncomeDate': nextIncomeDate?.toIso8601String(),
      'daysToNextIncome': daysToNextIncome,
      'status': status,
    };
  }
}
