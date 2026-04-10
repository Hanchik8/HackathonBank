import '../contracts/dashboard_repository.dart';
import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/daily_safe_to_save_model.dart';
import '../models/scheduled_payment_model.dart';
import '../models/simulate_day_response_model.dart';
import '../models/smart_category_model.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';

class MbankAdapter implements DashboardRepository {
  MbankAdapter({required ExistingMbankClient client}) : _client = client;

  final ExistingMbankClient _client;

  @override
  Future<List<SubscriptionModel>> fetchSubscriptions() async {
    final subscriptions = await _client.fetchSubscriptions();
    return subscriptions
        .map(
          (subscription) => SubscriptionModel(
            // TODO: Replace these fields with the real MBank subscription DTO.
            id: subscription.id,
            title: subscription.displayName,
            amount: subscription.amount,
            currency: subscription.currencyCode,
            status: subscription.status,
            nextChargeDate: subscription.nextChargeDate,
          ),
        )
        .toList();
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) {
    return _client.cancelSubscription(subscriptionId);
  }

  @override
  Future<List<AccountModel>> fetchAccounts() async {
    final accounts = await _client.getAccounts();
    return accounts.map(_mapAccount).toList();
  }

  @override
  Future<List<TransactionModel>> fetchTransactions() async {
    final transactions = await _client.getTransactions();
    return transactions.map(_mapTransaction).toList();
  }

  @override
  Future<AiDashboardModel> fetchDashboard(int offsetDays) async {
    final dashboard = await _client.getDashboardData(offsetDays);
    final forecastPoints = dashboard.points.map(_mapForecastPoint).toList();
    final scheduledPayments = dashboard.scheduledPayments
        .map(_mapScheduledPayment)
        .toList();

    return AiDashboardModel(
      currentBalance: dashboard.currentBalance,
      savingsBalance: dashboard.savingsBalance,
      minimumProjectedBalance:
          dashboard.minimumProjectedBalance ??
          (forecastPoints.isEmpty
              ? dashboard.currentBalance
              : forecastPoints
                  .map((point) => point.balance)
                  .reduce((left, right) => left < right ? left : right)),
      horizonDays: dashboard.horizonDays ?? offsetDays,
      points: forecastPoints,
      scheduledPayments: scheduledPayments,
    );
  }

  @override
  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) async {
    final analysis = await _client.analyzeCashFlow(offsetDays);
    return AiAnalysisModel(
      hasAlert: analysis.hasAlert,
      message: analysis.message,
      actionToken: analysis.actionToken,
      suggestions: analysis.suggestions
          .map(
            (suggestion) => BalanceSuggestionModel(
              id: suggestion.id,
              title: suggestion.title,
              description: suggestion.description,
              actionToken: suggestion.actionToken,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<AiExecutionModel> executeAction(String actionToken) async {
    final execution = await _client.executeAction(actionToken);
    return AiExecutionModel(
      success: execution.success,
      message: execution.message,
      currentBalance: execution.currentBalance,
      savingsBalance: execution.savingsBalance,
    );
  }

  @override
  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) async {
    final created = await _client.createScheduledPayment(
      accountId: accountId,
      title: title,
      counterparty: counterparty,
      category: category,
      amount: amount,
      dueDate: dueDate,
    );
    return _mapScheduledPayment(created);
  }

  @override
  Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) async {
    final created = await _client.createReminderScheduledPayment(
      accountId: accountId,
      title: title,
      counterparty: counterparty,
      category: category,
      amount: amount,
      dueDate: dueDate,
      isReminder: isReminder,
    );
    return _mapScheduledPayment(created);
  }

  @override
  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) {
    // TODO: Confirm the real MBank credit creation endpoint and payload.
    return _client.createLoan(
      accountId: accountId,
      title: title,
      amount: amount,
      dueDate: dueDate,
    );
  }

  @override
  Future<void> deleteScheduledPayment(int paymentId) {
    // TODO: Confirm the real MBank scheduled-payment deletion endpoint.
    return _client.deleteScheduledPayment(paymentId);
  }

  @override
  Future<TransactionModel> createTransaction({
    required int accountId,
    required String title,
    required String counterparty,
    required double amount,
    required String type,
    required String category,
    required String iconKey,
    String? smartCategoryId,
  }) async {
    final created = await _client.createTransaction(
      accountId: accountId,
      title: title,
      counterparty: counterparty,
      amount: amount,
      type: type,
      category: category,
      iconKey: iconKey,
      smartCategoryId: smartCategoryId,
    );
    return _mapTransaction(created);
  }

  @override
  Future<List<SmartCategory>> fetchSmartCategories() async {
    final categories = await _client.getSmartCategories();
    return categories.map(_mapSmartCategory).toList(growable: false);
  }

  @override
  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
    final created = await _client.createSmartCategory(
      name: name,
      plannedMonthly: plannedMonthly,
    );
    return _mapSmartCategory(created);
  }

  @override
  Future<void> setSmartCategoryFavorite(
    String categoryId,
    bool isFavorite,
  ) {
    // TODO: Confirm the real MBank endpoint for marking quick categories.
    return _client.setSmartCategoryFavorite(
      categoryId: categoryId,
      isFavorite: isFavorite,
    );
  }

  @override
  Future<void> deleteSmartCategory(String categoryId) {
    // TODO: Confirm the real MBank smart-category deletion endpoint.
    return _client.deleteSmartCategory(categoryId);
  }

  @override
  Future<bool> getSmartListEnabled() {
    // TODO: Confirm where MBank stores Smart List settings.
    return _client.getSmartListEnabled();
  }

  @override
  Future<void> setSmartListEnabled(bool enabled) {
    // TODO: Confirm the real MBank Smart List toggle endpoint.
    return _client.setSmartListEnabled(enabled);
  }

  @override
  Future<bool> getAdminModeEnabled() {
    // TODO: Confirm whether MBank exposes a demo/admin mode flag.
    return _client.getAdminModeEnabled();
  }

  @override
  Future<void> setAdminModeEnabled(bool enabled) {
    // TODO: Confirm the real MBank admin-mode toggle endpoint.
    return _client.setAdminModeEnabled(enabled);
  }

  @override
  Future<DateTime> getEffectiveDate() {
    // TODO: Confirm how MBank exposes the effective demo date.
    return _client.getEffectiveDate();
  }

  @override
  Future<void> setEffectiveDate(DateTime date) {
    // TODO: Confirm the real MBank endpoint for changing the effective date.
    return _client.setEffectiveDate(date);
  }

  @override
  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) async {
    // TODO: Confirm the real MBank admin-adjustment payload and response DTO.
    final created = await _client.adjustAccountBalance(
      accountId: accountId,
      delta: delta,
      title: title,
    );
    return _mapTransaction(created);
  }

  @override
  Future<DailySafeToSaveModel> fetchDailySafeToSave() async {
    final preview = await _client.getDailySafeToSave();
    return DailySafeToSaveModel(
      enabled: preview.enabled,
      suggestedAmount: preview.suggestedAmount,
      safeBalance: preview.safeBalance,
      currentBalance: preview.currentBalance,
      requiredPayments: preview.requiredPayments,
      lifeBuffer: preview.lifeBuffer,
      nextIncomeDate: preview.nextIncomeDate,
      daysToNextIncome: preview.daysToNextIncome,
      status: preview.status,
    );
  }

  @override
  Future<bool> getAutoDailySaveEnabled() {
    // TODO: Confirm where MBank stores the auto Safe-to-Save switch.
    return _client.getAutoDailySaveEnabled();
  }

  @override
  Future<void> setAutoDailySaveEnabled(bool enabled) {
    // TODO: Confirm the real MBank endpoint for auto Safe-to-Save.
    return _client.setAutoDailySaveEnabled(enabled);
  }

  @override
  Future<SimulateDayResponseModel> simulateDay() async {
    final response = await _client.simulateDay();
    return SimulateDayResponseModel(
      currentDate: response.currentDate,
      currentBalance: response.currentBalance,
      savingsBalance: response.savingsBalance,
      savedAmount: response.savedAmount,
      autoSaveExecuted: response.autoSaveExecuted,
      notification: response.notification,
    );
  }

  @override
  Future<List<ForecastPointModel>> fetchForecastPoints(int days) async {
    final dashboard = await _client.getDashboardData(days);
    return dashboard.points.map(_mapForecastPoint).toList();
  }

  AccountModel _mapAccount(ExistingMbankAccount account) {
    return AccountModel(
      id: account.id,
      // TODO: Confirm the preferred MBank account display name field.
      name: account.name.isEmpty ? 'Account ${account.id}' : account.name,
      // TODO: Align MBank account type vocabulary with the package enum-like strings.
      type: account.type.isEmpty ? 'MAIN' : account.type,
      balance: account.balance,
      currency: account.currencyCode.isEmpty ? 'KGS' : account.currencyCode,
    );
  }

  TransactionModel _mapTransaction(ExistingMbankTransaction transaction) {
    final occurredAt =
        transaction.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return TransactionModel(
      id: transaction.id,
      // TODO: Confirm whether MBank should display merchant or payment title first.
      title: transaction.title.isEmpty
          ? (transaction.counterparty.isEmpty
                ? 'Операция'
                : transaction.counterparty)
          : transaction.title,
      counterparty: transaction.counterparty,
      amount: transaction.amount,
      category: transaction.category.isEmpty
          ? 'Без категории'
          : transaction.category,
      iconKey: transaction.iconKey.isEmpty ? 'payment' : transaction.iconKey,
      type: transaction.type.isEmpty ? 'PAYMENT' : transaction.type,
      status: transaction.status.isEmpty ? 'COMPLETED' : transaction.status,
      accountName: transaction.accountName.isEmpty
          ? 'Основной счет'
          : transaction.accountName,
      occurredAt: occurredAt,
    );
  }

  ForecastPointModel _mapForecastPoint(ExistingMbankForecastPoint point) {
    final safeDate = point.date ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ForecastPointModel(
      dayOffset: point.dayOffset,
      isoDate: safeDate.toIso8601String(),
      label: point.label.isEmpty ? _formatPointLabel(safeDate) : point.label,
      balance: point.balance,
    );
  }

  ScheduledPaymentModel _mapScheduledPayment(
    ExistingMbankScheduledPayment payment,
  ) {
    final dueDate = payment.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ScheduledPaymentModel(
      id: payment.id,
      accountId: payment.accountId,
      accountName: payment.accountName.isEmpty
          ? 'Основной счет'
          : payment.accountName,
      title: payment.title.isEmpty ? 'Платеж' : payment.title,
      counterparty: payment.counterparty,
      category: payment.category.isEmpty ? 'Без категории' : payment.category,
      iconKey: payment.iconKey.isEmpty ? 'calendar' : payment.iconKey,
      amount: payment.amount,
      dueDate: dueDate,
      status: payment.status.isEmpty ? 'SCHEDULED' : payment.status,
      isReminder: payment.isReminder,
    );
  }

  SmartCategory _mapSmartCategory(ExistingMbankSmartCategory category) {
    return SmartCategory(
      id: category.id,
      // TODO: Confirm the smart budget DTO field names with the real MBank API.
      name: category.name.isEmpty ? 'Категория' : category.name,
      plannedMonthly: category.plannedMonthly,
      remaining: category.remaining,
      isFavorite: category.isFavorite,
    );
  }

  String _formatPointLabel(DateTime value) {
    const monthLabels = <String>[
      'янв.',
      'фев.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сен.',
      'окт.',
      'ноя.',
      'дек.',
    ];
    final month = monthLabels[value.month.clamp(1, 12) - 1];
    return '${value.day} $month';
  }
}

abstract class ExistingMbankClient {
  Future<List<ExistingMbankSubscription>> fetchSubscriptions();

  Future<void> cancelSubscription(String subscriptionId);

  Future<List<ExistingMbankAccount>> getAccounts();

  Future<List<ExistingMbankTransaction>> getTransactions();

  Future<ExistingMbankDashboardData> getDashboardData(int offsetDays);

  Future<ExistingMbankAiAnalysis> analyzeCashFlow(int offsetDays);

  Future<ExistingMbankActionExecution> executeAction(String actionToken);

  Future<ExistingMbankScheduledPayment> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  });

  Future<ExistingMbankScheduledPayment> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  });

  Future<void> deleteScheduledPayment(int paymentId);

  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  });

  Future<ExistingMbankTransaction> createTransaction({
    required int accountId,
    required String title,
    required String counterparty,
    required double amount,
    required String type,
    required String category,
    required String iconKey,
    String? smartCategoryId,
  });

  Future<List<ExistingMbankSmartCategory>> getSmartCategories();

  Future<ExistingMbankSmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  });

  Future<void> setSmartCategoryFavorite({
    required String categoryId,
    required bool isFavorite,
  });

  Future<void> deleteSmartCategory(String categoryId);

  Future<bool> getSmartListEnabled();

  Future<void> setSmartListEnabled(bool enabled);

  Future<bool> getAdminModeEnabled();

  Future<void> setAdminModeEnabled(bool enabled);

  Future<DateTime> getEffectiveDate();

  Future<void> setEffectiveDate(DateTime date);

  Future<ExistingMbankTransaction> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  });

  Future<ExistingMbankDailySafeToSave> getDailySafeToSave();

  Future<bool> getAutoDailySaveEnabled();

  Future<void> setAutoDailySaveEnabled(bool enabled);

  Future<ExistingMbankSimulateDayResponse> simulateDay();
}

class ExistingMbankSubscription {
  const ExistingMbankSubscription({
    required this.id,
    required this.displayName,
    required this.amount,
    required this.currencyCode,
    required this.status,
    this.nextChargeDate,
  });

  final String id;
  final String displayName;
  final double amount;
  final String currencyCode;
  final String status;
  final DateTime? nextChargeDate;

  factory ExistingMbankSubscription.fromJson(Map<String, dynamic> json) {
    return ExistingMbankSubscription(
      id: json['id']?.toString() ?? '',
      displayName:
          json['displayName'] as String? ??
          (json['title'] as String? ?? ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode:
          json['currencyCode'] as String? ??
          (json['currency'] as String? ?? ''),
      status: json['status'] as String? ?? 'UNKNOWN',
      nextChargeDate: _dateFromJson(json['nextChargeDate']),
    );
  }
}

class ExistingMbankAccount {
  const ExistingMbankAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currencyCode,
  });

  final int id;
  final String name;
  final String type;
  final double balance;
  final String currencyCode;

  factory ExistingMbankAccount.fromJson(Map<String, dynamic> json) {
    return ExistingMbankAccount(
      id: _intFromJson(json['id']),
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currencyCode:
          json['currencyCode'] as String? ??
          (json['currency'] as String? ?? ''),
    );
  }
}

class ExistingMbankTransaction {
  const ExistingMbankTransaction({
    required this.id,
    required this.title,
    required this.counterparty,
    required this.amount,
    required this.category,
    required this.iconKey,
    required this.type,
    required this.status,
    required this.accountName,
    required this.occurredAt,
  });

  final int id;
  final String title;
  final String counterparty;
  final double amount;
  final String category;
  final String iconKey;
  final String type;
  final String status;
  final String accountName;
  final DateTime? occurredAt;

  factory ExistingMbankTransaction.fromJson(Map<String, dynamic> json) {
    return ExistingMbankTransaction(
      id: _intFromJson(json['id']),
      title: json['title'] as String? ?? '',
      counterparty:
          json['counterparty'] as String? ??
          (json['merchant'] as String? ?? ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      occurredAt:
          _dateFromJson(json['occurredAt']) ?? _dateFromJson(json['date']),
    );
  }
}

class ExistingMbankDashboardData {
  const ExistingMbankDashboardData({
    required this.currentBalance,
    required this.savingsBalance,
    required this.minimumProjectedBalance,
    required this.horizonDays,
    required this.points,
    required this.scheduledPayments,
  });

  final double currentBalance;
  final double savingsBalance;
  final double? minimumProjectedBalance;
  final int? horizonDays;
  final List<ExistingMbankForecastPoint> points;
  final List<ExistingMbankScheduledPayment> scheduledPayments;

  factory ExistingMbankDashboardData.fromJson(Map<String, dynamic> json) {
    return ExistingMbankDashboardData(
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0.0,
      minimumProjectedBalance:
          (json['minimumProjectedBalance'] as num?)?.toDouble(),
      horizonDays: _nullableIntFromJson(json['horizonDays']),
      points: _listFromJson(
        json['points'],
        (item) => ExistingMbankForecastPoint.fromJson(item),
      ),
      scheduledPayments: _listFromJson(
        json['scheduledPayments'],
        (item) => ExistingMbankScheduledPayment.fromJson(item),
      ),
    );
  }
}

class ExistingMbankForecastPoint {
  const ExistingMbankForecastPoint({
    required this.dayOffset,
    required this.date,
    required this.label,
    required this.balance,
  });

  final int dayOffset;
  final DateTime? date;
  final String label;
  final double balance;

  factory ExistingMbankForecastPoint.fromJson(Map<String, dynamic> json) {
    return ExistingMbankForecastPoint(
      dayOffset: _intFromJson(json['dayOffset']),
      date: _dateFromJson(json['isoDate']) ?? _dateFromJson(json['date']),
      label: json['label'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExistingMbankAiAnalysis {
  const ExistingMbankAiAnalysis({
    required this.hasAlert,
    required this.message,
    required this.actionToken,
    required this.suggestions,
  });

  final bool hasAlert;
  final String message;
  final String? actionToken;
  final List<ExistingMbankBalanceSuggestion> suggestions;

  factory ExistingMbankAiAnalysis.fromJson(Map<String, dynamic> json) {
    return ExistingMbankAiAnalysis(
      hasAlert: json['hasAlert'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      actionToken: json['actionToken'] as String?,
      suggestions: _listFromJson(
        json['suggestions'],
        (item) => ExistingMbankBalanceSuggestion.fromJson(item),
      ),
    );
  }
}

class ExistingMbankBalanceSuggestion {
  const ExistingMbankBalanceSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.actionToken,
  });

  final String id;
  final String title;
  final String description;
  final String actionToken;

  factory ExistingMbankBalanceSuggestion.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExistingMbankBalanceSuggestion(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      actionToken: json['actionToken'] as String? ?? '',
    );
  }
}

class ExistingMbankActionExecution {
  const ExistingMbankActionExecution({
    required this.success,
    required this.message,
    required this.currentBalance,
    required this.savingsBalance,
  });

  final bool success;
  final String message;
  final double currentBalance;
  final double savingsBalance;

  factory ExistingMbankActionExecution.fromJson(Map<String, dynamic> json) {
    return ExistingMbankActionExecution(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExistingMbankScheduledPayment {
  const ExistingMbankScheduledPayment({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.title,
    required this.counterparty,
    required this.category,
    required this.iconKey,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.isReminder,
  });

  final int id;
  final int accountId;
  final String accountName;
  final String title;
  final String counterparty;
  final String category;
  final String iconKey;
  final double amount;
  final DateTime? dueDate;
  final String status;
  final bool isReminder;

  factory ExistingMbankScheduledPayment.fromJson(Map<String, dynamic> json) {
    return ExistingMbankScheduledPayment(
      id: _intFromJson(json['id']),
      accountId: _intFromJson(json['accountId']),
      accountName: json['accountName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      counterparty: json['counterparty'] as String? ?? '',
      category: json['category'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: _dateFromJson(json['dueDate']),
      status: json['status'] as String? ?? '',
      isReminder: json['isReminder'] as bool? ?? true,
    );
  }
}

class ExistingMbankSmartCategory {
  const ExistingMbankSmartCategory({
    required this.id,
    required this.name,
    required this.plannedMonthly,
    required this.remaining,
    required this.isFavorite,
  });

  final String id;
  final String name;
  final double plannedMonthly;
  final double remaining;
  final bool isFavorite;

  factory ExistingMbankSmartCategory.fromJson(Map<String, dynamic> json) {
    return ExistingMbankSmartCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      plannedMonthly: (json['plannedMonthly'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

class ExistingMbankDailySafeToSave {
  const ExistingMbankDailySafeToSave({
    required this.enabled,
    required this.suggestedAmount,
    required this.safeBalance,
    required this.currentBalance,
    required this.requiredPayments,
    required this.lifeBuffer,
    required this.nextIncomeDate,
    required this.daysToNextIncome,
    required this.status,
  });

  final bool enabled;
  final double suggestedAmount;
  final double safeBalance;
  final double currentBalance;
  final double requiredPayments;
  final double lifeBuffer;
  final DateTime? nextIncomeDate;
  final int daysToNextIncome;
  final String status;

  factory ExistingMbankDailySafeToSave.fromJson(Map<String, dynamic> json) {
    return ExistingMbankDailySafeToSave(
      enabled: json['enabled'] as bool? ?? false,
      suggestedAmount: (json['suggestedAmount'] as num?)?.toDouble() ?? 0.0,
      safeBalance: (json['safeBalance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      requiredPayments: (json['requiredPayments'] as num?)?.toDouble() ?? 0.0,
      lifeBuffer: (json['lifeBuffer'] as num?)?.toDouble() ?? 0.0,
      nextIncomeDate: _dateFromJson(json['nextIncomeDate']),
      daysToNextIncome: _intFromJson(json['daysToNextIncome']),
      status: json['status'] as String? ?? '',
    );
  }
}

class ExistingMbankSimulateDayResponse {
  const ExistingMbankSimulateDayResponse({
    required this.currentDate,
    required this.currentBalance,
    required this.savingsBalance,
    required this.savedAmount,
    required this.autoSaveExecuted,
    required this.notification,
  });

  final DateTime? currentDate;
  final double currentBalance;
  final double savingsBalance;
  final double savedAmount;
  final bool autoSaveExecuted;
  final String notification;

  factory ExistingMbankSimulateDayResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExistingMbankSimulateDayResponse(
      currentDate: _dateFromJson(json['currentDate']),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
      autoSaveExecuted: json['autoSaveExecuted'] as bool? ?? false,
      notification: json['notification'] as String? ?? '',
    );
  }
}

DateTime? _dateFromJson(Object? rawValue) {
  if (rawValue is DateTime) {
    return rawValue;
  }
  if (rawValue is String) {
    return DateTime.tryParse(rawValue);
  }
  return null;
}

int _intFromJson(Object? rawValue) {
  if (rawValue is int) {
    return rawValue;
  }
  if (rawValue is num) {
    return rawValue.toInt();
  }
  if (rawValue is String) {
    return int.tryParse(rawValue) ?? 0;
  }
  return 0;
}

int? _nullableIntFromJson(Object? rawValue) {
  if (rawValue == null) {
    return null;
  }
  return _intFromJson(rawValue);
}

List<T> _listFromJson<T>(
  Object? rawValue,
  T Function(Map<String, dynamic> json) builder,
) {
  if (rawValue is! List<dynamic>) {
    return <T>[];
  }
  return rawValue
      .whereType<Map<String, dynamic>>()
      .map(builder)
      .toList(growable: false);
}
