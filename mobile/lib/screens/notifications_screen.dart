import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/mock_notifications.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key, List<NotificationModel>? notifications})
    : notifications = List<NotificationModel>.from(
        notifications ?? getMockNotifications(),
      )..sort((left, right) => right.timestamp.compareTo(left.timestamp));

  final List<NotificationModel> notifications;

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
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
              ...group.items.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NotificationTile(notification: notification),
                ),
              ),
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

    for (final notification in notifications) {
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
        _NotificationGroup(label: 'Сегодня', items: todayItems),
      if (yesterdayItems.isNotEmpty)
        _NotificationGroup(label: 'Вчера', items: yesterdayItems),
      if (earlierItems.isNotEmpty)
        _NotificationGroup(label: 'Ранее', items: earlierItems),
    ];
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<NotificationModel> items;
}
