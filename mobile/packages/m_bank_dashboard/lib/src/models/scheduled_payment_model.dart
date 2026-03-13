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

  factory ScheduledPaymentModel.fromJson(Map<String, dynamic> json) {
    return ScheduledPaymentModel(
      id: json['id'] as int,
      accountId: json['accountId'] as int,
      accountName: json['accountName'] as String,
      title: json['title'] as String,
      counterparty: json['counterparty'] as String,
      category: json['category'] as String,
      iconKey: json['iconKey'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: json['status'] as String,
    );
  }
}
