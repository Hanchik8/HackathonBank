import '../models/account_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_dashboard_model.dart';
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
        .toList();
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final json = await _apiClient.getJson('/transactions') as List<dynamic>;
    return json
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AiDashboardModel> fetchDashboard(int offsetDays) async {
    final json =
        await _apiClient.getJson('/ai/dashboard?offsetDays=$offsetDays')
            as Map<String, dynamic>;
    return AiDashboardModel.fromJson(json);
  }

  Future<AiAnalysisModel> analyzeCashFlow() async {
    final json =
        await _apiClient.postJson('/ai/analyze') as Map<String, dynamic>;
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
