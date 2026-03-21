import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/save_suggestion_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';
import 'api_client.dart';

class MockDataProvider {
  MockDataProvider._();

  static bool _initialized = false;
  static bool _smartListEnabled = true;
  static bool _adminModeEnabled = false;
  static DateTime _effectiveDate = _systemToday();
  static int _nextTransactionId = 2000;
  static int _nextScheduledPaymentId = 4000;
  static int _nextLoanId = 6000;
  static int _nextSmartCategoryId = 1;

  static List<AccountModel> _accounts = <AccountModel>[];
  static List<TransactionModel> _transactions = <TransactionModel>[];
  static List<ScheduledPaymentModel> _scheduledPayments =
      <ScheduledPaymentModel>[];
  static List<SmartCategory> _smartCategoryDefinitions = <SmartCategory>[];
  static Map<int, String> _transactionSmartCategoryIds = <int, String>{};

  static bool get isInitialized => _initialized;

  static bool get smartListEnabled => _smartListEnabled;

  static bool get adminModeEnabled => _adminModeEnabled;

  static DateTime get effectiveDate => _effectiveDate;

  static List<AccountModel> get accounts =>
      List<AccountModel>.unmodifiable(_accounts);

  static List<TransactionModel> get transactions =>
      List<TransactionModel>.unmodifiable(_transactions);

  static List<ScheduledPaymentModel> get scheduledPayments =>
      List<ScheduledPaymentModel>.unmodifiable(_scheduledPayments);

  static List<SmartCategory> get smartCategories =>
      List<SmartCategory>.unmodifiable(_buildSmartCategories());

  static void resetForTest() {
    _initialized = false;
    _smartListEnabled = true;
    _adminModeEnabled = false;
    _effectiveDate = _systemToday();
    _nextTransactionId = 2000;
    _nextScheduledPaymentId = 4000;
    _nextLoanId = 6000;
    _nextSmartCategoryId = 1;
    _accounts = <AccountModel>[];
    _transactions = <TransactionModel>[];
    _scheduledPayments = <ScheduledPaymentModel>[];
    _smartCategoryDefinitions = <SmartCategory>[];
    _transactionSmartCategoryIds = <int, String>{};
  }

  static void initDemoData({
    required List<AccountModel> accounts,
    required List<TransactionModel> transactions,
    List<ScheduledPaymentModel> scheduledPayments =
        const <ScheduledPaymentModel>[],
  }) {
    if (_initialized) {
      return;
    }

    _effectiveDate = _systemToday();
    _accounts = accounts.map(_copyAccount).toList(growable: false);
    _transactions = transactions.map(_copyTransaction).toList(growable: true);
    _scheduledPayments = scheduledPayments
        .map(_copyScheduledPayment)
        .toList(growable: true)
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    _smartCategoryDefinitions = const <SmartCategory>[
      SmartCategory(
        id: 'food',
        name: 'Еда',
        plannedMonthly: 12000,
        remaining: 12000,
        isFavorite: false,
      ),
      SmartCategory(
        id: 'transfer',
        name: 'Переводы',
        plannedMonthly: 9000,
        remaining: 9000,
        isFavorite: false,
      ),
      SmartCategory(
        id: 'fun',
        name: 'Развлечения',
        plannedMonthly: 7000,
        remaining: 7000,
        isFavorite: false,
      ),
    ];
    _transactionSmartCategoryIds = _inferSmartCategoryAssignments(_transactions);
    _syncCounters();
    _initialized = true;
  }

  static Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) async {
    final account = _findAccount(accountId);
    final payment = ScheduledPaymentModel(
      id: _nextScheduledPaymentId++,
      accountId: account.id,
      accountName: account.name,
      title: title,
      counterparty: counterparty,
      category: category,
      iconKey: _iconForCategory(category),
      amount: amount,
      dueDate: _dateOnly(dueDate),
      status: 'SCHEDULED',
      isReminder: isReminder,
    );
    _scheduledPayments = <ScheduledPaymentModel>[
      ..._scheduledPayments,
      payment,
    ]..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    return payment;
  }

  static Future<void> deleteScheduledPayment(int paymentId) async {
    _scheduledPayments.removeWhere((payment) => payment.id == paymentId);
  }

  static Future<TransactionModel> createTransaction({
    required int accountId,
    required String title,
    required String counterparty,
    required double amount,
    required String type,
    required String category,
    required String iconKey,
    String? smartCategoryId,
  }) async {
    final account = _findAccount(accountId);
    final normalizedAmount = _normalizeTransactionAmount(type, amount);
    final transaction = TransactionModel(
      id: _nextTransactionId++,
      title: title,
      counterparty: counterparty,
      amount: normalizedAmount,
      category: category,
      iconKey: iconKey,
      type: type,
      status: 'COMPLETED',
      accountName: account.name,
      occurredAt: _effectiveDateTime(),
    );

    _transactions = <TransactionModel>[transaction, ..._transactions];
    _updateAccountBalance(accountId, normalizedAmount);
    if (smartCategoryId != null && smartCategoryId.isNotEmpty) {
      _transactionSmartCategoryIds[transaction.id] = smartCategoryId;
    }
    return transaction;
  }

  static Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    final account = _findAccount(accountId);
    _updateAccountBalance(accountId, amount);
    _transactions = <TransactionModel>[
      TransactionModel(
        id: _nextLoanId++,
        title: title,
        counterparty: 'MBank',
        amount: amount,
        category: 'Кредит',
        iconKey: 'income',
        type: 'INCOME',
        status: 'COMPLETED',
        accountName: account.name,
        occurredAt: _effectiveDateTime(),
      ),
      ..._transactions,
    ];

    await createReminderScheduledPayment(
      accountId: accountId,
      title: '$title · Погашение',
      counterparty: 'MBank',
      category: 'Кредит',
      amount: amount * 1.12,
      dueDate: dueDate,
      isReminder: true,
    );
  }

  static Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
    final category = SmartCategory(
      id: 'smart-${_nextSmartCategoryId++}',
      name: name,
      plannedMonthly: plannedMonthly,
      remaining: plannedMonthly,
      isFavorite: false,
    );
    _smartCategoryDefinitions = <SmartCategory>[
      ..._smartCategoryDefinitions,
      category,
    ];
    return category;
  }

  static Future<void> setSmartCategoryFavorite(
    String categoryId,
    bool isFavorite,
  ) async {
    final currentCategory = _smartCategoryDefinitions
        .where((category) => category.id == categoryId)
        .firstOrNull;
    if (currentCategory == null) {
      throw const ApiException(404, 'Smart-категория не найдена.');
    }

    if (isFavorite && !currentCategory.isFavorite) {
      final favoriteCount = _smartCategoryDefinitions
          .where((category) => category.isFavorite)
          .length;
      if (favoriteCount >= 3) {
        throw const ApiException(
          400,
          'Можно выбрать не больше трех избранных категорий.',
        );
      }
    }

    _smartCategoryDefinitions = _smartCategoryDefinitions
        .map(
          (category) => category.id == categoryId
              ? SmartCategory(
                  id: category.id,
                  name: category.name,
                  plannedMonthly: category.plannedMonthly,
                  remaining: category.remaining,
                  isFavorite: isFavorite,
                )
              : category,
        )
        .toList(growable: false);
  }

  static Future<void> deleteSmartCategory(String categoryId) async {
    _smartCategoryDefinitions = _smartCategoryDefinitions
        .where((category) => category.id != categoryId)
        .toList(growable: false);
    _transactionSmartCategoryIds.removeWhere(
      (_, assignedCategoryId) => assignedCategoryId == categoryId,
    );
  }

  static Future<void> setSmartListEnabled(bool enabled) async {
    _smartListEnabled = enabled;
  }

  static Future<void> setAdminModeEnabled(bool enabled) async {
    _adminModeEnabled = enabled;
  }

  static Future<void> setEffectiveDate(DateTime date) async {
    _effectiveDate = _dateOnly(date);
  }

  static Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) async {
    final account = _findAccount(accountId);
    final normalizedTitle = title.trim().isEmpty
        ? delta >= 0
              ? 'Пополнение счета'
              : 'Списание со счета'
        : title.trim();
    final transaction = TransactionModel(
      id: _nextTransactionId++,
      title: normalizedTitle,
      counterparty: 'Admin',
      amount: delta,
      category: delta >= 0 ? 'Поступления' : 'Корректировки',
      iconKey: delta >= 0 ? 'income' : 'calendar',
      type: delta >= 0 ? 'INCOME' : 'ADJUSTMENT',
      status: 'COMPLETED',
      accountName: account.name,
      occurredAt: _effectiveDateTime(),
    );
    _updateAccountBalance(accountId, delta);
    _transactions = <TransactionModel>[transaction, ..._transactions];
    return transaction;
  }

  static AiDashboardModel computeDashboard(int horizonDays) {
    final trackedAccount = _pickTrackedAccount();
    final savingsAccount = _pickSavingsAccount();
    final today = _today();
    final normalizedHorizon = horizonDays < 0 ? 0 : horizonDays;
    final endDate = today.add(Duration(days: normalizedHorizon));
    final trackedPayments = _scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .where((payment) => !payment.dueDate.isAfter(endDate))
        .toList()
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    var runningBalance = trackedAccount.balance;
    final points = List<ForecastPointModel>.generate(
      normalizedHorizon + 1,
      (int index) {
        final date = today.add(Duration(days: index));
        if (index > 0) {
          final dailyOutflow = trackedPayments
              .where((payment) => _isSameDay(payment.dueDate, date))
              .fold<double>(0.0, (sum, payment) => sum + payment.amount);
          runningBalance -= dailyOutflow;
        }
        return ForecastPointModel(
          dayOffset: index,
          isoDate: date.toIso8601String(),
          label: _shortDateLabel(date),
          balance: runningBalance,
        );
      },
    );

    final minimumProjectedBalance = points.isEmpty
        ? trackedAccount.balance
        : points
            .map((point) => point.balance)
            .reduce((left, right) => left < right ? left : right);

    return AiDashboardModel(
      currentBalance: trackedAccount.balance,
      savingsBalance: savingsAccount?.balance ?? 0.0,
      minimumProjectedBalance: minimumProjectedBalance,
      horizonDays: normalizedHorizon,
      points: points,
      scheduledPayments: trackedPayments,
    );
  }

  static AiAnalysisModel computeBalanceAdvice({int? horizonDays}) {
    final normalizedHorizon = horizonDays ?? daysUntilEndOfMonth();
    final dashboard = computeDashboard(normalizedHorizon);
    final deficit = dashboard.minimumProjectedBalance < 0
        ? dashboard.minimumProjectedBalance.abs()
        : 0.0;

    if (deficit <= 0) {
      return const AiAnalysisModel(
        hasAlert: false,
        message:
            'До конца месяца прогноз остается положительным. Дополнительные действия не нужны.',
        actionToken: null,
      );
    }

    final suggestions = _buildBalanceSuggestions(
      dashboard: dashboard,
      deficit: deficit,
    );
    final horizonDate = _today().add(Duration(days: normalizedHorizon));
    final message = suggestions.isEmpty
        ? 'К ${_shortDateLabel(horizonDate)} ожидается дефицит ${_money(deficit)}. Подходящих действий в демо не найдено.'
        : 'К ${_shortDateLabel(horizonDate)} ожидается дефицит ${_money(deficit)}. Ниже варианты, как закрыть разрыв.';

    return AiAnalysisModel(
      hasAlert: suggestions.isNotEmpty,
      message: message,
      actionToken: suggestions.isEmpty ? null : suggestions.first.actionToken,
      suggestions: suggestions,
    );
  }

  static SaveSuggestionModel computeSuggestedSave() {
    final trackedAccount = _pickTrackedAccount();
    final today = _today();
    final monthEnd = _monthEnd(today);
    final scheduledOutflow = _scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .where((payment) => !payment.dueDate.isAfter(monthEnd))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
    final reservedByBudgets = smartListEnabled
        ? _buildSmartCategories().fold<double>(
            0.0,
            (sum, category) =>
                sum + (category.remaining > 0 ? category.remaining : 0),
          )
        : 0.0;
    final safetyReserve = (trackedAccount.balance * 0.15).clamp(3000.0, 15000.0);
    final freeAmount =
        trackedAccount.balance - scheduledOutflow - reservedByBudgets - safetyReserve;
    final suggestionAmount = freeAmount <= 0
        ? 0.0
        : (freeAmount / 100).floorToDouble() * 100;
    final reason = suggestionAmount <= 0
        ? 'До конца месяца свободного остатка нет: оставьте деньги на обязательные списания.'
        : 'Можно безопасно отложить часть остатка: ближайшие платежи и лимиты категорий уже учтены.';

    return SaveSuggestionModel(
      amount: suggestionAmount,
      reason: reason,
      safetyReserve: safetyReserve,
    );
  }

  static Future<AiExecutionModel> executeAction(String actionToken) async {
    final parts = actionToken.split(':');
    final command = parts.isEmpty ? '' : parts.first;

    switch (command) {
      case 'CLOSE_DEPOSIT':
        final depositId = parts.length > 1 ? int.tryParse(parts[1]) : null;
        return _closeDeposit(depositId);
      case 'POSTPONE':
        if (parts.length < 3) {
          return _executionFailure('Не удалось распознать перенос платежа.');
        }
        final paymentId = int.tryParse(parts[1]);
        if (paymentId == null) {
          return _executionFailure('Не удалось распознать перенос платежа.');
        }
        return _postponePayments(
          paymentIds: <int>[paymentId],
          targetDate: _resolveTargetDate(
            targetSpec: parts[2],
            referenceDate: _paymentDateById(paymentId),
          ),
          label: 'Платеж перенесен.',
        );
      case 'POSTPONE_GROUP':
        if (parts.length < 3) {
          return _executionFailure('Не удалось распознать перенос группы платежей.');
        }
        final paymentIds = _parsePaymentIds(parts[1]);
        if (paymentIds.isEmpty) {
          return _executionFailure('Не удалось распознать перенос группы платежей.');
        }
        return _postponePayments(
          paymentIds: paymentIds,
          targetDate: _resolveTargetDate(
            targetSpec: parts[2],
            referenceDate: _latestPaymentDate(paymentIds),
          ),
          label: 'Группа платежей перенесена.',
        );
      case 'CLOSE_DEPOSIT_AND_POSTPONE':
        if (parts.length < 4) {
          return _executionFailure(
            'Не удалось распознать комбинированное действие.',
          );
        }
        final depositId = int.tryParse(parts[1]);
        final paymentIds = _parsePaymentIds(parts[2]);
        await _closeDeposit(depositId);
        return _postponePayments(
          paymentIds: paymentIds,
          targetDate: _resolveTargetDate(
            targetSpec: parts[3],
            referenceDate: _latestPaymentDate(paymentIds),
          ),
          label: 'Депозит закрыт, платежи перенесены.',
        );
      default:
        return _executionFailure('Неизвестное действие: $actionToken');
    }
  }

  static List<BalanceSuggestionModel> _buildBalanceSuggestions({
    required AiDashboardModel dashboard,
    required double deficit,
  }) {
    final suggestions = <String, BalanceSuggestionModel>{};
    final savingsAccount = _pickSavingsAccount();
    final flexiblePayments = _collectFlexiblePayments(dashboard);

    if (savingsAccount != null && savingsAccount.balance > 0) {
      final covered = savingsAccount.balance >= deficit;
      final suggestion = BalanceSuggestionModel(
        id: 'close-deposit-${savingsAccount.id}',
        title: covered
            ? 'Закрыть депозит и закрыть разрыв'
            : 'Закрыть депозит и сократить разрыв',
        description: covered
            ? 'Закрытие накопительного депозита даст ${_money(savingsAccount.balance)} и полностью покроет дефицит ${_money(deficit)}.'
            : 'Закрытие накопительного депозита даст ${_money(savingsAccount.balance)} и сократит дефицит ${_money(deficit)}.',
        actionToken: 'CLOSE_DEPOSIT:${savingsAccount.id}',
      );
      suggestions[suggestion.actionToken] = suggestion;
    }

    final singleCandidate = _pickSinglePostponeCandidate(
      flexiblePayments,
      deficit: deficit,
    );
    if (singleCandidate != null) {
      final targetDate = _inferRecommendedPostponeDate(
        afterDate: singleCandidate.dueDate,
      );
      if (targetDate.isAfter(_dateOnly(singleCandidate.dueDate))) {
        final postponeAmount = singleCandidate.amount;
        final covers = postponeAmount >= deficit;
        final targetLabel = _shortDateLabel(targetDate);
        final actionToken =
            'POSTPONE:${singleCandidate.id}:${targetDate.toIso8601String()}';
        suggestions[actionToken] = BalanceSuggestionModel(
          id: 'postpone-${singleCandidate.id}',
          title: 'Перенести платеж "${singleCandidate.title}"',
          description: covers
              ? 'Перенесите платеж до $targetLabel, когда обычно приходит доход. Это освободит ${_money(postponeAmount)} и закроет разрыв.'
              : 'Перенесите платеж до $targetLabel, когда обычно приходит доход. Это освободит ${_money(postponeAmount)} и уменьшит разрыв.',
          actionToken: actionToken,
        );
      }
    }

    if (flexiblePayments.length > 1) {
      final grouped = _pickPaymentsForCoverage(
        flexiblePayments,
        requiredAmount: deficit,
      );
      if (grouped.length > 1) {
        final targetDate = _inferRecommendedPostponeDate(
          afterDate: _latestDueDate(grouped),
        );
        if (targetDate.isAfter(_latestDueDate(grouped))) {
          final groupAmount = grouped.fold<double>(
            0.0,
            (sum, payment) => sum + payment.amount,
          );
          final ids = grouped.map((payment) => payment.id).join(',');
          final actionToken =
              'POSTPONE_GROUP:$ids:${targetDate.toIso8601String()}';
          suggestions[actionToken] = BalanceSuggestionModel(
            id: 'postpone-group-$ids',
            title: 'Перенести группу платежей',
            description:
                'Сдвиг ${grouped.length} платежей до ${_shortDateLabel(targetDate)} освободит ${_money(groupAmount)} и снимет давление на баланс.',
            actionToken: actionToken,
          );

          if (savingsAccount != null &&
              savingsAccount.balance > 0 &&
              savingsAccount.balance < deficit &&
              savingsAccount.balance + groupAmount >= deficit) {
            final comboToken =
                'CLOSE_DEPOSIT_AND_POSTPONE:${savingsAccount.id}:$ids:${targetDate.toIso8601String()}';
            suggestions[comboToken] = BalanceSuggestionModel(
              id: 'combo-${savingsAccount.id}-$ids',
              title: 'Комбинировать депозит и перенос',
              description:
                  'Закройте депозит и перенесите ${grouped.length} платежей до ${_shortDateLabel(targetDate)}, чтобы полностью убрать дефицит.',
              actionToken: comboToken,
            );
          }
        }
      }
    }

    return suggestions.values.toList(growable: false);
  }

  static List<ScheduledPaymentModel> _collectFlexiblePayments(
    AiDashboardModel dashboard,
  ) {
    return dashboard.scheduledPayments
        .where((payment) => payment.amount > 0)
        .where(_isFlexiblePayment)
        .toList(growable: false);
  }

  static ScheduledPaymentModel? _pickSinglePostponeCandidate(
    List<ScheduledPaymentModel> payments, {
    required double deficit,
  }) {
    final sorted = List<ScheduledPaymentModel>.from(payments)
      ..sort((left, right) {
        final byCoverage = right.amount.compareTo(left.amount);
        if (byCoverage != 0) {
          return byCoverage;
        }
        return left.dueDate.compareTo(right.dueDate);
      });

    for (final payment in sorted) {
      final targetDate = _inferRecommendedPostponeDate(afterDate: payment.dueDate);
      if (!targetDate.isAfter(_dateOnly(payment.dueDate))) {
        continue;
      }
      if (payment.amount >= deficit) {
        return payment;
      }
    }

    for (final payment in sorted) {
      final targetDate = _inferRecommendedPostponeDate(afterDate: payment.dueDate);
      if (targetDate.isAfter(_dateOnly(payment.dueDate))) {
        return payment;
      }
    }

    return null;
  }

  static List<ScheduledPaymentModel> _pickPaymentsForCoverage(
    List<ScheduledPaymentModel> payments, {
    required double requiredAmount,
  }) {
    final sorted = List<ScheduledPaymentModel>.from(payments)
      ..sort((left, right) {
        final byDate = left.dueDate.compareTo(right.dueDate);
        if (byDate != 0) {
          return byDate;
        }
        return right.amount.compareTo(left.amount);
      });
    final selected = <ScheduledPaymentModel>[];
    var covered = 0.0;
    for (final payment in sorted) {
      selected.add(payment);
      covered += payment.amount;
      if (covered >= requiredAmount) {
        break;
      }
    }
    return selected;
  }

  static DateTime _inferRecommendedPostponeDate({required DateTime afterDate}) {
    final predictedIncomeDate = _predictNextIncomeDate(after: _dateOnly(afterDate));
    if (predictedIncomeDate != null &&
        predictedIncomeDate.isAfter(_dateOnly(afterDate))) {
      return predictedIncomeDate;
    }
    return _dateOnly(afterDate).add(const Duration(days: 7));
  }

  static DateTime? _predictNextIncomeDate({required DateTime after}) {
    final incomes = _recentIncomeTransactions();
    if (incomes.isEmpty) {
      return null;
    }

    final byDay = <int, _RecurringIncomeDay>{};
    for (final transaction in incomes) {
      final day = transaction.occurredAt.day;
      final current = byDay[day];
      if (current == null) {
        byDay[day] = _RecurringIncomeDay(
          dayOfMonth: day,
          occurrences: 1,
          totalAmount: transaction.amount,
        );
      } else {
        byDay[day] = _RecurringIncomeDay(
          dayOfMonth: day,
          occurrences: current.occurrences + 1,
          totalAmount: current.totalAmount + transaction.amount,
        );
      }
    }

    final recurringDays = byDay.values.where((item) => item.occurrences >= 2).toList()
      ..sort((left, right) {
        final byCount = right.occurrences.compareTo(left.occurrences);
        if (byCount != 0) {
          return byCount;
        }
        return right.totalAmount.compareTo(left.totalAmount);
      });

    DateTime? bestCandidate;
    for (final recurringDay in recurringDays) {
      final candidate = _nextOccurrence(
        after: after,
        dayOfMonth: recurringDay.dayOfMonth,
      );
      if (bestCandidate == null || candidate.isBefore(bestCandidate)) {
        bestCandidate = candidate;
      }
    }
    if (bestCandidate != null) {
      return bestCandidate;
    }

    if (incomes.length >= 2) {
      final sorted = incomes.toList(growable: false)
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
      var totalInterval = 0;
      for (var index = 1; index < sorted.length; index += 1) {
        totalInterval += sorted[index]
            .occurredAt
            .difference(sorted[index - 1].occurredAt)
            .inDays;
      }
      final averageInterval = (totalInterval / (sorted.length - 1)).round();
      if (averageInterval > 0) {
        var candidate = _dateOnly(sorted.last.occurredAt);
        while (!candidate.isAfter(after)) {
          candidate = candidate.add(Duration(days: averageInterval));
        }
        return candidate;
      }
    }

    return null;
  }

  static List<TransactionModel> _recentIncomeTransactions() {
    final periodStart = _today().subtract(const Duration(days: 90));
    final periodEnd = _endOfDay(_effectiveDate);
    return _transactions
        .where((transaction) => transaction.status == 'COMPLETED')
        .where((transaction) => transaction.amount > 0)
        .where((transaction) => !transaction.occurredAt.isBefore(periodStart))
        .where((transaction) => !transaction.occurredAt.isAfter(periodEnd))
        .toList(growable: false);
  }

  static Future<AiExecutionModel> _closeDeposit(int? depositId) async {
    final savingsAccount = depositId == null
        ? _pickSavingsAccount()
        : _accounts.where((account) => account.id == depositId).firstOrNull;
    if (savingsAccount == null) {
      return _executionFailure('Накопительный депозит не найден.');
    }
    if (savingsAccount.balance <= 0) {
      return _executionFailure('Накопительный депозит уже пуст.');
    }

    final mainAccount = _pickTrackedAccount();
    final movedAmount = savingsAccount.balance;
    _updateAccountBalance(mainAccount.id, movedAmount);
    _updateAccountBalance(savingsAccount.id, -movedAmount);

    return _executionSuccess(
      'Депозит закрыт. На основной счет переведено ${_money(movedAmount)}.',
    );
  }

  static Future<AiExecutionModel> _postponePayments({
    required List<int> paymentIds,
    required DateTime targetDate,
    required String label,
  }) async {
    if (paymentIds.isEmpty) {
      return _executionFailure('Не найдено ни одного платежа для переноса.');
    }

    var changedCount = 0;
    _scheduledPayments = _scheduledPayments.map((payment) {
      if (!paymentIds.contains(payment.id)) {
        return payment;
      }
      changedCount += 1;
      return ScheduledPaymentModel(
        id: payment.id,
        accountId: payment.accountId,
        accountName: payment.accountName,
        title: payment.title,
        counterparty: payment.counterparty,
        category: payment.category,
        iconKey: payment.iconKey,
        amount: payment.amount,
        dueDate: _dateOnly(targetDate),
        status: 'POSTPONED',
        isReminder: payment.isReminder,
      );
    }).toList(growable: true)
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    if (changedCount == 0) {
      return _executionFailure('Не удалось найти выбранные платежи.');
    }

    final noun = changedCount == 1 ? 'платеж' : 'платежей';
    return _executionSuccess(
      '$label Перенесено $changedCount $noun на ${_shortDateLabel(_dateOnly(targetDate))}.',
    );
  }

  static AiExecutionModel _executionSuccess(String message) {
    final currentBalance = _pickTrackedAccount().balance;
    final savingsBalance = _pickSavingsAccount()?.balance ?? 0.0;
    return AiExecutionModel(
      success: true,
      message: message,
      currentBalance: currentBalance,
      savingsBalance: savingsBalance,
    );
  }

  static AiExecutionModel _executionFailure(String message) {
    final currentBalance = _accounts.isEmpty ? 0.0 : _pickTrackedAccount().balance;
    final savingsBalance = _pickSavingsAccount()?.balance ?? 0.0;
    return AiExecutionModel(
      success: false,
      message: message,
      currentBalance: currentBalance,
      savingsBalance: savingsBalance,
    );
  }

  static List<SmartCategory> _buildSmartCategories() {
    final windowStart = _monthStart(_effectiveDate);
    final windowEnd = _endOfDay(_effectiveDate);

    return _smartCategoryDefinitions.map((definition) {
      final spent = _transactions
          .where((transaction) => transaction.status == 'COMPLETED')
          .where((transaction) => transaction.amount < 0)
          .where((transaction) => !transaction.occurredAt.isBefore(windowStart))
          .where((transaction) => !transaction.occurredAt.isAfter(windowEnd))
          .where(
            (transaction) =>
                _resolveSmartCategoryId(transaction) == definition.id,
          )
          .fold<double>(0.0, (sum, transaction) => sum + transaction.amount.abs());

      return SmartCategory(
        id: definition.id,
        name: definition.name,
        plannedMonthly: definition.plannedMonthly,
        remaining: definition.plannedMonthly - spent,
        isFavorite: definition.isFavorite,
      );
    }).toList(growable: false);
  }

  static Map<int, String> _inferSmartCategoryAssignments(
    List<TransactionModel> transactions,
  ) {
    final assignments = <int, String>{};
    for (final transaction in transactions) {
      final categoryId = _inferCategoryFromTransaction(transaction);
      if (categoryId != null) {
        assignments[transaction.id] = categoryId;
      }
    }
    return assignments;
  }

  static String? _resolveSmartCategoryId(TransactionModel transaction) {
    return _transactionSmartCategoryIds[transaction.id] ??
        _inferCategoryFromTransaction(transaction);
  }

  static String? _inferCategoryFromTransaction(TransactionModel transaction) {
    final category = transaction.category.toLowerCase();
    final iconKey = transaction.iconKey.toLowerCase();
    return switch (true) {
      _ when category.contains('ед') || iconKey == 'food' => 'food',
      _ when category.contains('перевод') || transaction.type == 'TRANSFER' =>
        'transfer',
      _ when category.contains('развлеч') || iconKey == 'shopping' => 'fun',
      _ => null,
    };
  }

  static void _updateAccountBalance(int accountId, double delta) {
    _accounts = _accounts
        .map(
          (account) => account.id == accountId
              ? AccountModel(
                  id: account.id,
                  name: account.name,
                  type: account.type,
                  balance: account.balance + delta,
                  currency: account.currency,
                )
              : account,
        )
        .toList(growable: false);
  }

  static void _syncCounters() {
    if (_transactions.isNotEmpty) {
      final maxTransactionId = _transactions
          .map((transaction) => transaction.id)
          .reduce(_maxInt);
      _nextTransactionId = maxTransactionId + 1;
      _nextLoanId = maxTransactionId + 1000;
    }
    if (_scheduledPayments.isNotEmpty) {
      _nextScheduledPaymentId = _scheduledPayments
              .map((payment) => payment.id)
              .reduce(_maxInt) +
          1;
    }
  }

  static AccountModel _findAccount(int accountId) {
    return _accounts.firstWhere(
      (account) => account.id == accountId,
      orElse: _pickTrackedAccount,
    );
  }

  static AccountModel _pickTrackedAccount() {
    for (final account in _accounts) {
      if (account.type == 'MAIN') {
        return account;
      }
    }
    return _accounts.first;
  }

  static AccountModel? _pickSavingsAccount() {
    for (final account in _accounts) {
      if (account.type == 'SAVINGS') {
        return account;
      }
    }
    return null;
  }

  static bool _isFlexiblePayment(ScheduledPaymentModel payment) {
    final category = payment.category.toLowerCase();
    final title = payment.title.toLowerCase();
    const strictKeywords = <String>[
      'аренд',
      'коммун',
      'кредит',
      'налог',
      'штраф',
    ];
    final isStrict = strictKeywords.any(
      (keyword) => category.contains(keyword) || title.contains(keyword),
    );
    return !isStrict;
  }

  static double _normalizeTransactionAmount(String type, double amount) {
    if (type == 'INCOME') {
      return amount.abs();
    }
    return -amount.abs();
  }

  static String _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('аренд')) {
      return 'home';
    }
    if (normalized.contains('подпис')) {
      return 'subscription';
    }
    if (normalized.contains('кредит')) {
      return 'loan';
    }
    if (normalized.contains('перевод')) {
      return 'qr';
    }
    return 'calendar';
  }

  static List<int> _parsePaymentIds(String rawValue) {
    return rawValue
        .split(',')
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toList(growable: false);
  }

  static DateTime _resolveTargetDate({
    required String targetSpec,
    required DateTime referenceDate,
  }) {
    final parsedDays = int.tryParse(targetSpec);
    if (parsedDays != null) {
      return _dateOnly(referenceDate).add(Duration(days: parsedDays));
    }
    final parsedDate = DateTime.tryParse(targetSpec);
    if (parsedDate != null) {
      return _dateOnly(parsedDate);
    }
    return _dateOnly(referenceDate).add(const Duration(days: 7));
  }

  static DateTime _paymentDateById(int paymentId) {
    return _scheduledPayments
            .where((payment) => payment.id == paymentId)
            .firstOrNull
            ?.dueDate ??
        _today();
  }

  static DateTime _latestPaymentDate(List<int> paymentIds) {
    DateTime latest = _today();
    for (final payment in _scheduledPayments) {
      if (!paymentIds.contains(payment.id)) {
        continue;
      }
      if (payment.dueDate.isAfter(latest)) {
        latest = payment.dueDate;
      }
    }
    return latest;
  }

  static DateTime _latestDueDate(List<ScheduledPaymentModel> payments) {
    var latest = payments.first.dueDate;
    for (final payment in payments.skip(1)) {
      if (payment.dueDate.isAfter(latest)) {
        latest = payment.dueDate;
      }
    }
    return latest;
  }

  static int daysUntilEndOfMonth() {
    final today = _today();
    final monthEnd = _monthEnd(today);
    return monthEnd.difference(today).inDays;
  }

  static String _money(double amount) => '${amount.toStringAsFixed(2)} KGS';

  static DateTime _today() => _dateOnly(_effectiveDate);

  static DateTime _effectiveDateTime() {
    return DateTime(
      _effectiveDate.year,
      _effectiveDate.month,
      _effectiveDate.day,
      12,
    );
  }

  static DateTime _systemToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59);
  }

  static DateTime _monthStart(DateTime now) {
    return DateTime(now.year, now.month, 1);
  }

  static DateTime _monthEnd(DateTime now) {
    return DateTime(now.year, now.month + 1, 0);
  }

  static DateTime _nextOccurrence({
    required DateTime after,
    required int dayOfMonth,
  }) {
    final currentMonth = DateTime(after.year, after.month, 1);
    final candidates = <DateTime>[
      _safeDate(currentMonth.year, currentMonth.month, dayOfMonth),
      _safeDate(currentMonth.year, currentMonth.month + 1, dayOfMonth),
      _safeDate(currentMonth.year, currentMonth.month + 2, dayOfMonth),
    ];
    for (final candidate in candidates) {
      if (candidate.isAfter(after)) {
        return candidate;
      }
    }
    return candidates.last;
  }

  static DateTime _safeDate(int year, int month, int dayOfMonth) {
    final maxDay = DateTime(year, month + 1, 0).day;
    final clampedDay = dayOfMonth > maxDay ? maxDay : dayOfMonth;
    return DateTime(year, month, clampedDay);
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static int _maxInt(int left, int right) => left > right ? left : right;

  static String _shortDateLabel(DateTime value) {
    const months = <String>[
      'янв.',
      'фев.',
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

  static AccountModel _copyAccount(AccountModel account) {
    return AccountModel(
      id: account.id,
      name: account.name,
      type: account.type,
      balance: account.balance,
      currency: account.currency,
    );
  }

  static TransactionModel _copyTransaction(TransactionModel transaction) {
    return TransactionModel(
      id: transaction.id,
      title: transaction.title,
      counterparty: transaction.counterparty,
      amount: transaction.amount,
      category: transaction.category,
      iconKey: transaction.iconKey,
      type: transaction.type,
      status: transaction.status,
      accountName: transaction.accountName,
      occurredAt: transaction.occurredAt,
    );
  }

  static ScheduledPaymentModel _copyScheduledPayment(
    ScheduledPaymentModel payment,
  ) {
    return ScheduledPaymentModel(
      id: payment.id,
      accountId: payment.accountId,
      accountName: payment.accountName,
      title: payment.title,
      counterparty: payment.counterparty,
      category: payment.category,
      iconKey: payment.iconKey,
      amount: payment.amount,
      dueDate: payment.dueDate,
      status: payment.status,
      isReminder: payment.isReminder,
    );
  }
}

class _RecurringIncomeDay {
  const _RecurringIncomeDay({
    required this.dayOfMonth,
    required this.occurrences,
    required this.totalAmount,
  });

  final int dayOfMonth;
  final int occurrences;
  final double totalAmount;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
