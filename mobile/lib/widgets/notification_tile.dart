import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAddToSmartList,
  });

  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onAddToSmartList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final palette = _paletteFor(notification.type);
    final amountLabel = _amountLabel(notification.amount);
    final hasAction = onAddToSmartList != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? AppTheme.surface : AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white10
                  : palette.color.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.color.withValues(alpha: 0.15),
                ),
                child: Icon(palette.icon, color: palette.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 5, left: 8),
                            decoration: BoxDecoration(
                              color: palette.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: theme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                    if (amountLabel != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          amountLabel,
                          textAlign: TextAlign.end,
                          style: theme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.color,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      AppDateFormatter.shortDateTime(notification.timestamp),
                      style: theme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    if (hasAction) ...<Widget>[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey<String>(
                            'notification-smart-list-${notification.id}',
                          ),
                          onPressed: onAddToSmartList,
                          child: const Text('\u0412 Smart List'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _amountLabel(double? amount) {
    if (amount == null) {
      return null;
    }
    if (amount > 0) {
      return '+${SomFormatter.amount(amount)}';
    }
    if (amount < 0) {
      return '-${SomFormatter.amount(amount.abs())}';
    }
    return SomFormatter.amount(amount);
  }

  _NotificationPalette _paletteFor(NotificationType type) {
    return switch (type) {
      NotificationType.credit => const _NotificationPalette(
        color: AppTheme.accent,
        icon: Icons.south_west_rounded,
      ),
      NotificationType.debit => const _NotificationPalette(
        color: AppTheme.coral,
        icon: Icons.north_east_rounded,
      ),
      NotificationType.warning => const _NotificationPalette(
        color: Color(0xFFFFB347),
        icon: Icons.warning_amber_rounded,
      ),
      NotificationType.system => const _NotificationPalette(
        color: AppTheme.blue,
        icon: Icons.notifications_active_rounded,
      ),
    };
  }
}

class _NotificationPalette {
  const _NotificationPalette({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
