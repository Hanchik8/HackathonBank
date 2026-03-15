import 'package:flutter/material.dart';

import '../models/scheduled_payment_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class ScheduledPaymentTile extends StatelessWidget {
  const ScheduledPaymentTile({
    super.key,
    required this.payment,
    required this.referenceDate,
    this.onDelete,
    this.isDeleting = false,
  });

  final ScheduledPaymentModel payment;
  final DateTime referenceDate;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(payment.iconKey);
    final accent = _colorFor(payment.iconKey);
    final dueLabel = _dueLabel(payment.dueDate, referenceDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        payment.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: payment.status),
                    if (onDelete != null) ...<Widget>[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: isDeleting ? null : onDelete,
                        icon: isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        color: AppTheme.coral,
                        tooltip: 'Удалить',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${payment.counterparty} • ${_displayAccountName(payment.accountName)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${payment.category} • $dueLabel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      SomFormatter.amount(payment.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime dueDate, DateTime currentDate) {
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final days = dueDateOnly.difference(todayOnly).inDays;
    if (days <= 0) {
      return 'сегодня';
    }
    return 'через $days дн. • ${AppDateFormatter.shortDate(dueDate)}';
  }

  IconData _iconFor(String iconKey) {
    return switch (iconKey) {
      'home' => Icons.home_rounded,
      'subscription' => Icons.play_circle_fill_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'food' => Icons.restaurant_rounded,
      'transport' => Icons.directions_car_rounded,
      'utilities' => Icons.bolt_rounded,
      _ => Icons.event_note_rounded,
    };
  }

  Color _colorFor(String iconKey) {
    return switch (iconKey) {
      'home' => AppTheme.accent,
      'subscription' => AppTheme.blue,
      'shopping' => AppTheme.yellow,
      'food' => AppTheme.coral,
      'transport' => AppTheme.blue,
      'utilities' => AppTheme.yellow,
      _ => Colors.white70,
    };
  }

  String _displayAccountName(String name) {
    return switch (name) {
      'Main' => 'Основной счет',
      'Savings' => 'Накопительный депозит',
      _ => name,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'POSTPONED' => AppTheme.blue,
      'PAID' => AppTheme.accent,
      _ => AppTheme.yellow,
    };
    final label = switch (status) {
      'POSTPONED' => 'Перенесен',
      'PAID' => 'Оплачен',
      _ => 'Запланирован',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
