import 'package:m_bank_dashboard/m_bank_dashboard.dart';

import 'bank_api_service.dart';

class BankApiDashboardRepository implements DashboardRepository {
  BankApiDashboardRepository({required BankApiService apiService})
    : _apiService = apiService;

  final BankApiService _apiService;

  @override
  Future<List<AccountModel>> fetchAccounts() => _apiService.fetchAccounts();

  @override
  Future<List<TransactionModel>> fetchTransactions() =>
      _apiService.fetchTransactions();

  @override
  Future<AiDashboardModel> fetchDashboard(int offsetDays) =>
      _apiService.fetchDashboard(offsetDays);

  @override
  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) =>
      _apiService.analyzeCashFlow(offsetDays);

  @override
  Future<AiExecutionModel> executeAction(String actionToken) =>
      _apiService.executeAction(actionToken);

  @override
  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) => _apiService.createScheduledPayment(
    accountId: accountId,
    title: title,
    counterparty: counterparty,
    category: category,
    amount: amount,
    dueDate: dueDate,
  );

  @override
  Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) => _apiService.createReminderScheduledPayment(
    accountId: accountId,
    title: title,
    counterparty: counterparty,
    category: category,
    amount: amount,
    dueDate: dueDate,
    isReminder: isReminder,
  );

  @override
  Future<void> deleteScheduledPayment(int paymentId) =>
      _apiService.deleteScheduledPayment(paymentId);

  @override
  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) => _apiService.createLoan(
    accountId: accountId,
    title: title,
    amount: amount,
    dueDate: dueDate,
  );

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
  }) => _apiService.createTransaction(
    accountId: accountId,
    title: title,
    counterparty: counterparty,
    amount: amount,
    type: type,
    category: category,
    iconKey: iconKey,
    smartCategoryId: smartCategoryId,
  );

  @override
  Future<List<SmartCategory>> fetchSmartCategories() =>
      _apiService.fetchSmartCategories();

  @override
  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) => _apiService.createSmartCategory(
    name: name,
    plannedMonthly: plannedMonthly,
  );

  @override
  Future<void> setSmartCategoryFavorite(String categoryId, bool isFavorite) =>
      _apiService.setSmartCategoryFavorite(categoryId, isFavorite);

  @override
  Future<void> deleteSmartCategory(String categoryId) =>
      _apiService.deleteSmartCategory(categoryId);

  @override
  Future<bool> getSmartListEnabled() => _apiService.getSmartListEnabled();

  @override
  Future<void> setSmartListEnabled(bool enabled) =>
      _apiService.setSmartListEnabled(enabled);

  @override
  Future<bool> getAdminModeEnabled() => _apiService.getAdminModeEnabled();

  @override
  Future<void> setAdminModeEnabled(bool enabled) =>
      _apiService.setAdminModeEnabled(enabled);

  @override
  Future<DateTime> getEffectiveDate() => _apiService.getEffectiveDate();

  @override
  Future<void> setEffectiveDate(DateTime date) =>
      _apiService.setEffectiveDate(date);

  @override
  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) => _apiService.adjustAccountBalance(
    accountId: accountId,
    delta: delta,
    title: title,
  );

  @override
  Future<DailySafeToSaveModel> fetchDailySafeToSave() =>
      _apiService.fetchDailySafeToSave();

  @override
  Future<bool> getAutoDailySaveEnabled() => _apiService.getAutoDailySaveEnabled();

  @override
  Future<void> setAutoDailySaveEnabled(bool enabled) =>
      _apiService.setAutoDailySaveEnabled(enabled);

  @override
  Future<SimulateDayResponseModel> simulateDay() => _apiService.simulateDay();

  @override
  Future<List<SubscriptionModel>> fetchSubscriptions() =>
      _apiService.fetchSubscriptions();

  @override
  Future<void> cancelSubscription(String subscriptionId) =>
      _apiService.cancelSubscription(subscriptionId);

  @override
  Future<List<ForecastPointModel>> fetchForecastPoints(int days) async {
    final dashboard = await _apiService.fetchDashboard(days);
    return dashboard.points;
  }
}
