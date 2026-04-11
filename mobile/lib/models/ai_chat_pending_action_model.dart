class AiChatPendingActionModel {
  const AiChatPendingActionModel({
    required this.type,
    required this.token,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.description,
  });

  final String type;
  final String token;
  final String? categoryId;
  final String? categoryName;
  final String title;
  final String description;

  factory AiChatPendingActionModel.fromJson(Map<String, dynamic> json) {
    return AiChatPendingActionModel(
      type: json['type'] as String? ?? '',
      token: json['token'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}
