import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/scheduled_payment_model.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';

abstract class DashboardRepository {
  Future<List<AccountModel>> fetchAccounts();

  Future<List<TransactionModel>> fetchTransactions();

  Future<AiDashboardModel> fetchDashboard(int offsetDays);

  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays);

  Future<AiExecutionModel> executeAction(String actionToken);

  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  });

  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  });

  Future<List<SubscriptionModel>> fetchSubscriptions();

  Future<void> cancelSubscription(String subscriptionId);
}
