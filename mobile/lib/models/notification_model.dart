enum NotificationType { credit, debit, system, warning }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.type,
    this.amount,
    this.transactionId,
    this.smartCategoryHint,
  });

  final String id;
  final String title;
  final String body;
  final double? amount;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final int? transactionId;
  final String? smartCategoryHint;

  bool get canAddToSmartList =>
      transactionId != null && (amount ?? 0) < 0 && type == NotificationType.debit;

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    double? amount,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
    int? transactionId,
    String? smartCategoryHint,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      transactionId: transactionId ?? this.transactionId,
      smartCategoryHint: smartCategoryHint ?? this.smartCategoryHint,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['isRead'] as bool? ?? false,
      type: _notificationTypeFromJson(json['type'] as String?),
      transactionId: json['transactionId'] as int?,
      smartCategoryHint: json['smartCategoryHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'type': type.name,
      'transactionId': transactionId,
      'smartCategoryHint': smartCategoryHint,
    };
  }

  static NotificationType _notificationTypeFromJson(String? value) {
    return NotificationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => NotificationType.system,
    );
  }
}
