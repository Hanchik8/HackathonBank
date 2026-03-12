import 'account_model.dart';

class TransferResultModel {
  const TransferResultModel({
    required this.message,
    required this.fromAccount,
    this.toAccount,
    this.recipientType,
    this.recipientName,
    this.amount,
  });

  final String message;
  final AccountModel fromAccount;
  final AccountModel? toAccount;
  final String? recipientType;
  final String? recipientName;
  final double? amount;

  factory TransferResultModel.fromJson(Map<String, dynamic> json) {
    return TransferResultModel(
      message: json['message'] as String,
      fromAccount: AccountModel.fromJson(
        json['fromAccount'] as Map<String, dynamic>,
      ),
      toAccount: json['toAccount'] == null
          ? null
          : AccountModel.fromJson(json['toAccount'] as Map<String, dynamic>),
      recipientType: json['recipientType'] as String?,
      recipientName: json['recipientName'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }
}
