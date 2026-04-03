import 'package:flutter/material.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';

import '../models/notification_model.dart';
import '../services/bank_api_service.dart';
import '../services/mock_notifications.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiService,
    this.transactions = const <TransactionModel>[],
    this.notifications,
    this.onSmartListChanged,
  });

  final BankApiService apiService;
  final List<TransactionModel> transactions;
  final List<NotificationModel>? notifications;
  final VoidCallback? onSmartListChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationModel> _notifications;
  String? _savingNotificationId;

  @override
  void initState() {
    super.initState();
    _notifications = List<NotificationModel>.from(
      widget.notifications ?? getMockNotifications(transactions: widget.transactions),
    )..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  }

  Future<void> _openSmartList(NotificationModel notification) async {
    if (!notification.canAddToSmartList ||
        notification.transactionId == null ||
        _savingNotificationId != null) {
      return;
    }

    final draft = await showModalBottomSheet<SmartCategoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartCategoryFormSheet(
        initialName: notification.smartCategoryHint ?? notification.title,
        initialPlannedMonthly: notification.amount?.abs(),
        title: '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0440\u0430\u0441\u0445\u043e\u0434 \u0432 Smart List',
        submitLabel: '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c',
      ),
    );

    if (draft == null) {
      return;
    }

    setState(() {
      _savingNotificationId = notification.id;
    });

    try {
      await widget.apiService.createSmartCategoryFromTransaction(
        transactionId: notification.transactionId!,
        name: draft.name,
        plannedMonthly: draft.plannedMonthly,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id != notification.id) {
            return item;
          }
          return item.copyWith(isRead: true);
        }).toList(growable: false);
      });
      widget.onSmartListChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u0420\u0430\u0441\u0445\u043e\u0434 "${draft.name}" \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d \u0432 Smart List.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _savingNotificationId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    return Scaffold(
      appBar: AppBar(title: const Text('\u0423\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u044f')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 22),
        itemBuilder: (context, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
              ...group.items.map((notification) {
                final canAddToSmartList =
                    notification.canAddToSmartList &&
                    _savingNotificationId != notification.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NotificationTile(
                    notification: notification,
                    onTap: notification.canAddToSmartList
                        ? () => _openSmartList(notification)
                        : null,
                    onAddToSmartList: canAddToSmartList
                        ? () => _openSmartList(notification)
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  List<_NotificationGroup> _buildGroups() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationModel>[];
    final yesterdayItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final notification in _notifications) {
      final day = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );
      if (day == today) {
        todayItems.add(notification);
      } else if (day == yesterday) {
        yesterdayItems.add(notification);
      } else {
        earlierItems.add(notification);
      }
    }

    return <_NotificationGroup>[
      if (todayItems.isNotEmpty)
        _NotificationGroup(
          label: '\u0421\u0435\u0433\u043e\u0434\u043d\u044f',
          items: todayItems,
        ),
      if (yesterdayItems.isNotEmpty)
        _NotificationGroup(
          label: '\u0412\u0447\u0435\u0440\u0430',
          items: yesterdayItems,
        ),
      if (earlierItems.isNotEmpty)
        _NotificationGroup(
          label: '\u0420\u0430\u043d\u0435\u0435',
          items: earlierItems,
        ),
    ];
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<NotificationModel> items;
}
