part of 'ai_dashboard_screen.dart';

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.dashboard,
    required this.scheduledPaymentCount,
    required this.sliderMax,
    required this.sliderValue,
    required this.offsetDays,
    required this.maxDays,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final AiDashboardModel dashboard;
  final int scheduledPaymentCount;
  final int sliderMax;
  final double sliderValue;
  final int offsetDays;
  final int maxDays;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

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
                      'Прогноз баланса',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      SomFormatter.amount(dashboard.minimumProjectedBalance),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: dashboard.minimumProjectedBalance < 0
                                ? Colors.white
                                : AppTheme.accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              MiniBadge(
                label: '$scheduledPaymentCount платежей',
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(height: 180, child: ForecastChart(dashboard: dashboard)),
          const SizedBox(height: 16),
          Text(
            'Машина времени',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Slider(
            min: 0,
            max: sliderMax.toDouble(),
            divisions: sliderMax,
            value: sliderValue,
            label: '$offsetDays дн.',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Text(
            'Горизонт до конца месяца: $maxDays дн.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '0 дн.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryText),
              ),
              Text(
                '$maxDays дн.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminModeCard extends StatelessWidget {
  const _AdminModeCard({
    required this.enabled,
    required this.effectiveDate,
    required this.isBusy,
    required this.onToggle,
    required this.onOpen,
  });

  final bool enabled;
  final DateTime effectiveDate;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: enabled
              ? AppTheme.accent.withValues(alpha: 0.25)
              : Colors.white10,
        ),
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
                      'Режим Админа',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      enabled
                          ? 'Текущая дата: ${AppDateFormatter.shortDate(effectiveDate)}. Можно откатиться в прошлое и вручную менять баланс, чтобы проверить аналитику дохода.'
                          : 'Включите режим, чтобы менять текущую дату и вручную добавлять или убирать деньги со счета.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: enabled,
                onChanged: isBusy ? null : (_) => onToggle(),
              ),
            ],
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onOpen,
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  isBusy ? 'Применение...' : 'Изменить дату и баланс',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailySafeToSaveCard extends StatelessWidget {
  const _DailySafeToSaveCard({
    required this.preview,
    required this.autoDailySaveEnabled,
    required this.isBusy,
    required this.onToggle,
  });

  final DailySafeToSaveModel preview;
  final bool autoDailySaveEnabled;
  final bool isBusy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final nextIncomeLabel = preview.nextIncomeDate == null
        ? 'Дата дохода пока не определена'
        : 'Следующий доход: ${AppDateFormatter.shortDate(preview.nextIncomeDate!)}';
    final statusText = _statusLabel(preview);

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
                      'Ежедневный Safe-to-Save',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: autoDailySaveEnabled,
                onChanged: isBusy ? null : onToggle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            preview.suggestedAmount > 0
                ? 'Сегодня можно отложить ${SomFormatter.amount(preview.suggestedAmount)}'
                : 'Сегодня безопасный перевод в накопления не рекомендован',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: preview.suggestedAmount > 0
                  ? AppTheme.accent
                  : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextIncomeLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                _MetricChip(
                  label: 'Текущий баланс',
                  value: SomFormatter.amount(preview.currentBalance),
                ),
                _MetricChip(
                  label: 'Платежи до дохода',
                  value: SomFormatter.amount(preview.requiredPayments),
                ),
                _MetricChip(
                  label: 'Буфер на жизнь',
                  value: SomFormatter.amount(preview.lifeBuffer),
                ),
                _MetricChip(
                  label: 'Безопасный остаток',
                  value: SomFormatter.amount(preview.safeBalance),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(DailySafeToSaveModel preview) {
    if (!preview.enabled) {
      return 'Функция недоступна для текущего сценария.';
    }
    if (preview.daysToNextIncome > 0) {
      return 'До следующего дохода ${preview.daysToNextIncome} дн. Статус: ${preview.status}.';
    }
    return 'Статус на сегодня: ${preview.status}.';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MonthAnalysisCard extends StatelessWidget {
  const _MonthAnalysisCard({
    required this.summary,
    required this.title,
    required this.onTap,
  });

  final _AnalysisSummary summary;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _MetricRow(
              label: 'Поступления',
              amount: summary.income,
              color: const Color(0xFF4CAF50),
              prefix: '+',
            ),
            const SizedBox(height: 14),
            _MetricRow(
              label: 'Расходы',
              amount: summary.expenses,
              color: const Color(0xFFE57373),
              prefix: '-',
            ),
            const SizedBox(height: 14),
            SegmentedSpendBar(
              segments: <SpendSegment>[
                SpendSegment(
                  color: const Color(0xFF4CAF50),
                  value: summary.income,
                ),
                SpendSegment(
                  color: const Color(0xFFE57373),
                  value: summary.expenses,
                ),
              ],
              height: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.amount,
    required this.color,
    this.prefix,
  });

  final String label;
  final double amount;
  final Color color;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${prefix ?? ''}${SomFormatter.amount(amount)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.summary});

  final _AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: <Widget>[
          AnalysisCategoryRow(
            color: AppTheme.accent,
            title: 'Поступления',
            amount: summary.income,
            highlight: true,
          ),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          AnalysisCategoryRow(
            color: AppTheme.blue,
            title: 'Оплата по QR',
            amount: summary.qr,
          ),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          AnalysisCategoryRow(
            color: AppTheme.accent,
            title: 'Переводы',
            amount: summary.transfers,
          ),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          AnalysisCategoryRow(
            color: AppTheme.yellow,
            title: 'Покупки',
            amount: summary.shopping,
          ),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          AnalysisCategoryRow(
            color: AppTheme.coral,
            title: 'Рестораны',
            amount: summary.restaurants,
          ),
        ],
      ),
    );
  }
}

class _AnalysisSummary {
  const _AnalysisSummary({
    required this.income,
    required this.expenses,
    required this.qr,
    required this.transfers,
    required this.shopping,
    required this.restaurants,
  });

  final double income;
  final double expenses;
  final double qr;
  final double transfers;
  final double shopping;
  final double restaurants;
}
