import 'package:flutter/material.dart';

import '../models/smart_category_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class SmartListCard extends StatelessWidget {
  const SmartListCard({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onToggleFavorite,
    required this.onDeleteCategory,
    this.deletingCategoryId,
    this.updatingFavoriteCategoryId,
  });

  final List<SmartCategory> categories;
  final VoidCallback onAddCategory;
  final ValueChanged<SmartCategory> onToggleFavorite;
  final ValueChanged<String> onDeleteCategory;
  final String? deletingCategoryId;
  final String? updatingFavoriteCategoryId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Smart List',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u041a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438 \u0441 \u043b\u0438\u043c\u0438\u0442\u043e\u043c, '
                      '\u0442\u0440\u0430\u0442\u0430\u043c\u0438 \u0438 \u043e\u0441\u0442\u0430\u0442\u043a\u043e\u043c \u0434\u043e '
                      '\u043a\u043e\u043d\u0446\u0430 \u043c\u0435\u0441\u044f\u0446\u0430.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u041e\u0442\u043c\u0435\u0442\u044c\u0442\u0435 \u0434\u043e 3 \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u044b\u0445 '
                      '\u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0439: \u043e\u043d\u0438 '
                      '\u043f\u043e\u044f\u0432\u044f\u0442\u0441\u044f \u043f\u0440\u0438 \u0434\u043e\u043b\u0433\u043e\u043c '
                      '\u043d\u0430\u0436\u0430\u0442\u0438\u0438 \u043d\u0430 QR.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '\u041f\u043e\u043a\u0430 \u043d\u0435\u0442 smart-\u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0439. '
                '\u0414\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u043b\u0438\u043c\u0438\u0442, '
                '\u0447\u0442\u043e\u0431\u044b \u043e\u0442\u0441\u043b\u0435\u0436\u0438\u0432\u0430\u0442\u044c '
                '\u043e\u0441\u0442\u0430\u0442\u043e\u043a \u0430\u0432\u0442\u043e\u043c\u0430\u0442\u0438\u0447\u0435\u0441\u043a\u0438.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Column(
              children: categories.map((category) {
                final spent = category.plannedMonthly - category.remaining;
                final normalizedSpent = spent < 0 ? 0.0 : spent;
                final progress = category.plannedMonthly <= 0
                    ? 0.0
                    : (normalizedSpent / category.plannedMonthly).clamp(0.0, 1.0);
                final isDeleting = deletingCategoryId == category.id;
                final isUpdatingFavorite =
                    updatingFavoriteCategoryId == category.id;
                final isOverBudget = category.remaining < 0;
                final balanceLabel = isOverBudget
                    ? '\u041f\u0435\u0440\u0435\u0440\u0430\u0441\u0445\u043e\u0434'
                    : '\u041e\u0441\u0442\u0430\u043b\u043e\u0441\u044c';
                final balanceColor = isOverBudget
                    ? AppTheme.coral
                    : AppTheme.accent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                category.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (isUpdatingFavorite)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                onPressed: () => onToggleFavorite(category),
                                icon: Icon(
                                  category.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                                color: category.isFavorite
                                    ? AppTheme.yellow
                                    : AppTheme.secondaryText,
                                tooltip:
                                    '\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u0430\u044f \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f',
                              ),
                            if (isDeleting)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                onPressed: () => onDeleteCategory(category.id),
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AppTheme.secondaryText,
                                tooltip:
                                    '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e',
                              ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  balanceLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.secondaryText,
                                      ),
                                ),
                                Text(
                                  SomFormatter.amount(category.remaining.abs()),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: balanceColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u041b\u0438\u043c\u0438\u0442: ${SomFormatter.amount(category.plannedMonthly)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u041f\u043e\u0442\u0440\u0430\u0447\u0435\u043d\u043e: ${SomFormatter.amount(normalizedSpent)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              balanceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}
