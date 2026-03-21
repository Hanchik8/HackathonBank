class SaveSuggestionModel {
  const SaveSuggestionModel({
    required this.amount,
    required this.reason,
    required this.safetyReserve,
    this.currentBalance = 0.0,
    this.scheduledOutflow = 0.0,
    this.smartListReserve = 0.0,
    this.freeAmount = 0.0,
  });

  final double amount;
  final String reason;
  final double safetyReserve;
  final double currentBalance;
  final double scheduledOutflow;
  final double smartListReserve;
  final double freeAmount;

  factory SaveSuggestionModel.fromJson(Map<String, dynamic> json) {
    return SaveSuggestionModel(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      safetyReserve: (json['safetyReserve'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      scheduledOutflow: (json['scheduledOutflow'] as num?)?.toDouble() ?? 0.0,
      smartListReserve: (json['smartListReserve'] as num?)?.toDouble() ?? 0.0,
      freeAmount: (json['freeAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'amount': amount,
      'reason': reason,
      'safetyReserve': safetyReserve,
      'currentBalance': currentBalance,
      'scheduledOutflow': scheduledOutflow,
      'smartListReserve': smartListReserve,
      'freeAmount': freeAmount,
    };
  }
}
