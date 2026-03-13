import '../contracts/dashboard_repository.dart';
import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/scheduled_payment_model.dart';
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
  Future<List<AccountModel>> fetchAccounts() {
    // TODO: Map the existing MBank account DTOs to AccountModel.
    throw UnimplementedError('Map MBank accounts to AccountModel.');
  }

  @override
  Future<List<TransactionModel>> fetchTransactions() {
    // TODO: Map the existing MBank transaction DTOs to TransactionModel.
    throw UnimplementedError('Map MBank transactions to TransactionModel.');
  }

  @override
  Future<AiDashboardModel> fetchDashboard(int offsetDays) {
    // TODO: Compose dashboard data from MBank balances, future payments, and forecast services.
    throw UnimplementedError('Compose MBank dashboard data.');
  }

  @override
  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) {
    // TODO: Connect MBank AI analysis or orchestration layer.
    throw UnimplementedError('Connect MBank AI analysis.');
  }

  @override
  Future<AiExecutionModel> executeAction(String actionToken) {
    // TODO: Route AI actions to the MBank automation layer.
    throw UnimplementedError('Connect MBank AI action execution.');
  }

  @override
  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) {
    // TODO: Map deferred payment creation to the MBank payments API.
    throw UnimplementedError('Connect MBank deferred payment creation.');
  }
}

abstract class ExistingMbankClient {
  Future<List<ExistingMbankSubscription>> fetchSubscriptions();

  Future<void> cancelSubscription(String subscriptionId);
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
}
