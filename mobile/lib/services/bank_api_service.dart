import 'package:flutter/foundation.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart' show SubscriptionModel;

import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/save_suggestion_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';
import '../models/transfer_result_model.dart';
import 'api_client.dart';
import 'mock_data_provider.dart';

class BankApiService {
  BankApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AccountModel>> fetchAccounts() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.accounts;
    }
    return _fetchAccountsFromApi();
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.transactions;
    }
    return _fetchTransactionsFromApi();
  }

  Future<List<SubscriptionModel>> fetchSubscriptions() async {
    try {
      final json = await _apiClient.getJson('/subscriptions');
      if (json is! List<dynamic>) {
        return const <SubscriptionModel>[];
      }
      return json
          .map(
            (item) => SubscriptionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on ApiException catch (error) {
      // NOTE: endpoint may be absent in backend.
      if (error.statusCode == 404 || error.statusCode == 405) {
        return const <SubscriptionModel>[];
      }
      rethrow;
    }
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    await _apiClient.postJson(
      '/subscriptions/$subscriptionId/cancel',
      body: <String, dynamic>{},
    );
  }

  Future<AiDashboardModel> fetchDashboard(int offsetDays) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.computeDashboard(offsetDays);
    }

    final json =
        await _apiClient.getJson('/ai/dashboard?offsetDays=$offsetDays')
            as Map<String, dynamic>;
    return AiDashboardModel.fromJson(json);
  }

  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.computeBalanceAdvice(
        horizonDays: MockDataProvider.daysUntilEndOfMonth(),
      );
    }

    final json =
        await _apiClient.postJson(
              '/ai/analyze',
              body: <String, dynamic>{'offsetDays': offsetDays},
            )
            as Map<String, dynamic>;
    return AiAnalysisModel.fromJson(json);
  }

  Future<AiExecutionModel> executeAction(String actionToken) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.executeAction(actionToken);
    }

    final json =
        await _apiClient.postJson(
              '/ai/execute',
              body: <String, dynamic>{'actionToken': actionToken},
            )
            as Map<String, dynamic>;
    return AiExecutionModel.fromJson(json);
  }

  Future<void> deleteScheduledPayment(int paymentId) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.deleteScheduledPayment(paymentId);
      return;
    }

    await _apiClient.postJson(
      '/scheduled-payments/$paymentId/delete',
      body: <String, dynamic>{},
    );
  }

  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) => createReminderScheduledPayment(
    accountId: accountId,
    title: title,
    counterparty: counterparty,
    category: category,
    amount: amount,
    dueDate: dueDate,
    isReminder: true,
  );

  Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.createReminderScheduledPayment(
        accountId: accountId,
        title: title,
        counterparty: counterparty,
        category: category,
        amount: amount,
        dueDate: dueDate,
        isReminder: isReminder,
      );
    }

    final json =
        await _apiClient.postJson(
              '/scheduled-payments',
              body: <String, dynamic>{
                'accountId': accountId,
                'title': title,
                'counterparty': counterparty,
                'category': category,
                'amount': amount,
                'dueDate': dueDate.toIso8601String().split('T').first,
                'isReminder': isReminder,
              },
            )
            as Map<String, dynamic>;
    return ScheduledPaymentModel.fromJson(json);
  }

  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.createLoan(
        accountId: accountId,
        title: title,
        amount: amount,
        dueDate: dueDate,
      );
      return;
    }

    await _apiClient.postJson(
      '/loans',
      body: <String, dynamic>{
        'accountId': accountId,
        'title': title,
        'amount': amount,
        'dueDate': dueDate.toIso8601String().split('T').first,
      },
    );
  }

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
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.createTransaction(
        accountId: accountId,
        title: title,
        counterparty: counterparty,
        amount: amount,
        type: type,
        category: category,
        iconKey: iconKey,
        smartCategoryId: smartCategoryId,
      );
    }

    final json =
        await _apiClient.postJson(
              '/transactions',
              body: <String, dynamic>{
                'accountId': accountId,
                'title': title,
                'counterparty': counterparty,
                'amount': amount,
                'type': type,
                'category': category,
                'iconKey': iconKey,
                'smartCategoryId': smartCategoryId,
              },
            )
            as Map<String, dynamic>;
    return TransactionModel.fromJson(json);
  }

  Future<List<SmartCategory>> fetchSmartCategories() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.smartListEnabled
          ? _visibleSmartCategories()
          : const <SmartCategory>[];
    }

    final json = await _apiClient.getJson('/smart-categories');
    if (json is! List<dynamic>) {
      return const <SmartCategory>[];
    }
    return json
        .map((item) => SmartCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.createSmartCategory(
        name: name,
        plannedMonthly: plannedMonthly,
      );
    }

    final json =
        await _apiClient.postJson(
              '/smart-categories',
              body: <String, dynamic>{
                'name': name,
                'plannedMonthly': plannedMonthly,
              },
            )
            as Map<String, dynamic>;
    return SmartCategory.fromJson(json);
  }

  Future<void> deleteSmartCategory(String categoryId) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.deleteSmartCategory(categoryId);
      return;
    }

    await _apiClient.postJson(
      '/smart-categories/$categoryId/delete',
      body: <String, dynamic>{},
    );
  }

  Future<bool> getSmartListEnabled() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.smartListEnabled;
    }

    try {
      final json =
          await _apiClient.getJson('/smart-categories/settings')
              as Map<String, dynamic>;
      return json['enabled'] as bool? ?? true;
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        return true;
      }
      rethrow;
    }
  }

  Future<void> setSmartListEnabled(bool enabled) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.setSmartListEnabled(enabled);
      return;
    }

    await _apiClient.postJson(
      '/smart-categories/settings',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<bool> getAdminModeEnabled() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.adminModeEnabled;
    }

    try {
      final json =
          await _apiClient.getJson('/demo/admin-mode') as Map<String, dynamic>;
      return json['enabled'] as bool? ?? false;
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> setAdminModeEnabled(bool enabled) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.setAdminModeEnabled(enabled);
      return;
    }

    await _apiClient.postJson(
      '/demo/admin-mode',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<DateTime> getEffectiveDate() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.effectiveDate;
    }

    try {
      final json = await _apiClient.getJson('/demo/date') as Map<String, dynamic>;
      return DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        return DateTime.now();
      }
      rethrow;
    }
  }

  Future<void> setEffectiveDate(DateTime date) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      await MockDataProvider.setEffectiveDate(date);
      return;
    }

    await _apiClient.postJson(
      '/demo/date',
      body: <String, dynamic>{
        'date': date.toIso8601String().split('T').first,
      },
    );
  }

  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.adjustAccountBalance(
        accountId: accountId,
        delta: delta,
        title: title,
      );
    }

    final json =
        await _apiClient.postJson(
              '/demo/accounts/$accountId/adjust',
              body: <String, dynamic>{
                'delta': delta,
                'title': title,
              },
            )
            as Map<String, dynamic>;
    return TransactionModel.fromJson(json);
  }

  Future<SaveSuggestionModel> suggestEndOfMonthSave() async {
    if (kDebugMode) {
      await _ensureMockDataInitialized();
      return MockDataProvider.computeSuggestedSave();
    }

    final json =
        await _apiClient.getJson('/ai/save-suggestion') as Map<String, dynamic>;
    return SaveSuggestionModel.fromJson(json);
  }

  Future<List<AccountModel>> _fetchAccountsFromApi() async {
    final json = await _apiClient.getJson('/accounts') as List<dynamic>;
    return json
        .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionModel>> _fetchTransactionsFromApi() async {
    final json = await _apiClient.getJson('/transactions') as List<dynamic>;
    return json
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _ensureMockDataInitialized() async {
    if (MockDataProvider.isInitialized) {
      return;
    }

    final accounts = await _fetchAccountsFromApi();
    final transactions = await _fetchTransactionsFromApi();
    List<ScheduledPaymentModel> scheduledPayments =
        const <ScheduledPaymentModel>[];
    try {
      final json =
          await _apiClient.getJson(
                '/ai/dashboard?offsetDays=${_daysUntilEndOfMonth()}',
              )
              as Map<String, dynamic>;
      scheduledPayments = AiDashboardModel.fromJson(json).scheduledPayments;
    } catch (_) {
      scheduledPayments = const <ScheduledPaymentModel>[];
    }

    MockDataProvider.initDemoData(
      accounts: accounts,
      transactions: transactions,
      scheduledPayments: scheduledPayments,
    );
  }

  int _daysUntilEndOfMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    return monthEnd.difference(today).inDays;
  }

  Future<TransferResultModel> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? description,
  }) async {
    final json =
        await _apiClient.postJson(
              '/transfer',
              body: <String, dynamic>{
                'fromAccountId': fromAccountId,
                'toAccountId': toAccountId,
                'amount': amount,
                'description': description,
              },
            )
            as Map<String, dynamic>;
    return TransferResultModel.fromJson(json);
  }

  Future<TransferResultModel> transferToRecipient({
    required int fromAccountId,
    required String recipientType,
    required String recipientName,
    required double amount,
    String? description,
  }) async {
    final json =
        await _apiClient.postJson(
              '/transfer/external',
              body: <String, dynamic>{
                'fromAccountId': fromAccountId,
                'recipientType': recipientType,
                'recipientName': recipientName,
                'amount': amount,
                'description': description,
              },
            )
            as Map<String, dynamic>;
    return TransferResultModel.fromJson(json);
  }

  List<SmartCategory> _visibleSmartCategories() {
    return MockDataProvider.smartCategories
        .where((category) => category.id.startsWith('smart-'))
        .toList(growable: false);
  }

  // ignore: unused_element
  SaveSuggestionModel _computeDebugSaveSuggestion() {
    final trackedAccount = MockDataProvider.accounts.firstWhere(
      (account) => account.type == 'MAIN',
      orElse: () => MockDataProvider.accounts.first,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final scheduledOutflow = MockDataProvider.scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .where((payment) => !payment.dueDate.isAfter(monthEnd))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
    final reservedByBudgets = MockDataProvider.smartListEnabled
        ? _visibleSmartCategories().fold<double>(
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
        ? 'До конца месяца свободного остатка нет: оставьте деньги на платежи и обязательные траты.'
        : 'Можно безопасно отложить часть остатка: ближайшие списания и лимиты ваших smart-категорий уже учтены.';

    return SaveSuggestionModel(
      amount: suggestionAmount,
      reason: reason,
      safetyReserve: safetyReserve,
    );
  }
}
