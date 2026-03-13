class AiAnalysisModel {
  const AiAnalysisModel({
    required this.hasAlert,
    required this.message,
    required this.actionToken,
  });

  final bool hasAlert;
  final String message;
  final String? actionToken;

  factory AiAnalysisModel.fromJson(Map<String, dynamic> json) {
    return AiAnalysisModel(
      hasAlert: json['hasAlert'] as bool,
      message: json['message'] as String,
      actionToken: json['actionToken'] as String?,
    );
  }
}

class AiExecutionModel {
  const AiExecutionModel({
    required this.success,
    required this.message,
    required this.currentBalance,
    required this.savingsBalance,
  });

  final bool success;
  final String message;
  final double currentBalance;
  final double savingsBalance;

  factory AiExecutionModel.fromJson(Map<String, dynamic> json) {
    return AiExecutionModel(
      success: json['success'] as bool,
      message: json['message'] as String,
      currentBalance: (json['currentBalance'] as num).toDouble(),
      savingsBalance: (json['savingsBalance'] as num).toDouble(),
    );
  }
}
