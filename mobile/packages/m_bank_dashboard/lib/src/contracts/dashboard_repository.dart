import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/scheduled_payment_model.dart';
import '../models/save_suggestion_model.dart';
import '../models/smart_category_model.dart';
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

  Future<ScheduledPaymentModel> createReminderScheduledPayment({
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

  Future<TransactionModel> createTransaction({
    required int accountId,
    required String title,
    required String counterparty,
    required double amount,
    required String type,
    required String category,
    required String iconKey,
    String? smartCategoryId,
  });

  Future<List<SmartCategory>> fetchSmartCategories();

  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  });

  Future<void> setSmartCategoryFavorite(String categoryId, bool isFavorite);

  Future<void> deleteSmartCategory(String categoryId);

  Future<bool> getSmartListEnabled();

  Future<void> setSmartListEnabled(bool enabled);

  Future<bool> getAdminModeEnabled();

  Future<void> setAdminModeEnabled(bool enabled);

  Future<DateTime> getEffectiveDate();

  Future<void> setEffectiveDate(DateTime date);

  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  });

  Future<SaveSuggestionModel> suggestEndOfMonthSave();

  Future<List<SubscriptionModel>> fetchSubscriptions();

  Future<void> cancelSubscription(String subscriptionId);
}
