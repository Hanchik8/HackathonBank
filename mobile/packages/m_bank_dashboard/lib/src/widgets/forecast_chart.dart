import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/ai_dashboard_model.dart';
import '../theme/app_theme.dart';

class ForecastChart extends StatelessWidget {
  const ForecastChart({super.key, required this.dashboard});

  final AiDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final points = dashboard.points;
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = points
        .map((point) => FlSpot(point.dayOffset.toDouble(), point.balance))
        .toList(growable: false);
    final chartMaxX = points.last.dayOffset <= 0
        ? 1.0
        : points.last.dayOffset.toDouble();
    final bottomTitleInterval = dashboard.horizonDays > 10
        ? 3.0
        : dashboard.horizonDays > 4
        ? 2.0
        : 1.0;
    final minBalance = points
        .map((point) => point.balance)
        .reduce((left, right) => left < right ? left : right);
    final maxBalance = points
        .map((point) => point.balance)
        .reduce((left, right) => left > right ? left : right);
    final minY = minBalance - 5000;
    final maxY = maxBalance + 5000;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: chartMaxX,
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final roundedValue = value.roundToDouble();
                  if ((value - roundedValue).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }
                  final index = roundedValue.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final shouldShow =
                      dashboard.horizonDays <= 4 ||
                      index == 0 ||
                      index == points.length - 1 ||
                      index % bottomTitleInterval.toInt() == 0;
                  if (!shouldShow) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      points[index].label,
                      style: const TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 120,
              getTooltipColor: (_) => AppTheme.surface,
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: <HorizontalLine>[
              HorizontalLine(
                y: 0,
                dashArray: const <int>[6, 6],
                color: Colors.white12,
              ),
            ],
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.accent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, index, barData, spotIndexPercent) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: AppTheme.accent,
                      strokeColor: AppTheme.background,
                      strokeWidth: 2,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppTheme.accent.withValues(alpha: 0.28),
                    AppTheme.accent.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
