import 'package:m_bank_dashboard/m_bank_dashboard.dart'
    show
        DailySafeToSaveModel,
        SimulateDayResponseModel,
        SubscriptionModel;

import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_chat_reply_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';
import '../models/transfer_result_model.dart';
import 'api_client.dart';

class BankApiService {
  BankApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AccountModel>> fetchAccounts() async {
    final json = await _apiClient.getJson('/accounts') as List<dynamic>;
    return json
        .map((item) => AccountModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final json = await _apiClient.getJson('/transactions') as List<dynamic>;
    return json
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
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
          .toList(growable: false);
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

  Future<AiChatReplyModel> sendAiChatMessage({
    required List<Map<String, String>> history,
    required String newMessage,
  }) async {
    final json =
        await _apiClient.postJson(
              '/ai/chat',
              body: <String, dynamic>{
                'history': history,
                'newMessage': newMessage,
              },
            )
            as Map<String, dynamic>;
    return AiChatReplyModel.fromJson(json);
  }

  Future<List<Map<String, String>>> fetchAiChatHistory() async {
    final json = await _apiClient.getJson('/ai/chat/history');
    if (json is! List<dynamic>) {
      return const <Map<String, String>>[];
    }
    return json.map((item) {
      final message = item as Map<String, dynamic>;
      return <String, String>{
        'role': message['role'] as String? ?? 'assistant',
        'content': message['content'] as String? ?? '',
      };
    }).toList(growable: false);
  }

  Future<AiChatReplyModel> resolveAiChatAction({
    required String token,
    required bool confirmed,
  }) async {
    final json =
        await _apiClient.postJson(
              '/ai/chat/action',
              body: <String, dynamic>{
                'token': token,
                'confirmed': confirmed,
              },
            )
            as Map<String, dynamic>;
    return AiChatReplyModel.fromJson(json);
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

  Future<void> deleteScheduledPayment(int paymentId) async {
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
  }) {
    return createReminderScheduledPayment(
      accountId: accountId,
      title: title,
      counterparty: counterparty,
      category: category,
      amount: amount,
      dueDate: dueDate,
      isReminder: true,
    );
  }

  Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
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
                'dueDate': _toIsoDate(dueDate),
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
    await _apiClient.postJson(
      '/loans',
      body: <String, dynamic>{
        'accountId': accountId,
        'title': title,
        'amount': amount,
        'dueDate': _toIsoDate(dueDate),
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
    final json = await _apiClient.getJson('/smart-categories');
    if (json is! List<dynamic>) {
      return const <SmartCategory>[];
    }
    return json
        .map((item) => SmartCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
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

  Future<SmartCategory> createSmartCategoryFromTransaction({
    required int transactionId,
    required String name,
    required double plannedMonthly,
  }) async {
    final json =
        await _apiClient.postJson(
              '/smart-categories/link-transaction',
              body: <String, dynamic>{
                'transactionId': transactionId,
                'name': name,
                'plannedMonthly': plannedMonthly,
              },
            )
            as Map<String, dynamic>;
    return SmartCategory.fromJson(json);
  }

  Future<void> setSmartCategoryFavorite(
    String categoryId,
    bool isFavorite,
  ) async {
    await _apiClient.postJson(
      '/smart-categories/$categoryId/favorite',
      body: <String, dynamic>{'isFavorite': isFavorite},
    );
  }

  Future<void> deleteSmartCategory(String categoryId) async {
    await _apiClient.postJson(
      '/smart-categories/$categoryId/delete',
      body: <String, dynamic>{},
    );
  }

  Future<SmartCategory> updateSmartCategoryLimit({
    required String categoryId,
    required double plannedMonthly,
  }) async {
    final json =
        await _apiClient.postJson(
              '/smart-categories/$categoryId/limit',
              body: <String, dynamic>{'plannedMonthly': plannedMonthly},
            )
            as Map<String, dynamic>;
    return SmartCategory.fromJson(json);
  }

  Future<void> bulkCategorizeTransactions({
    required List<int> transactionIds,
    String? categoryId,
  }) async {
    await _apiClient.putJson(
      '/transactions/bulk-categorize',
      body: <String, dynamic>{
        'transactionIds': transactionIds,
        'categoryId': categoryId,
      },
    );
  }

  Future<bool> getSmartListEnabled() async {
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
    await _apiClient.postJson(
      '/smart-categories/settings',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<bool> getAdminModeEnabled() async {
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
    await _apiClient.postJson(
      '/demo/admin-mode',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<DateTime> getEffectiveDate() async {
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
    await _apiClient.postJson(
      '/demo/date',
      body: <String, dynamic>{'date': _toIsoDate(date)},
    );
  }

  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) async {
    final json =
        await _apiClient.postJson(
              '/demo/accounts/$accountId/adjust',
              body: <String, dynamic>{'delta': delta, 'title': title},
            )
            as Map<String, dynamic>;
    return TransactionModel.fromJson(json);
  }

  Future<DailySafeToSaveModel> fetchDailySafeToSave() async {
    final json =
        await _apiClient.getJson('/ai/daily-safe-to-save')
            as Map<String, dynamic>;
    return DailySafeToSaveModel.fromJson(json);
  }

  Future<bool> getAutoDailySaveEnabled() async {
    final json =
        await _apiClient.getJson('/ai/auto-daily-save')
            as Map<String, dynamic>;
    return json['enabled'] as bool? ?? false;
  }

  Future<void> setAutoDailySaveEnabled(bool enabled) async {
    await _apiClient.postJson(
      '/ai/auto-daily-save',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<SimulateDayResponseModel> simulateDay() async {
    final json =
        await _apiClient.postJson(
              '/demo/simulate-day',
              body: <String, dynamic>{},
            )
            as Map<String, dynamic>;
    return SimulateDayResponseModel.fromJson(json);
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
    String? category,
    String? iconKey,
    String? smartCategoryId,
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
                'category': category,
                'iconKey': iconKey,
                'smartCategoryId': smartCategoryId,
              },
            )
            as Map<String, dynamic>;
    return TransferResultModel.fromJson(json);
  }

  String _toIsoDate(DateTime value) {
    return value.toIso8601String().split('T').first;
  }
}
