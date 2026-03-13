class AccountModel {
  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
  });

  final int id;
  final String name;
  final String type;
  final double balance;
  final String currency;

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
