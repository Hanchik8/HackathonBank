import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnalysisInsightCard extends StatelessWidget {
  const AnalysisInsightCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final displaySubtitle = subtitle == 'Счет сбережений'
        ? 'Накопительный депозит'
        : subtitle;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displaySubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
