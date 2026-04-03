import '../models/notification_model.dart';

List<NotificationModel> getMockNotifications() {
  final now = DateTime.now();

  return <NotificationModel>[
    NotificationModel(
      id: 'notification-credit-salary',
      title: 'Пополнение',
      body: 'Зарплата от Tech Corp поступила на основной счет.',
      amount: 120000,
      timestamp: DateTime(now.year, now.month, now.day, 9, 12),
      isRead: false,
      type: NotificationType.credit,
    ),
    NotificationModel(
      id: 'notification-debit-market',
      title: 'Покупка',
      body: 'VTS GTS CANTIN STOLOVAYA, Bishkek. Карта *4477.',
      amount: -135,
      timestamp: DateTime(now.year, now.month, now.day, 12, 36),
      isRead: false,
      type: NotificationType.debit,
    ),
    NotificationModel(
      id: 'notification-debit-qr',
      title: 'Оплата по QR',
      body: 'Оплата по QR Тулпар. Карта *4477.',
      amount: -17,
      timestamp: DateTime(now.year, now.month, now.day, 17, 23),
      isRead: true,
      type: NotificationType.debit,
    ),
    NotificationModel(
      id: 'notification-system-safe-save',
      title: 'Safe-to-Save',
      body:
          'Автоматический перевод в накопительный депозит не выполнен: сегодня резерв важнее накопления.',
      amount: null,
      timestamp: DateTime(now.year, now.month, now.day - 1, 8, 10),
      isRead: false,
      type: NotificationType.system,
    ),
    NotificationModel(
      id: 'notification-credit-refund',
      title: 'Возврат',
      body: 'Возврат после корректировки платежа. Карта *4477.',
      amount: 630,
      timestamp: DateTime(now.year, now.month, now.day - 1, 22, 47),
      isRead: true,
      type: NotificationType.credit,
    ),
    NotificationModel(
      id: 'notification-warning-rent',
      title: 'Предупреждение',
      body: 'Через 4 дня спишется аренда 25 000 KGS. Проверьте баланс.',
      amount: -25000,
      timestamp: DateTime(now.year, now.month, now.day - 3, 19, 20),
      isRead: false,
      type: NotificationType.warning,
    ),
    NotificationModel(
      id: 'notification-debit-transfer',
      title: 'Перевод',
      body: 'Перевод 500 KGS на карту Visa. Карта *4477.',
      amount: -500,
      timestamp: now.subtract(const Duration(days: 7, hours: 2)),
      isRead: true,
      type: NotificationType.debit,
    ),
  ]..sort((left, right) => right.timestamp.compareTo(left.timestamp));
}
