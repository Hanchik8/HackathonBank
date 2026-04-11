class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.title,
    required this.counterparty,
    required this.amount,
    required this.category,
    required this.iconKey,
    required this.type,
    required this.status,
    required this.accountName,
    required this.occurredAt,
    this.smartCategoryId,
    this.smartCategoryName,
  });

  final int id;
  final String title;
  final String counterparty;
  final double amount;
  final String category;
  final String iconKey;
  final String type;
  final String status;
  final String accountName;
  final DateTime occurredAt;
  final String? smartCategoryId;
  final String? smartCategoryName;

  bool get isIncome => amount >= 0;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      title: json['title'] as String,
      counterparty: json['counterparty'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      iconKey: json['iconKey'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      accountName: json['accountName'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      smartCategoryId: json['smartCategoryId']?.toString(),
      smartCategoryName: json['smartCategoryName'] as String?,
    );
  }
}
