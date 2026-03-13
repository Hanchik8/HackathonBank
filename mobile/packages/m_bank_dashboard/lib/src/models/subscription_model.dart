class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.status,
    this.nextChargeDate,
  });

  final String id;
  final String title;
  final double amount;
  final String currency;
  final String status;
  final DateTime? nextChargeDate;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? (json['merchant'] as String? ?? ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency:
          json['currency'] as String? ??
          (json['currencyCode'] as String? ?? ''),
      status: json['status'] as String? ?? 'UNKNOWN',
      nextChargeDate: json['nextChargeDate'] != null
          ? DateTime.tryParse(json['nextChargeDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'currency': currency,
      'status': status,
      'nextChargeDate': nextChargeDate?.toIso8601String(),
    };
  }
}
