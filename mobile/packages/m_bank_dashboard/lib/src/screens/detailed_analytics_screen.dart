// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ai_dashboard_model.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

typedef _MonthlyBucket = ({DateTime month, double income, double expense});
typedef _DailyNetPoint = ({DateTime date, double value});
typedef _PieSlice = ({
  String category,
  double value,
  double percentage,
  Color color,
});
typedef _ForecastSummary = ({
  List<FlSpot> primarySpots,
  List<FlSpot> secondarySpots,
  List<DateTime> dates,
  double projectedBalance,
  bool isBackendBalanceMode,
});

class DetailedAnalyticsScreen extends StatefulWidget {
  const DetailedAnalyticsScreen({
    super.key,
    required this.transactions,
    this.backendForecastPoints,
  });

  final List<TransactionModel> transactions;
  final List<ForecastPointModel>? backendForecastPoints;

  @override
  State<DetailedAnalyticsScreen> createState() =>
      _DetailedAnalyticsScreenState();
}

class _DetailedAnalyticsScreenState extends State<DetailedAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static Duration get _chartAnimationDuration =>
      kIsWeb ? Duration.zero : const Duration(milliseconds: 600);

  late final AnimationController _animationController;
  late final CurvedAnimation _chartAnimation;
  int _touchedPieIndex = -1;

  late List<TransactionModel> _sortedTransactions;
  late DateTime _anchorDate;
  late List<_MonthlyBucket> _monthlyBuckets;
  late List<_DailyNetPoint> _dailyNetSeries;
  late List<_PieSlice> _pieSlices;
  late _ForecastSummary _forecast;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _chartAnimationDuration,
    );
    _chartAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (kIsWeb) {
      _animationController.value = 1;
    } else {
      _animationController.forward();
    }
    _recomputeAnalytics();
  }

  @override
  void didUpdateWidget(covariant DetailedAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactions != widget.transactions ||
        oldWidget.backendForecastPoints != widget.backendForecastPoints) {
      _recomputeAnalytics();
    }
  }

  @override
  void dispose() {
    _chartAnimation.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _recomputeAnalytics() {
    _sortedTransactions =
        widget.transactions
            .where((transaction) => transaction.status == 'COMPLETED')
            .toList(growable: false)
          ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    _anchorDate = _sortedTransactions.isEmpty
        ? DateTime.now()
        : _sortedTransactions.last.occurredAt;
    _monthlyBuckets = _buildMonthlyBuckets();
    _dailyNetSeries = _buildDailyNetSeries();
    _pieSlices = _buildPieSlices();
    final backendPoints = widget.backendForecastPoints;
    _forecast = backendPoints != null && backendPoints.isNotEmpty
        ? _buildBackendForecast(backendPoints)
        : _buildFallbackForecast();
  }

  @override
  Widget build(BuildContext context) {
    final touchedSlice =
        _touchedPieIndex >= 0 && _touchedPieIndex < _pieSlices.length
        ? _pieSlices[_touchedPieIndex]
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Подробная аналитика',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'История за 3 месяца, динамика чистого потока и структура расходов по категориям.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            _card(
              context,
              title: 'Доходы и расходы по месяцам',
              subtitle: 'Сравнение последних трёх месяцев.',
              footer: const _LegendRow(
                items: <({Color color, String label})>[
                  (color: Color(0xFF4CAF50), label: 'Доходы'),
                  (color: Color(0xFFE57373), label: 'Расходы'),
                ],
              ),
              child: _animatedChart(
                BarChart(_buildMonthlyBarChartData(context)),
              ),
            ),
            const SizedBox(height: 18),
            _card(
              context,
              title: 'Тренд чистого денежного потока',
              subtitle: '90 дней истории с нулевой линией.',
              child: _animatedChart(
                LineChart(
                  _buildNetTrendChartData(context),
                  duration: _chartAnimationDuration,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _card(
              context,
              title: 'Расходы по категориям',
              subtitle: touchedSlice == null
                  ? 'Нажмите на сектор, чтобы увидеть категорию и долю.'
                  : '${touchedSlice.category} · ${touchedSlice.percentage.toStringAsFixed(1)}%',
              footer: _PieLegend(slices: _pieSlices),
              child: _animatedChart(
                PieChart(
                  _buildPieChartData(context),
                  swapAnimationDuration: _chartAnimationDuration,
                  swapAnimationCurve: Curves.easeInOut,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _card(
              context,
              title: _forecast.isBackendBalanceMode
                  ? 'Прогноз баланса'
                  : 'Экстраполяция доходов и расходов',
              subtitle: _forecast.isBackendBalanceMode
                  ? 'Серверный прогноз баланса на основе доходных и платёжных событий.'
                  : 'Клиентский fallback-прогноз по данным последних 3 месяцев.',
              footer: _forecast.isBackendBalanceMode
                  ? Text(
                      'Ожидаемый баланс в конце окна: ${SomFormatter.amount(_forecast.projectedBalance.abs())}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _forecast.projectedBalance >= 0
                            ? AppTheme.accent
                            : const Color(0xFFE57373),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _LegendRow(
                          items: <({Color color, String label})>[
                            (
                              color: Color(0xFF4CAF50),
                              label: 'Прогноз доходов',
                            ),
                            (
                              color: Color(0xFFE57373),
                              label: 'Прогноз расходов',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Прогнозируемый остаток: ${_signedAmount(_forecast.projectedBalance)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _forecast.projectedBalance >= 0
                                    ? AppTheme.accent
                                    : const Color(0xFFE57373),
                              ),
                        ),
                      ],
                    ),
              child: _animatedChart(
                LineChart(
                  _buildForecastChartData(context),
                  duration: _chartAnimationDuration,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    const borderRadius = BorderRadius.all(Radius.circular(24));
    final cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
          if (footer != null) ...<Widget>[const SizedBox(height: 18), footer],
        ],
      ),
    );
    if (kIsWeb) {
      return ClipRRect(borderRadius: borderRadius, child: cardContent);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: cardContent,
      ),
    );
  }

  Widget _animatedChart(Widget chart) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final targetHeight = (constraints.maxWidth * 0.65).clamp(200.0, 320.0);
        return SizedBox(height: targetHeight, child: chart);
      },
    );
    if (kIsWeb) {
      return content;
    }
    return FadeTransition(opacity: _chartAnimation, child: content);
  }

  List<_MonthlyBucket> _buildMonthlyBuckets() => List<_MonthlyBucket>.generate(
    3,
    (index) {
      final anchorMonth = DateTime(_anchorDate.year, _anchorDate.month, 1);
      final monthStart = DateTime(
        anchorMonth.year,
        anchorMonth.month - (2 - index),
        1,
      );
      final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
      final monthTransactions = _sortedTransactions.where((transaction) {
        final occurredAt = transaction.occurredAt;
        return !occurredAt.isBefore(monthStart) &&
            occurredAt.isBefore(nextMonthStart);
      });
      final income = monthTransactions
          .where((transaction) => transaction.amount > 0)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final expense = monthTransactions
          .where((transaction) => transaction.amount < 0)
          .fold<double>(0, (sum, t) => sum + t.amount.abs());
      return (month: monthStart, income: income, expense: expense);
    },
  );

  List<_DailyNetPoint> _buildDailyNetSeries() {
    final anchorDay = _dateOnly(_anchorDate);
    final startDay = anchorDay.subtract(const Duration(days: 89));
    final amountsByDay = <DateTime, double>{};
    for (final transaction in _sortedTransactions) {
      final day = _dateOnly(transaction.occurredAt);
      if (day.isBefore(startDay) || day.isAfter(anchorDay)) {
        continue;
      }
      amountsByDay.update(
        day,
        (current) => current + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return List<_DailyNetPoint>.generate(90, (index) {
      final day = startDay.add(Duration(days: index));
      return (date: day, value: amountsByDay[day] ?? 0);
    });
  }

  List<_PieSlice> _buildPieSlices() {
    final monthStart = DateTime(_anchorDate.year, _anchorDate.month, 1);
    final nextMonthStart = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
    final expensesByCategory = <String, double>{};
    for (final transaction in _sortedTransactions) {
      if (transaction.amount >= 0) {
        continue;
      }
      if (transaction.occurredAt.isBefore(monthStart) ||
          !transaction.occurredAt.isBefore(nextMonthStart)) {
        continue;
      }
      final category = transaction.category.trim().isEmpty
          ? 'Без категории'
          : transaction.category.trim();
      expensesByCategory.update(
        category,
        (current) => current + transaction.amount.abs(),
        ifAbsent: () => transaction.amount.abs(),
      );
    }
    final total = expensesByCategory.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    if (total <= 0) {
      return const <_PieSlice>[];
    }
    final palette = <Color>[
      const Color(0xFF4CAF50),
      AppTheme.blue,
      AppTheme.yellow,
      AppTheme.coral,
      const Color(0xFF26C6DA),
      const Color(0xFFFFB74D),
      const Color(0xFFBA68C8),
      const Color(0xFF90A4AE),
    ];
    final sortedEntries = expensesByCategory.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final slices = <_PieSlice>[];
    var otherValue = 0.0;
    for (var index = 0; index < sortedEntries.length; index++) {
      final entry = sortedEntries[index];
      final percentage = entry.value / total * 100;
      if (percentage < 5) {
        otherValue += entry.value;
        continue;
      }
      slices.add((
        category: entry.key,
        value: entry.value,
        percentage: percentage,
        color: palette[index % palette.length],
      ));
    }
    if (otherValue > 0) {
      slices.add((
        category: 'Другое',
        value: otherValue,
        percentage: otherValue / total * 100,
        color: const Color(0xFF9E9E9E),
      ));
    }
    return slices;
  }

  _ForecastSummary _buildBackendForecast(List<ForecastPointModel> points) {
    final cappedPoints = points.take(30).toList(growable: false);
    final dates = cappedPoints
        .map(
          (point) => _dateOnly(DateTime.tryParse(point.isoDate) ?? _anchorDate),
        )
        .toList(growable: false);
    return (
      primarySpots: cappedPoints
          .asMap()
          .entries
          .map((entry) => FlSpot(entry.key.toDouble(), entry.value.balance))
          .toList(growable: false),
      secondarySpots: const <FlSpot>[],
      dates: dates,
      projectedBalance: cappedPoints.last.balance,
      isBackendBalanceMode: true,
    );
  }

  _ForecastSummary _buildFallbackForecast() {
    final incomeRegression = _linearRegression(
      _monthlyBuckets.map((bucket) => bucket.income).toList(growable: false),
    );
    final expenseRegression = _linearRegression(
      _monthlyBuckets.map((bucket) => bucket.expense).toList(growable: false),
    );
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final dates = <DateTime>[];
    var projectedBalance = 0.0;
    for (var dayIndex = 0; dayIndex < 30; dayIndex++) {
      final x = 3 + (dayIndex / 30);
      final dailyIncome = _predictRegression(incomeRegression, x) / 30;
      final dailyExpense = _predictRegression(expenseRegression, x) / 30;
      incomeSpots.add(FlSpot(dayIndex.toDouble(), dailyIncome));
      expenseSpots.add(FlSpot(dayIndex.toDouble(), dailyExpense));
      dates.add(_dateOnly(_anchorDate).add(Duration(days: dayIndex + 1)));
      projectedBalance += dailyIncome - dailyExpense;
    }
    return (
      primarySpots: incomeSpots,
      secondarySpots: expenseSpots,
      dates: dates,
      projectedBalance: projectedBalance,
      isBackendBalanceMode: false,
    );
  }

  ({double slope, double intercept}) _linearRegression(List<double> values) {
    if (values.isEmpty) {
      return (slope: 0, intercept: 0);
    }
    final n = values.length.toDouble();
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var index = 0; index < values.length; index++) {
      final x = index.toDouble();
      final y = values[index];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    final denominator = n * sumXX - (sumX * sumX);
    if (denominator == 0) {
      return (slope: 0, intercept: values.last);
    }
    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;
    return (slope: slope, intercept: intercept);
  }

  double _predictRegression(
    ({double slope, double intercept}) regression,
    double x,
  ) => math.max<double>(0, regression.intercept + regression.slope * x);

  BarChartData _buildMonthlyBarChartData(BuildContext context) {
    final maxValue = _monthlyBuckets.fold<double>(
      0,
      (currentMax, bucket) => math.max<double>(
        currentMax,
        math.max<double>(bucket.income, bucket.expense),
      ),
    );
    return BarChartData(
      minY: 0,
      maxY: math.max<double>(1, maxValue * 1.2),
      alignment: BarChartAlignment.spaceAround,
      groupsSpace: 18,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: math.max<double>(1, maxValue * 0.3),
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withValues(alpha: 0.07),
          strokeWidth: 1,
          dashArray: const <int>[4, 4],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _monthlyBuckets.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _shortMonth(_monthlyBuckets[index].month),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: BarTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => AppTheme.surface,
          tooltipBorderRadius: BorderRadius.circular(14),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final label = rodIndex == 0 ? 'Доходы' : 'Расходы';
            return BarTooltipItem(
              '$label\n${SomFormatter.amount(rod.toY)}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            );
          },
        ),
      ),
      barGroups: _monthlyBuckets
          .asMap()
          .entries
          .map(
            (entry) => BarChartGroupData(
              x: entry.key,
              barsSpace: 10,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: entry.value.income,
                  width: 14,
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                BarChartRodData(
                  toY: entry.value.expense,
                  width: 14,
                  color: const Color(0xFFE57373),
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  LineChartData _buildNetTrendChartData(BuildContext context) {
    final spots = _dailyNetSeries
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
        .toList(growable: false);
    final maxAbs = _dailyNetSeries.fold<double>(
      0,
      (currentMax, point) => math.max<double>(currentMax, point.value.abs()),
    );
    final chartExtent = math.max<double>(1, maxAbs * 1.2);
    return LineChartData(
      minX: 0,
      maxX: math.max<double>(1, _dailyNetSeries.length - 1).toDouble(),
      minY: -chartExtent,
      maxY: chartExtent,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: math.max<double>(1, chartExtent / 3),
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withValues(alpha: value == 0 ? 0.18 : 0.07),
          strokeWidth: 1,
          dashArray: const <int>[4, 4],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 15,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= _dailyNetSeries.length) {
                return const SizedBox.shrink();
              }
              final shouldShow =
                  index == 0 ||
                  index == _dailyNetSeries.length - 1 ||
                  index % 15 == 0;
              if (!shouldShow) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _shortDayMonth(_dailyNetSeries[index].date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => AppTheme.surface,
          getTooltipItems: (spots) => spots
              .map((spot) {
                final date = _dailyNetSeries[spot.x.round()].date;
                return LineTooltipItem(
                  '${_shortDayMonth(date)}\n${_signedAmount(spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: <HorizontalLine>[
          HorizontalLine(
            y: 0,
            color: Colors.white.withValues(alpha: 0.18),
            strokeWidth: 1,
            dashArray: const <int>[6, 4],
          ),
        ],
      ),
      lineBarsData: <LineChartBarData>[
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.accent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 2.8,
                  color: AppTheme.accent,
                  strokeWidth: 1.5,
                  strokeColor: AppTheme.background,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.accent.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  PieChartData _buildPieChartData(BuildContext context) => PieChartData(
    centerSpaceRadius: 44,
    sectionsSpace: 3,
    pieTouchData: PieTouchData(
      enabled: true,
      touchCallback: (event, response) {
        final index = response?.touchedSection?.touchedSectionIndex ?? -1;
        if (_touchedPieIndex == index) return;
        setState(() => _touchedPieIndex = index);
      },
    ),
    sections: _pieSlices
        .asMap()
        .entries
        .map((entry) {
          final isTouched = entry.key == _touchedPieIndex;
          return PieChartSectionData(
            value: entry.value.value,
            color: entry.value.color,
            radius: isTouched ? 92 : 82,
            showTitle: isTouched,
            title: '${entry.value.percentage.toStringAsFixed(1)}%',
            titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          );
        })
        .toList(growable: false),
  );

  LineChartData _buildForecastChartData(BuildContext context) {
    final maxX = math.max<double>(0, _forecast.dates.length - 1).toDouble();
    if (_forecast.isBackendBalanceMode) {
      final minY = <double>[
        ..._forecast.primarySpots.map((spot) => spot.y),
        0,
      ].reduce(math.min);
      final maxY = <double>[
        ..._forecast.primarySpots.map((spot) => spot.y),
        1,
      ].reduce(math.max);
      final padding = math.max<double>(1, (maxY - minY).abs() * 0.15);
      return LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max<double>(1, (maxY - minY).abs() / 3),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.07),
            strokeWidth: 1,
            dashArray: const <int>[4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _forecastTitles(context),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => AppTheme.surface,
            getTooltipItems: (spots) => spots
                .map((spot) {
                  final date = _forecast.dates[spot.x.round()];
                  return LineTooltipItem(
                    'Баланс · ${_shortDayMonth(date)}\n${SomFormatter.amount(spot.y.abs())}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: _forecast.primarySpots,
            isCurved: true,
            color: AppTheme.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accent.withValues(alpha: 0.15),
            ),
          ),
        ],
      );
    }

    final maxY = <double>[
      ..._forecast.primarySpots.map((spot) => spot.y),
      ..._forecast.secondarySpots.map((spot) => spot.y),
      1,
    ].reduce(math.max);
    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: maxY * 1.2,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: math.max<double>(1, maxY / 3),
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withValues(alpha: 0.07),
          strokeWidth: 1,
          dashArray: const <int>[4, 4],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _forecastTitles(context),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => AppTheme.surface,
          getTooltipItems: (spots) => spots
              .map((spot) {
                final label = spot.barIndex == 0 ? 'Доходы' : 'Расходы';
                return LineTooltipItem(
                  '$label · ${_shortDayMonth(_forecast.dates[spot.x.round()])}\n${SomFormatter.amount(spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
      lineBarsData: <LineChartBarData>[
        LineChartBarData(
          spots: _forecast.primarySpots,
          isCurved: true,
          color: const Color(0xFF4CAF50),
          dashArray: const <int>[6, 4],
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
          ),
        ),
        LineChartBarData(
          spots: _forecast.secondarySpots,
          isCurved: true,
          color: const Color(0xFFE57373),
          dashArray: const <int>[6, 4],
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFFE57373).withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  FlTitlesData _forecastTitles(BuildContext context) => FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 7,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= _forecast.dates.length) {
            return const SizedBox.shrink();
          }
          final shouldShow =
              index == 0 ||
              index == _forecast.dates.length - 1 ||
              index % 7 == 0;
          if (!shouldShow) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _shortDayMonth(_forecast.dates[index]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    ),
  );

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _shortMonth(DateTime value) {
    const months = <String>[
      'Янв',
      'Фев',
      'Мар',
      'Апр',
      'Май',
      'Июн',
      'Июл',
      'Авг',
      'Сен',
      'Окт',
      'Ноя',
      'Дек',
    ];
    return months[value.month - 1];
  }

  String _shortDayMonth(DateTime value) {
    const months = <String>[
      'янв.',
      'февр.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  String _signedAmount(double value) =>
      '${value >= 0 ? '+' : '−'}${SomFormatter.amount(value.abs())}';
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.items});

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PieLegend extends StatelessWidget {
  const _PieLegend({required this.slices});

  final List<_PieSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Text(
        'В этом месяце завершённых расходов по категориям пока нет.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slices
          .map(
            (slice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slice.category,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${slice.percentage.toStringAsFixed(1)}% · ${SomFormatter.amount(slice.value)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
