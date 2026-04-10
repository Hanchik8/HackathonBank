import '../models/notification_model.dart';
import '../models/transaction_model.dart';

List<NotificationModel> getMockNotifications({
  List<TransactionModel> transactions = const <TransactionModel>[],
}) {
  final sortedTransactions = transactions
      .where((transaction) => transaction.status == 'COMPLETED')
      .toList(growable: false)
    ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

  final transactionNotifications = sortedTransactions
      .take(5)
      .toList(growable: false)
      .asMap()
      .entries
      .map(
        (entry) => _fromTransaction(
          entry.value,
          isRead: entry.key > 1,
        ),
      )
      .toList(growable: true);

  final now = DateTime.now();
  transactionNotifications.addAll(<NotificationModel>[
    NotificationModel(
      id: 'safe-to-save-system',
      title: 'Safe-to-Save',
      body:
          'Алгоритм пересчитал безопасный остаток на сегодня и учел ближайшие платежи.',
      timestamp: DateTime(now.year, now.month, now.day - 1, 8, 10),
      isRead: false,
      type: NotificationType.system,
    ),
    NotificationModel(
      id: 'rent-warning',
      title: 'Предупреждение',
      body: 'Через 4 дня спишется аренда 25 000 KGS. Проверьте баланс заранее.',
      amount: -25000,
      timestamp: now.subtract(const Duration(days: 6, hours: 2)),
      isRead: false,
      type: NotificationType.warning,
    ),
  ]);

  transactionNotifications.sort(
    (left, right) => right.timestamp.compareTo(left.timestamp),
  );
  return transactionNotifications;
}

NotificationModel _fromTransaction(
  TransactionModel transaction, {
  required bool isRead,
}) {
  final isIncome = transaction.amount > 0;
  return NotificationModel(
    id: 'transaction-${transaction.id}',
    title: _titleFor(transaction),
    body: _bodyFor(transaction),
    amount: transaction.amount,
    timestamp: transaction.occurredAt,
    isRead: isRead,
    type: isIncome ? NotificationType.credit : NotificationType.debit,
    transactionId: isIncome ? null : transaction.id,
    smartCategoryHint: isIncome ? null : transaction.category,
  );
}

String _titleFor(TransactionModel transaction) {
  if (transaction.amount > 0) {
    return 'Пополнение';
  }
  return switch (transaction.type) {
    'QR_TRANSFER' => 'Оплата по QR',
    'TRANSFER' => 'Перевод',
    _ => 'Покупка',
  };
}

String _bodyFor(TransactionModel transaction) {
  final details = <String>[
    if (transaction.counterparty.isNotEmpty) transaction.counterparty,
    if (transaction.accountName.isNotEmpty) 'Счет: ${transaction.accountName}',
  ];
  return details.join('\n');
}
