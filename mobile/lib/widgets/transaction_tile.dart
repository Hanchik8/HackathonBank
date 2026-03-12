import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isIncome ? AppTheme.accent : Colors.white;
    final amountPrefix = transaction.isIncome ? '+' : '-';
    final subtitle =
        '${transaction.category} • $_accountLabel • ${AppDateFormatter.shortDateTime(transaction.occurredAt)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconData, color: _iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                if (transaction.status != 'COMPLETED') ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      transaction.status,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$amountPrefix${SomFormatter.amount(transaction.amount.abs())}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  String get _accountLabel {
    return switch (transaction.accountName) {
      'Main' => 'Main account',
      'Savings' => 'Savings',
      _ => transaction.accountName,
    };
  }

  IconData get _iconData {
    return switch (transaction.iconKey) {
      'food' => Icons.restaurant_rounded,
      'transport' => Icons.directions_car_rounded,
      'transfer' => Icons.person_rounded,
      'qr' => Icons.qr_code_rounded,
      'entertainment' => Icons.movie_creation_outlined,
      'subscription' => Icons.repeat_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'income' => Icons.south_west_rounded,
      'home' => Icons.home_work_rounded,
      'health' => Icons.local_pharmacy_rounded,
      'gift' => Icons.card_giftcard_rounded,
      _ => Icons.payments_rounded,
    };
  }

  Color get _iconColor {
    return switch (transaction.iconKey) {
      'food' => AppTheme.coral,
      'transport' => const Color(0xFF4DD0E1),
      'transfer' => AppTheme.accent,
      'qr' => AppTheme.blue,
      'entertainment' => const Color(0xFFFF8A65),
      'subscription' => const Color(0xFF81C784),
      'shopping' => AppTheme.yellow,
      'income' => AppTheme.accent,
      'home' => const Color(0xFF90CAF9),
      'health' => const Color(0xFFA5D6A7),
      'gift' => const Color(0xFFCE93D8),
      _ => Colors.white70,
    };
  }
}
