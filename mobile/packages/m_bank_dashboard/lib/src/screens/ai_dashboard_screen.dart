// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../contracts/dashboard_repository.dart';
import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/save_suggestion_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';
import '../widgets/action_circle_button.dart';
import '../widgets/ai_alert_card.dart';
import '../widgets/analysis_category_row.dart';
import '../widgets/analysis_insight_card.dart';
import '../widgets/create_loan_sheet.dart';
import '../widgets/forecast_chart.dart';
import '../widgets/mini_badge.dart';
import '../widgets/scheduled_payment_form_sheet.dart';
import '../widgets/segmented_spend_bar.dart';
import '../widgets/smart_category_form_sheet.dart';
import '../widgets/smart_list_card.dart';
import '../widgets/transaction_capture_sheet.dart';
import '../widgets/upcoming_payments_card.dart';

class AiDashboardScreen extends StatefulWidget {
  const AiDashboardScreen({
    super.key,
    required this.repository,
    required this.refreshSignal,
    required this.onDataChanged,
  });

  final DashboardRepository repository;
  final int refreshSignal;
  final VoidCallback onDataChanged;

  @override
  State<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends State<AiDashboardScreen> {
  AiDashboardModel? _dashboard;
  AiAnalysisModel? _analysis;
  SaveSuggestionModel? _saveSuggestion;
  List<TransactionModel>? _transactions;
  List<AccountModel>? _accounts;
  List<SmartCategory>? _smartCategories;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isExecuting = false;
  bool _isCreatingPayment = false;
  bool _isCreatingLoan = false;
  bool _isCreatingTransaction = false;
  bool _isCreatingCategory = false;
  bool _isTogglingSmartList = false;
  bool _smartListEnabled = true;
  String? _deletingCategoryId;
  late int _offsetDays;

  @override
  void initState() {
    super.initState();
    _offsetDays = _daysUntilEndOfMonth();
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
    final maxDays = _daysUntilEndOfMonth();
    final requestOffset = _offsetDays.clamp(0, maxDays);
    if (_offsetDays != requestOffset) {
      _offsetDays = requestOffset;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.fetchDashboard(requestOffset),
        widget.repository.analyzeCashFlow(requestOffset),
        widget.repository.fetchTransactions(),
        widget.repository.fetchAccounts(),
        widget.repository.fetchSmartCategories(),
        widget.repository.suggestEndOfMonthSave(),
        widget.repository.getSmartListEnabled(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = results[0] as AiDashboardModel;
        _analysis = results[1] as AiAnalysisModel;
        _transactions = results[2] as List<TransactionModel>;
        _accounts = results[3] as List<AccountModel>;
        _smartCategories = results[4] as List<SmartCategory>;
        _saveSuggestion = results[5] as SaveSuggestionModel;
        _smartListEnabled = results[6] as bool;
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
      final execution = await widget.repository.executeAction(token);
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

  Future<void> _openScheduledPaymentSheet() async {
    final accounts = _accounts;
    if (accounts == null || accounts.isEmpty || _isCreatingPayment) {
      return;
    }

    final draft = await showModalBottomSheet<ScheduledPaymentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduledPaymentFormSheet(
        accounts: accounts,
        initialOffsetDays: _initialSheetOffset(),
      ),
    );

    if (draft == null) {
      return;
    }
    await _createScheduledPayment(draft);
  }

  Future<void> _createScheduledPayment(ScheduledPaymentDraft draft) async {
    if (_isCreatingPayment) {
      return;
    }

    setState(() {
      _isCreatingPayment = true;
    });

    try {
      final created = await widget.repository.createReminderScheduledPayment(
        accountId: draft.accountId,
        title: draft.title,
        counterparty: draft.counterparty,
        category: draft.category,
        amount: draft.amount,
        dueDate: draft.dueDate,
        isReminder: draft.isReminder,
      );
      if (!mounted) {
        return;
      }

      final dueInDays = _daysUntil(created.dueDate);
      final maxDays = _daysUntilEndOfMonth();
      if (dueInDays > _offsetDays && dueInDays <= maxDays) {
        setState(() {
          _offsetDays = dueInDays;
        });
      }
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Платеж "${created.title}" запланирован.')),
      );
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
          _isCreatingPayment = false;
        });
      }
    }
  }

  Future<void> _openCreateLoanSheet() async {
    final accounts = _accounts;
    if (accounts == null || accounts.isEmpty || _isCreatingLoan) {
      return;
    }

    final draft = await showModalBottomSheet<LoanDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateLoanSheet(
        accounts: accounts,
        initialOffsetDays: _initialSheetOffset(),
      ),
    );

    if (draft == null) {
      return;
    }
    await _createLoan(draft);
  }

  Future<void> _createLoan(LoanDraft draft) async {
    if (_isCreatingLoan) {
      return;
    }

    setState(() {
      _isCreatingLoan = true;
    });

    try {
      await widget.repository.createLoan(
        accountId: draft.accountId,
        title: draft.title,
        amount: draft.amount,
        dueDate: draft.dueDate,
      );
      if (!mounted) {
        return;
      }

      final dueInDays = _daysUntil(draft.dueDate);
      final maxDays = _daysUntilEndOfMonth();
      if (dueInDays > _offsetDays && dueInDays <= maxDays) {
        setState(() {
          _offsetDays = dueInDays;
        });
      }
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Кредит создан. Дашборд обновлен.')),
      );
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
          _isCreatingLoan = false;
        });
      }
    }
  }

  Future<void> _openCreateTransactionSheet() async {
    final accounts = _accounts;
    final smartCategories = _smartCategories;
    if (accounts == null ||
        accounts.isEmpty ||
        _isCreatingTransaction) {
      return;
    }

    final draft = await showModalBottomSheet<TransactionCaptureDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionCaptureSheet(
        accounts: accounts,
        smartCategories: smartCategories ?? const <SmartCategory>[],
        smartListEnabled: _smartListEnabled,
      ),
    );

    if (draft == null) {
      return;
    }
    await _createTransaction(draft);
  }

  Future<void> _createTransaction(TransactionCaptureDraft draft) async {
    if (_isCreatingTransaction) {
      return;
    }

    setState(() {
      _isCreatingTransaction = true;
    });

    try {
      await widget.repository.createTransaction(
        accountId: draft.accountId,
        title: draft.title,
        counterparty: draft.counterparty,
        amount: draft.amount,
        type: draft.type,
        category: draft.categoryLabel,
        iconKey: draft.iconKey,
        smartCategoryId: draft.smartCategoryId,
      );
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.smartCategoryId == null
                ? 'Платеж сохранен.'
                : 'Платеж сохранен и учтен в Smart List.',
          ),
        ),
      );
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
          _isCreatingTransaction = false;
        });
      }
    }
  }

  Future<void> _openCreateSmartCategorySheet() async {
    if (_isCreatingCategory) {
      return;
    }

    final draft = await showModalBottomSheet<SmartCategoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SmartCategoryFormSheet(),
    );

    if (draft == null) {
      return;
    }
    await _createSmartCategory(draft);
  }

  Future<void> _createSmartCategory(SmartCategoryDraft draft) async {
    if (_isCreatingCategory) {
      return;
    }

    setState(() {
      _isCreatingCategory = true;
    });

    try {
      await widget.repository.createSmartCategory(
        name: draft.name,
        plannedMonthly: draft.plannedMonthly,
      );
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Категория "${draft.name}" добавлена.')),
      );
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
          _isCreatingCategory = false;
        });
      }
    }
  }

  Future<void> _deleteSmartCategory(String categoryId) async {
    if (_deletingCategoryId != null) {
      return;
    }

    setState(() {
      _deletingCategoryId = categoryId;
    });

    try {
      await widget.repository.deleteSmartCategory(categoryId);
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Категория удалена.')));
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
          _deletingCategoryId = null;
        });
      }
    }
  }

  Future<void> _toggleSmartList() async {
    if (_isTogglingSmartList) {
      return;
    }

    setState(() {
      _isTogglingSmartList = true;
    });

    try {
      await widget.repository.setSmartListEnabled(!_smartListEnabled);
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
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
          _isTogglingSmartList = false;
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
    final saveSuggestion = _saveSuggestion!;
    final smartCategories = _smartCategories!;
    final transactions = _transactions!;
    final summary = _buildSummary(transactions, _offsetDays);
    final scheduledPayments = dashboard.scheduledPayments;
    final reminderCount = scheduledPayments
        .where((payment) => payment.isReminder)
        .length;
    final summaryTitle = dashboard.points.isEmpty
        ? 'Последние 30 дней'
        : 'Окно до ${dashboard.points.last.label}';
    final nearestPayment = scheduledPayments.isEmpty
        ? null
        : scheduledPayments.first;
    final maxDays = _daysUntilEndOfMonth();
    final sliderMax = maxDays <= 0 ? 1 : maxDays;
    final sliderValue = _offsetDays.clamp(0, sliderMax).toDouble();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Финансовый анализ',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ИИ отслеживает будущие списания и заранее предлагает действие, прежде чем баланс уйдет в минус.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ActionCircleButton(
                    icon: Icons.account_balance_wallet_rounded,
                    isLoading: _isCreatingLoan,
                    onTap: _openCreateLoanSheet,
                  ),
                  ActionCircleButton(
                    icon: Icons.qr_code_rounded,
                    isLoading: _isCreatingTransaction,
                    onTap: _openCreateTransactionSheet,
                  ),
                  ActionCircleButton(
                    icon: Icons.add_alert_rounded,
                    isLoading: _isCreatingPayment,
                    onTap: _openScheduledPaymentSheet,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              AnalysisInsightCard(
                title: 'Подушка',
                value: SomFormatter.amount(dashboard.savingsBalance),
                subtitle: 'Счет сбережений',
                accentColor: AppTheme.accent,
              ),
              AnalysisInsightCard(
                title: 'Будущие списания',
                value: '$reminderCount',
                subtitle: nearestPayment == null
                    ? 'Критичных списаний нет'
                    : 'Ближайшее: ${AppDateFormatter.shortDate(nearestPayment.dueDate)}',
                accentColor: AppTheme.blue,
              ),
              AnalysisInsightCard(
                title: 'Минимум в окне',
                value: SomFormatter.amount(dashboard.minimumProjectedBalance),
                subtitle: 'Горизонт ${dashboard.horizonDays} дн.',
                accentColor: dashboard.minimumProjectedBalance < 0
                    ? AppTheme.coral
                    : AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MonthAnalysisCard(summary: summary, title: summaryTitle),
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
                            SomFormatter.amount(
                              dashboard.minimumProjectedBalance,
                            ),
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
                      label: '${scheduledPayments.length} платежей',
                      color: AppTheme.accent,
                    ),
                  ],
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
                  max: sliderMax.toDouble(),
                  divisions: sliderMax,
                  value: sliderValue,
                  label: '$_offsetDays дн.',
                  onChanged: (value) =>
                      setState(() => _offsetDays = value.round()),
                  onChangeEnd: (_) => _loadData(),
                ),
                Text(
                  'Горизонт до конца месяца: $maxDays дн.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '0 дн.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    Text(
                      '10 дн.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_smartListEnabled)
            SmartListCard(
              categories: smartCategories,
              onAddCategory: _openCreateSmartCategorySheet,
              onDeleteCategory: _deleteSmartCategory,
              deletingCategoryId: _deletingCategoryId,
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                'Smart List выключен. Включите его внизу, чтобы снова привязывать платежи к категориям.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 18),
          _SaveSuggestionCard(suggestion: saveSuggestion),
          const SizedBox(height: 18),
          UpcomingPaymentsCard(
            payments: scheduledPayments,
            isCreatingPayment: _isCreatingPayment,
            onCreate: _openScheduledPaymentSheet,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTogglingSmartList ? null : _toggleSmartList,
              child: Text(
                _smartListEnabled
                    ? 'Выключить Smart List'
                    : 'Включить Smart List',
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AnalysisSummary _buildSummary(
    List<TransactionModel> transactions,
    int offsetDays,
  ) {
    final referenceDate = DateTime.now().add(Duration(days: offsetDays));
    final windowStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final completedTransactions =
        transactions
            .where((transaction) => transaction.status == 'COMPLETED')
            .toList()
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    final windowTransactions = completedTransactions
        .where(
          (transaction) =>
              !transaction.occurredAt.isBefore(windowStart) &&
              !transaction.occurredAt.isAfter(referenceDate),
        )
        .toList();
    final relevantTransactions = windowTransactions.isEmpty
        ? completedTransactions.take(12).toList()
        : windowTransactions;

    final income = relevantTransactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expenses = relevantTransactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final qr = relevantTransactions
        .where((transaction) => transaction.type == 'QR_TRANSFER')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final transfers = relevantTransactions
        .where((transaction) => transaction.type == 'TRANSFER')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final shopping = relevantTransactions
        .where((transaction) => transaction.iconKey == 'shopping')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final restaurants = relevantTransactions
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

  int _daysUntil(DateTime dueDate) {
    final now = DateTime.now();
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    return dueDateOnly.difference(todayOnly).inDays;
  }

  int _daysUntilEndOfMonth() {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    return monthEnd.difference(todayOnly).inDays;
  }

  int _initialSheetOffset() {
    final maxDays = _daysUntilEndOfMonth();
    if (maxDays <= 3) {
      return maxDays;
    }
    if (_offsetDays < 3) {
      return 3;
    }
    return _offsetDays > maxDays ? maxDays : _offsetDays;
  }
}

class _MonthAnalysisCard extends StatelessWidget {
  const _MonthAnalysisCard({required this.summary, required this.title});

  final _AnalysisSummary summary;
  final String title;

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
            title,
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

class _SaveSuggestionCard extends StatelessWidget {
  const _SaveSuggestionCard({required this.suggestion});

  final SaveSuggestionModel suggestion;

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
          Text(
            'Совет по накоплению',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.amount <= 0
                ? 'Свободной суммы для перевода в сбережения сейчас нет.'
                : 'Можно отложить ${SomFormatter.amount(suggestion.amount)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: suggestion.amount <= 0 ? Colors.white : AppTheme.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Страховой резерв: ${SomFormatter.amount(suggestion.safetyReserve)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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

class _LoanDraft {
  const _LoanDraft({
    required this.accountId,
    required this.title,
    required this.amount,
    required this.dueDate,
  });

  final int accountId;
  final String title;
  final double amount;
  final DateTime dueDate;
}

class _CreateLoanSheet extends StatefulWidget {
  const _CreateLoanSheet({
    required this.accounts,
    required this.initialOffsetDays,
  });

  final List<AccountModel> accounts;
  final int initialOffsetDays;

  @override
  State<_CreateLoanSheet> createState() => _CreateLoanSheetState();
}

class _CreateLoanSheetState extends State<_CreateLoanSheet> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Экспресс-кредит',
  );
  final TextEditingController _amountController = TextEditingController();

  int? _accountId;
  late DateTime _selectedDate;

  int get _daysOffset {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _selectedDate.difference(today).inDays;
  }

  set _daysOffset(int value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = today.add(Duration(days: value));
  }

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    final today = DateTime.now();
    _selectedDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: widget.initialOffsetDays));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final accountId = _accountId;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (accountId == null || title.isEmpty || amount == null || amount <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _LoanDraft(
        accountId: accountId,
        title: title,
        amount: amount,
        dueDate: _selectedDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              surface: AppTheme.surface,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppTheme.surface),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 32,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Новый кредит',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'В демо-режиме кредит сразу пополнит выбранный счет и появится в прогнозе как будущее погашение.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceSoft,
                decoration: _inputDecoration('Счет зачисления'),
                items: widget.accounts
                    .map(
                      (account) => DropdownMenuItem<int>(
                        value: account.id,
                        child: Text(
                          '${_displayAccountName(account.name)} · ${SomFormatter.amount(account.balance)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: _inputDecoration('Название кредита'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration('Сумма кредита в KGS'),
              ),
              const SizedBox(height: 18),
              Text(
                'Срок до погашения',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _LoanOptionChip(
                      label: '3 дня',
                      selected: _daysOffset == 3,
                      onTap: () => setState(() => _daysOffset = 3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LoanOptionChip(
                      label: '7 дней',
                      selected: _daysOffset == 7,
                      onTap: () => setState(() => _daysOffset = 7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LoanOptionChip(
                      label: '10 дней',
                      selected: _daysOffset == 10,
                      onTap: () => setState(() => _daysOffset = 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Дата погашения: ${AppDateFormatter.shortDate(DateTime.now().add(Duration(days: _daysOffset)))}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Создать кредит'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.secondaryText),
      filled: true,
      fillColor: AppTheme.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppTheme.accent),
      ),
    );
  }

  String _displayAccountName(String name) {
    return switch (name) {
      'Main' => 'Основной счет',
      'Savings' => 'Сбережения',
      _ => name,
    };
  }
}

class _LoanOptionChip extends StatelessWidget {
  const _LoanOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
