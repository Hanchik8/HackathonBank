import 'ai_chat_pending_action_model.dart';

class AiChatReplyModel {
  const AiChatReplyModel({
    required this.role,
    required this.content,
    this.pendingAction,
  });

  final String role;
  final String content;
  final AiChatPendingActionModel? pendingAction;

  String? operator [](String key) {
    return switch (key) {
      'role' => role,
      'content' => content,
      _ => null,
    };
  }

  factory AiChatReplyModel.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>? ?? const {};
    final pendingActionJson = json['pendingAction'] as Map<String, dynamic>?;
    return AiChatReplyModel(
      role: message['role'] as String? ?? 'assistant',
      content: message['content'] as String? ?? '',
      pendingAction: pendingActionJson == null
          ? null
          : AiChatPendingActionModel.fromJson(pendingActionJson),
    );
  }
}
