import 'package:flutter/material.dart';

import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/transaction_model.dart';
import '../services/bank_api_service.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';
import '../widgets/ai_alert_card.dart';
import '../widgets/analysis_category_row.dart';
import '../widgets/forecast_chart.dart';
import '../widgets/segmented_spend_bar.dart';

class AiDashboardScreen extends StatefulWidget {
  const AiDashboardScreen({
    super.key,
    required this.apiService,
    required this.refreshSignal,
    required this.onDataChanged,
  });

  final BankApiService apiService;
  final int refreshSignal;
  final VoidCallback onDataChanged;

  @override
  State<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends State<AiDashboardScreen> {
  AiDashboardModel? _dashboard;
  AiAnalysisModel? _analysis;
  List<TransactionModel>? _transactions;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isExecuting = false;
  int _offsetDays = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AiDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.apiService.fetchDashboard(_offsetDays),
        widget.apiService.analyzeCashFlow(),
        widget.apiService.fetchTransactions(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = results[0] as AiDashboardModel;
        _analysis = results[1] as AiAnalysisModel;
        _transactions = results[2] as List<TransactionModel>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _executeAction() async {
    final token = _analysis?.actionToken;
    if (token == null || _isExecuting) {
      return;
    }

    setState(() {
      _isExecuting = true;
    });

    try {
      final execution = await widget.apiService.executeAction(token);
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(execution.message)));
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final dashboard = _dashboard!;
    final analysis = _analysis!;
    final transactions = _transactions!;
    final summary = _buildSummary(transactions);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.accent,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Финансовый анализ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _MonthAnalysisCard(summary: summary),
          const SizedBox(height: 18),
          _BreakdownCard(summary: summary),
          if (analysis.hasAlert) ...<Widget>[
            const SizedBox(height: 18),
            AiAlertCard(
              message: analysis.message,
              isLoading: _isExecuting,
              onExecute: analysis.actionToken == null ? null : _executeAction,
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Прогноз баланса',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  SomFormatter.amount(dashboard.minimumProjectedBalance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: dashboard.minimumProjectedBalance < 0
                        ? Colors.white
                        : AppTheme.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
                  child: ForecastChart(dashboard: dashboard),
                ),
                const SizedBox(height: 16),
                Text(
                  'Машина времени',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  min: 0,
                  max: 10,
                  divisions: 10,
                  value: _offsetDays.toDouble(),
                  label: '$_offsetDays дн.',
                  onChanged: (value) {
                    setState(() => _offsetDays = value.round());
                  },
                  onChangeEnd: (_) => _loadData(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '0 дней',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    Text(
                      '10 дней',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
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

  _AnalysisSummary _buildSummary(List<TransactionModel> transactions) {
    final monthTransactions = transactions
        .where(
          (transaction) => transaction.occurredAt.month == DateTime.now().month,
        )
        .toList();

    final income = monthTransactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expenses = monthTransactions
        .where(
          (transaction) =>
              transaction.amount < 0 && transaction.status == 'COMPLETED',
        )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final qr = monthTransactions
        .where((transaction) => transaction.type == 'QR_TRANSFER')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final transfers = monthTransactions
        .where((transaction) => transaction.type == 'TRANSFER')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final shopping = monthTransactions
        .where((transaction) => transaction.iconKey == 'shopping')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final restaurants = monthTransactions
        .where((transaction) => transaction.iconKey == 'food')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());

    return _AnalysisSummary(
      income: income,
      expenses: expenses,
      qr: qr,
      transfers: transfers,
      shopping: shopping,
      restaurants: restaurants,
    );
  }
}

class _MonthAnalysisCard extends StatelessWidget {
  const _MonthAnalysisCard({required this.summary});

  final _AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'За Март',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _MetricRow(
            label: 'Поступления',
            amount: summary.income,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 10),
          SegmentedSpendBar(
            segments: <SpendSegment>[
              SpendSegment(color: Colors.white24, value: summary.income),
            ],
            height: 12,
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Расходы',
            amount: summary.expenses,
            color: Colors.white,
          ),
          const SizedBox(height: 10),
          SegmentedSpendBar(
            segments: <SpendSegment>[
              SpendSegment(color: AppTheme.blue, value: summary.qr),
              SpendSegment(color: AppTheme.accent, value: summary.transfers),
              SpendSegment(color: AppTheme.yellow, value: summary.shopping),
              SpendSegment(color: AppTheme.coral, value: summary.restaurants),
            ],
            height: 16,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

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
          SomFormatter.amount(amount),
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
            title: 'Перевод по номеру телефона QR',
            amount: summary.transfers,
          ),
          const Divider(color: Color(0xFF2A2A2E), height: 1),
          AnalysisCategoryRow(
            color: AppTheme.yellow,
            title: 'Разные товары',
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
