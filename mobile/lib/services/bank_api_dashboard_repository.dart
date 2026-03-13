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
  }) {
    return _apiService.createScheduledPayment(
      accountId: accountId,
      title: title,
      counterparty: counterparty,
      category: category,
      amount: amount,
      dueDate: dueDate,
    );
  }

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
  Future<List<SubscriptionModel>> fetchSubscriptions() =>
      _apiService.fetchSubscriptions();

  @override
  Future<void> cancelSubscription(String subscriptionId) =>
      _apiService.cancelSubscription(subscriptionId);
}
