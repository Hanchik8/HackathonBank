import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class AnalysisCategoryRow extends StatelessWidget {
  const AnalysisCategoryRow({
    super.key,
    required this.color,
    required this.title,
    required this.amount,
    this.highlight = false,
  });

  final Color color;
  final String title;
  final double amount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            SomFormatter.amount(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.accent : Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.secondaryText,
          ),
        ],
      ),
    );
  }
}
