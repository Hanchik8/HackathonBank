class BalanceSuggestionModel {
  const BalanceSuggestionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.actionToken,
  });

  final String id;
  final String title;
  final String description;
  final String actionToken;

  factory BalanceSuggestionModel.fromJson(Map<String, dynamic> json) {
    return BalanceSuggestionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      actionToken: json['actionToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'actionToken': actionToken,
    };
  }
}

class AiAnalysisModel {
  const AiAnalysisModel({
    required this.hasAlert,
    required this.message,
    required this.actionToken,
    this.suggestions = const <BalanceSuggestionModel>[],
  });

  final bool hasAlert;
  final String message;
  final String? actionToken;
  final List<BalanceSuggestionModel> suggestions;

  factory AiAnalysisModel.fromJson(Map<String, dynamic> json) {
    return AiAnalysisModel(
      hasAlert: json['hasAlert'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      actionToken: json['actionToken'] as String?,
      suggestions: (json['suggestions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => BalanceSuggestionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasAlert': hasAlert,
      'message': message,
      'actionToken': actionToken,
      'suggestions': suggestions
          .map((suggestion) => suggestion.toJson())
          .toList(growable: false),
    };
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
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'success': success,
      'message': message,
      'currentBalance': currentBalance,
      'savingsBalance': savingsBalance,
    };
  }
}
