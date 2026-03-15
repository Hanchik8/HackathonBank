import 'package:flutter/material.dart';

import '../models/ai_analysis_model.dart';
import '../theme/app_theme.dart';

class BalanceAdviceCard extends StatelessWidget {
  const BalanceAdviceCard({
    super.key,
    required this.analysis,
    required this.isLoading,
    required this.onExecute,
  });

  final AiAnalysisModel analysis;
  final bool isLoading;
  final Future<void> Function(BalanceSuggestionModel suggestion) onExecute;

  @override
  Widget build(BuildContext context) {
    final suggestions = analysis.suggestions.isEmpty
        ? _fallbackSuggestions(analysis)
        : analysis.suggestions;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x1400D26A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x3300D26A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Балансовые рекомендации',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SuggestionTile(
                suggestion: suggestion,
                isLoading: isLoading,
                onTap: () => _openSuggestionDialog(context, suggestion),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSuggestionDialog(
    BuildContext context,
    BalanceSuggestionModel suggestion,
  ) async {
    final shouldExecute = await showDialog<bool>(
      context: context,
      builder: (context) {
        final needsExtraWarning = suggestion.actionToken.startsWith(
          'CLOSE_DEPOSIT',
        );
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(suggestion.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                suggestion.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),
              if (needsExtraWarning) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Подтвердите действие: накопительный депозит будет закрыт, а деньги сразу перейдут на основной счет.',
                  ),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(true),
              child: const Text('Выполнить'),
            ),
          ],
        );
      },
    );

    if (shouldExecute == true) {
      await onExecute(suggestion);
    }
  }

  List<BalanceSuggestionModel> _fallbackSuggestions(AiAnalysisModel analysis) {
    final token = analysis.actionToken;
    if (token == null || token.isEmpty) {
      return const <BalanceSuggestionModel>[];
    }
    return <BalanceSuggestionModel>[
      BalanceSuggestionModel(
        id: 'legacy',
        title: 'Рекомендация',
        description: analysis.message,
        actionToken: token,
      ),
    ];
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.isLoading,
    required this.onTap,
  });

  final BalanceSuggestionModel suggestion;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1900D26A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: Color(0x3300D26A)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Подробнее / Выполнить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
