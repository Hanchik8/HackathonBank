class ScheduledPaymentModel {
  const ScheduledPaymentModel({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.title,
    required this.counterparty,
    required this.category,
    required this.iconKey,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.isReminder = true,
  });

  final int id;
  final int accountId;
  final String accountName;
  final String title;
  final String counterparty;
  final String category;
  final String iconKey;
  final double amount;
  final DateTime dueDate;
  final String status;
  final bool isReminder;

  factory ScheduledPaymentModel.fromJson(Map<String, dynamic> json) {
    return ScheduledPaymentModel(
      id: json['id'] as int? ?? 0,
      accountId: json['accountId'] as int? ?? 0,
      accountName: json['accountName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      counterparty: json['counterparty'] as String? ?? '',
      category: json['category'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'SCHEDULED',
      isReminder: json['isReminder'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'title': title,
      'counterparty': counterparty,
      'category': category,
      'iconKey': iconKey,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'isReminder': isReminder,
    };
  }
}
