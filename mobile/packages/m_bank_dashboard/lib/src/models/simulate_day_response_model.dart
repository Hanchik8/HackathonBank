class SimulateDayResponseModel {
  const SimulateDayResponseModel({
    required this.currentDate,
    required this.currentBalance,
    required this.savingsBalance,
    required this.savedAmount,
    required this.autoSaveExecuted,
    required this.notification,
  });

  final DateTime? currentDate;
  final double currentBalance;
  final double savingsBalance;
  final double savedAmount;
  final bool autoSaveExecuted;
  final String notification;

  factory SimulateDayResponseModel.fromJson(Map<String, dynamic> json) {
    return SimulateDayResponseModel(
      currentDate: json['currentDate'] == null
          ? null
          : DateTime.tryParse(json['currentDate'] as String? ?? ''),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
      autoSaveExecuted: json['autoSaveExecuted'] as bool? ?? false,
      notification: json['notification'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currentDate': currentDate?.toIso8601String(),
      'currentBalance': currentBalance,
      'savingsBalance': savingsBalance,
      'savedAmount': savedAmount,
      'autoSaveExecuted': autoSaveExecuted,
      'notification': notification,
    };
  }
}
