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
}
