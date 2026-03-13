import 'package:flutter/foundation.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart' show SubscriptionModel;

import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/transaction_model.dart';
import '../models/transfer_result_model.dart';
import 'api_client.dart';
import 'mock_data_provider.dart';

class BankApiService {
  BankApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AccountModel>> fetchAccounts() async {
    final accounts = await _fetchAccountsFromApi();
    if (kDebugMode) {
      return MockDataProvider.applyLoanOverlayToAccounts(accounts);
    }
    return accounts;
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final transactions = await _fetchTransactionsFromApi();
    if (kDebugMode) {
      final accounts = await _fetchAccountsFromApi();
      return MockDataProvider.applyLoanOverlayToTransactions(
        transactions,
        accounts,
      );
    }
    return transactions;
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
      final accounts = await _fetchAccountsFromApi();
      final transactions = await _fetchTransactionsFromApi();
      try {
        final json =
            await _apiClient.getJson('/ai/dashboard?offsetDays=$offsetDays')
                as Map<String, dynamic>;
        final baseDashboard = AiDashboardModel.fromJson(json);
        return MockDataProvider.computeDashboard(
          accounts: accounts,
          transactions: transactions,
          offsetDays: offsetDays,
          baseDashboard: baseDashboard,
        );
      } on ApiException catch (_) {
        return MockDataProvider.computeDashboard(
          accounts: accounts,
          transactions: transactions,
          offsetDays: offsetDays,
        );
      }
    }

    final json =
        await _apiClient.getJson('/ai/dashboard?offsetDays=$offsetDays')
            as Map<String, dynamic>;
    return AiDashboardModel.fromJson(json);
  }

  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) async {
    final json =
        await _apiClient.postJson(
              '/ai/analyze',
              body: <String, dynamic>{'offsetDays': offsetDays},
            )
            as Map<String, dynamic>;
    return AiAnalysisModel.fromJson(json);
  }

  Future<AiExecutionModel> executeAction(String actionToken) async {
    final json =
        await _apiClient.postJson(
              '/ai/execute',
              body: <String, dynamic>{'actionToken': actionToken},
            )
            as Map<String, dynamic>;
    return AiExecutionModel.fromJson(json);
  }

  Future<ScheduledPaymentModel> createScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) async {
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
      final accounts = await _fetchAccountsFromApi();
      await MockDataProvider.createLoan(
        accountId: accountId,
        title: title,
        amount: amount,
        dueDate: dueDate,
        accounts: accounts,
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
}
