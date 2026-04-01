import 'package:flutter/material.dart';

import '../contracts/dashboard_repository.dart';
import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/daily_safe_to_save_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';
import '../widgets/action_circle_button.dart';
import '../widgets/admin_mode_sheet.dart';
import '../widgets/analysis_category_row.dart';
import '../widgets/analysis_insight_card.dart';
import '../widgets/balance_advice_card.dart';
import '../widgets/create_loan_sheet.dart';
import '../widgets/forecast_chart.dart';
import '../widgets/mini_badge.dart';
import '../widgets/scheduled_payment_form_sheet.dart';
import '../widgets/segmented_spend_bar.dart';
import '../widgets/smart_category_form_sheet.dart';
import '../widgets/smart_list_card.dart';
import '../widgets/transaction_capture_sheet.dart';
import '../widgets/upcoming_payments_card.dart';
import 'detailed_analytics_screen.dart';

part 'ai_dashboard_widgets.dart';

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
  static const List<String> _monthTitles = <String>[
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  AiDashboardModel? _dashboard;
  AiAnalysisModel? _analysis;
  DailySafeToSaveModel? _dailySafeToSave;
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
  bool _isTogglingAdminMode = false;
  bool _isTogglingAutoDailySave = false;
  bool _isApplyingAdminAction = false;
  bool _isSimulateTickInFlight = false;

  bool _smartListEnabled = true;
  bool _adminModeEnabled = false;
  bool _autoDailySaveEnabled = false;
  String? _deletingCategoryId;
  String? _updatingFavoriteCategoryId;
  int? _deletingPaymentId;
  DateTime _effectiveDate = _today();
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
    final requestOffset = _offsetDays.clamp(0, _daysUntilEndOfMonth());
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
        widget.repository.fetchDailySafeToSave(),
        widget.repository.getSmartListEnabled(),
        widget.repository.getAdminModeEnabled(),
        widget.repository.getAutoDailySaveEnabled(),
        widget.repository.getEffectiveDate(),
      ]);

      if (!mounted) {
        return;
      }

      final effectiveDate = results[9] as DateTime;
      final maxDays = _daysUntilEndOfMonthFrom(effectiveDate);

      setState(() {
        _dashboard = results[0] as AiDashboardModel;
        _analysis = results[1] as AiAnalysisModel;
        _transactions = results[2] as List<TransactionModel>;
        _accounts = results[3] as List<AccountModel>;
        _smartCategories = results[4] as List<SmartCategory>;
        _dailySafeToSave = results[5] as DailySafeToSaveModel;
        _smartListEnabled = results[6] as bool;
        _adminModeEnabled = results[7] as bool;
        _autoDailySaveEnabled = results[8] as bool;
        _effectiveDate = effectiveDate;
        _offsetDays = _offsetDays.clamp(0, maxDays);
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

  Future<void> _refreshFinancialState() async {
    final requestOffset = _offsetDays.clamp(0, _daysUntilEndOfMonth());

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.fetchDashboard(requestOffset),
        widget.repository.analyzeCashFlow(requestOffset),
        widget.repository.fetchTransactions(),
        widget.repository.fetchAccounts(),
        widget.repository.fetchDailySafeToSave(),
        widget.repository.getEffectiveDate(),
      ]);

      if (!mounted) {
        return;
      }

      final effectiveDate = results[5] as DateTime;
      final maxDays = _daysUntilEndOfMonthFrom(effectiveDate);

      setState(() {
        _dashboard = results[0] as AiDashboardModel;
        _analysis = results[1] as AiAnalysisModel;
        _transactions = results[2] as List<TransactionModel>;
        _accounts = results[3] as List<AccountModel>;
        _dailySafeToSave = results[4] as DailySafeToSaveModel;
        _effectiveDate = effectiveDate;
        _offsetDays = _offsetDays.clamp(0, maxDays);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    }
  }

  Future<void> _refreshSmartListState({
    bool includeSettings = false,
  }) async {
    try {
      final futures = <Future<dynamic>>[
        widget.repository.fetchSmartCategories(),
        if (includeSettings) widget.repository.getSmartListEnabled(),
      ];
      final results = await Future.wait<dynamic>(futures);

      if (!mounted) {
        return;
      }

      var index = 0;
      final categories = results[index++] as List<SmartCategory>;
      final smartListEnabled = includeSettings
          ? results[index] as bool
          : _smartListEnabled;

      setState(() {
        _smartCategories = categories;
        _smartListEnabled = smartListEnabled;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    }
  }

  Future<void> _executeSuggestion(BalanceSuggestionModel suggestion) async {
    if (_isExecuting || suggestion.actionToken.isEmpty) {
      return;
    }

    setState(() {
      _isExecuting = true;
    });

    try {
      final execution = await widget.repository.executeAction(
        suggestion.actionToken,
      );
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      _showMessage(execution.message);
      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
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
        referenceDate: _effectiveDate,
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
        _offsetDays = dueInDays;
      }
      widget.onDataChanged();
      _showMessage('Платеж "${created.title}" запланирован.');
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
        });
      }
    }
  }

  Future<void> _deleteScheduledPayment(int paymentId) async {
    if (_deletingPaymentId != null) {
      return;
    }

    setState(() {
      _deletingPaymentId = paymentId;
    });

    try {
      await widget.repository.deleteScheduledPayment(paymentId);
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      _showMessage('Отложенный платеж удален.');
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _deletingPaymentId = null;
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
        referenceDate: _effectiveDate,
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
        _offsetDays = dueInDays;
      }
      widget.onDataChanged();
      _showMessage('Кредит создан. Прогноз обновлен.');
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
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
    if (accounts == null || accounts.isEmpty || _isCreatingTransaction) {
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
      _showMessage(
        draft.smartCategoryId == null
            ? 'Платеж сохранен.'
            : 'Платеж сохранен и учтен в Smart List.',
      );
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
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
      _showMessage('Категория "${draft.name}" добавлена.');
      await _refreshSmartListState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
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
      _showMessage('Категория удалена.');
      await _refreshSmartListState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _deletingCategoryId = null;
        });
      }
    }
  }

  Future<void> _toggleFavoriteCategory(SmartCategory category) async {
    if (_updatingFavoriteCategoryId != null) {
      return;
    }

    setState(() {
      _updatingFavoriteCategoryId = category.id;
    });

    try {
      await widget.repository.setSmartCategoryFavorite(
        category.id,
        !category.isFavorite,
      );
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      await _refreshSmartListState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _updatingFavoriteCategoryId = null;
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
      await _refreshSmartListState(includeSettings: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingSmartList = false;
        });
      }
    }
  }

  Future<void> _toggleAdminMode() async {
    if (_isTogglingAdminMode) {
      return;
    }

    setState(() {
      _isTogglingAdminMode = true;
    });

    try {
      final nextValue = !_adminModeEnabled;
      await widget.repository.setAdminModeEnabled(nextValue);
      if (!mounted) {
        return;
      }

      widget.onDataChanged();
      await _refreshFinancialState();
      if (nextValue) {
        await _openAdminModeSheet();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingAdminMode = false;
        });
      }
    }
  }

  Future<void> _toggleAutoDailySave(bool enabled) async {
    if (_isTogglingAutoDailySave) {
      return;
    }

    setState(() {
      _isTogglingAutoDailySave = true;
    });

    try {
      await widget.repository.setAutoDailySaveEnabled(enabled);
      if (!mounted) {
        return;
      }

      setState(() {
        _autoDailySaveEnabled = enabled;
      });
      _showMessage(
        enabled
            ? 'Автоматический Safe-to-Save включен.'
            : 'Автоматический Safe-to-Save выключен.',
      );
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingAutoDailySave = false;
        });
      }
    }
  }

  Future<void> _simulateNextDay() async {
    if (_isSimulateTickInFlight) {
      return;
    }

    setState(() {
      _isSimulateTickInFlight = true;
    });
    try {
      final response = await widget.repository.simulateDay();
      if (!mounted) {
        return;
      }

      await _refreshFinancialState();
      if (response.notification.isNotEmpty) {
        _showMessage(response.notification);
      }
      widget.onDataChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSimulateTickInFlight = false;
        });
      }
    }
  }

  Future<void> _openAdminModeSheet() async {
    final accounts = _accounts;
    if (!_adminModeEnabled ||
        accounts == null ||
        accounts.isEmpty ||
        _isApplyingAdminAction) {
      return;
    }

    final action = await showModalBottomSheet<AdminModeAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AdminModeSheet(accounts: accounts, effectiveDate: _effectiveDate),
    );

    if (action == null) {
      return;
    }

    await _applyAdminAction(action);
  }

  Future<void> _applyAdminAction(AdminModeAction action) async {
    if (_isApplyingAdminAction) {
      return;
    }

    setState(() {
      _isApplyingAdminAction = true;
    });

    try {
      await widget.repository.setEffectiveDate(action.effectiveDate);
      _effectiveDate = action.effectiveDate;

      switch (action.kind) {
        case AdminModeActionKind.setDate:
          break;
        case AdminModeActionKind.addFunds:
          if (action.accountId != null) {
            await widget.repository.adjustAccountBalance(
              accountId: action.accountId!,
              delta: action.amount,
              title: action.title,
            );
          }
        case AdminModeActionKind.removeFunds:
          if (action.accountId != null) {
            await widget.repository.adjustAccountBalance(
              accountId: action.accountId!,
              delta: -action.amount,
              title: action.title,
            );
          }
      }

      if (!mounted) {
        return;
      }

      _offsetDays = _offsetDays.clamp(0, _daysUntilEndOfMonth());
      widget.onDataChanged();
      _showMessage('Админ-режим обновлен.');
      await _refreshFinancialState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingAdminAction = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final dailySafeToSave = _dailySafeToSave!;
    final transactions = _transactions!;
    final smartCategories = _smartCategories!;
    final scheduledPayments = dashboard.scheduledPayments;
    final summary = _buildSummary(transactions, _offsetDays);
    final reminderCount = scheduledPayments
        .where((payment) => payment.isReminder)
        .length;
    final nearestPayment = scheduledPayments.isEmpty
        ? null
        : scheduledPayments.first;
    final summaryTitle = _summaryTitle(_offsetDays);
    final maxDays = _daysUntilEndOfMonth();
    final sliderMax = maxDays <= 0 ? 1 : maxDays;
    final sliderValue = _offsetDays.clamp(0, sliderMax).toDouble();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'ИИ отслеживает будущие списания, доходные паттерны и заранее предлагает действия, прежде чем баланс уйдет в минус.',
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
                    icon: Icons.skip_next_rounded,
                    isLoading: _isSimulateTickInFlight,
                    onTap: _simulateNextDay,
                  ),
                  ActionCircleButton(
                    icon: _adminModeEnabled
                        ? Icons.manage_history_rounded
                        : Icons.admin_panel_settings_outlined,
                    isLoading: _isTogglingAdminMode || _isApplyingAdminAction,
                    onTap: _adminModeEnabled
                        ? _openAdminModeSheet
                        : _toggleAdminMode,
                  ),
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
                subtitle: 'Накопительный депозит',
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
          _DailySafeToSaveCard(
            preview: dailySafeToSave,
            autoDailySaveEnabled: _autoDailySaveEnabled,
            isBusy: _isTogglingAutoDailySave,
            onToggle: _toggleAutoDailySave,
          ),
          const SizedBox(height: 18),
          _MonthAnalysisCard(
            summary: summary,
            title: summaryTitle,
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                pageBuilder: (routeContext, animation, secondaryAnimation) =>
                    DetailedAnalyticsScreen(
                      transactions: _transactions ?? const <TransactionModel>[],
                    ),
                transitionsBuilder:
                    (routeContext, animation, secondaryAnimation, child) =>
                        SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                              ),
                          child: child,
                        ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _BreakdownCard(summary: summary),
          if (analysis.hasAlert) ...<Widget>[
            const SizedBox(height: 18),
            BalanceAdviceCard(
              analysis: analysis,
              isLoading: _isExecuting,
              onExecute: _executeSuggestion,
            ),
          ],
          const SizedBox(height: 18),
          _ForecastCard(
            dashboard: dashboard,
            scheduledPaymentCount: scheduledPayments.length,
            sliderMax: sliderMax,
            sliderValue: sliderValue,
            offsetDays: _offsetDays,
            maxDays: maxDays,
            onChanged: (value) => setState(() => _offsetDays = value.round()),
            onChangeEnd: (_) => _loadData(),
          ),
          const SizedBox(height: 18),
          _AdminModeCard(
            enabled: _adminModeEnabled,
            effectiveDate: _effectiveDate,
            isBusy: _isTogglingAdminMode || _isApplyingAdminAction,
            onToggle: _toggleAdminMode,
            onOpen: _openAdminModeSheet,
          ),
          const SizedBox(height: 18),
          if (_smartListEnabled)
            SmartListCard(
              categories: smartCategories,
              onAddCategory: _openCreateSmartCategorySheet,
              onToggleFavorite: _toggleFavoriteCategory,
              onDeleteCategory: _deleteSmartCategory,
              deletingCategoryId: _deletingCategoryId,
              updatingFavoriteCategoryId: _updatingFavoriteCategoryId,
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
          UpcomingPaymentsCard(
            payments: scheduledPayments,
            referenceDate: _effectiveDate,
            isCreatingPayment: _isCreatingPayment,
            onCreate: _openScheduledPaymentSheet,
            onDelete: _deleteScheduledPayment,
            deletingPaymentId: _deletingPaymentId,
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
    final referenceDate = _dateOnly(
      _effectiveDate,
    ).add(Duration(days: offsetDays));
    final windowStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final completedTransactions =
        transactions
            .where((transaction) => transaction.status == 'COMPLETED')
            .toList(growable: false)
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    final windowTransactions = completedTransactions
        .where(
          (transaction) =>
              !transaction.occurredAt.isBefore(windowStart) &&
              !transaction.occurredAt.isAfter(referenceDate),
        )
        .toList(growable: false);
    final relevantTransactions = windowTransactions.isEmpty
        ? completedTransactions.take(12).toList(growable: false)
        : windowTransactions;

    final income = relevantTransactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    final expenses = relevantTransactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount.abs(),
        );
    final qr = relevantTransactions
        .where((transaction) => transaction.type == 'QR_TRANSFER')
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount.abs(),
        );
    final transfers = relevantTransactions
        .where((transaction) => transaction.type == 'TRANSFER')
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount.abs(),
        );
    final shopping = relevantTransactions
        .where((transaction) => transaction.iconKey == 'shopping')
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount.abs(),
        );
    final restaurants = relevantTransactions
        .where((transaction) => transaction.iconKey == 'food')
        .fold<double>(
          0.0,
          (sum, transaction) => sum + transaction.amount.abs(),
        );

    return _AnalysisSummary(
      income: income,
      expenses: expenses,
      qr: qr,
      transfers: transfers,
      shopping: shopping,
      restaurants: restaurants,
    );
  }

  String _summaryTitle(int offsetDays) {
    final referenceDate = _dateOnly(
      _effectiveDate,
    ).add(Duration(days: offsetDays));
    return 'За ${_monthLabel(referenceDate.month)}';
  }

  String _monthLabel(int month) {
    return _monthTitles[month - 1];
  }

  int _daysUntil(DateTime dueDate) {
    return _dateOnly(dueDate).difference(_dateOnly(_effectiveDate)).inDays;
  }

  int _daysUntilEndOfMonth() {
    return _daysUntilEndOfMonthFrom(_effectiveDate);
  }

  int _daysUntilEndOfMonthFrom(DateTime value) {
    final monthEnd = DateTime(value.year, value.month + 1, 0);
    return monthEnd.difference(_dateOnly(value)).inDays;
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

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
