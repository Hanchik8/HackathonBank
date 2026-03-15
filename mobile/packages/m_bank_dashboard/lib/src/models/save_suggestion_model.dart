class SaveSuggestionModel {
  const SaveSuggestionModel({
    required this.amount,
    required this.reason,
    required this.safetyReserve,
  });

  final double amount;
  final String reason;
  final double safetyReserve;

  factory SaveSuggestionModel.fromJson(Map<String, dynamic> json) {
    return SaveSuggestionModel(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      safetyReserve: (json['safetyReserve'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'amount': amount,
      'reason': reason,
      'safetyReserve': safetyReserve,
    };
  }
}
