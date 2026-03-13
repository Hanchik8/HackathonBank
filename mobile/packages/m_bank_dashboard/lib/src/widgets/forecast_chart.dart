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
    final spots = points
        .map((point) => FlSpot(point.dayOffset.toDouble(), point.balance))
        .toList();
    final bottomTitleInterval = dashboard.horizonDays > 4 ? 2.0 : 1.0;
    final minY =
        points
            .map((point) => point.balance)
            .reduce((left, right) => left < right ? left : right) -
        5000;
    final maxY =
        points
            .map((point) => point.balance)
            .reduce((left, right) => left > right ? left : right) +
        5000;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: dashboard.horizonDays.toDouble().clamp(1, 10),
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
              reservedSize: 24,
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
                    index == dashboard.horizonDays ||
                    index % bottomTitleInterval.toInt() == 0;
                if (!shouldShow) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
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
    );
  }
}
