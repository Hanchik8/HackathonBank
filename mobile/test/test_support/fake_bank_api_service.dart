import 'package:hackathon_bank_mobile/models/account_model.dart';
import 'package:hackathon_bank_mobile/models/ai_analysis_model.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/models/transaction_model.dart';
import 'package:hackathon_bank_mobile/models/transfer_result_model.dart';
import 'package:hackathon_bank_mobile/services/api_client.dart';
import 'package:hackathon_bank_mobile/services/bank_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NoopApiClient extends ApiClient {
  _NoopApiClient()
    : super(
        httpClient: MockClient(
          (http.Request request) async => http.Response('', 500),
        ),
      );

  @override
  Future<dynamic> getJson(String path) async {
    throw UnimplementedError('Fake service does not use ApiClient.getJson');
  }

  @override
  Future<dynamic> postJson(String path, {Object? body}) async {
    throw UnimplementedError('Fake service does not use ApiClient.postJson');
  }
}

DateTime _sampleTime() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 12, 9, 5);
}

List<AccountModel> sampleAccounts() {
  return const <AccountModel>[
    AccountModel(
      id: 1,
      name: 'Main',
      type: 'MAIN',
      balance: 15000,
      currency: 'KGS',
    ),
    AccountModel(
      id: 2,
      name: 'Savings',
      type: 'SAVINGS',
      balance: 50000,
      currency: 'KGS',
    ),
  ];
}

List<TransactionModel> sampleTransactions() {
  final occurredAt = _sampleTime();
  return <TransactionModel>[
    TransactionModel(
      id: 1,
      title: 'Продукты',
      counterparty: 'Green Market',
      amount: -3200,
      category: 'Еда',
      iconKey: 'food',
      type: 'PURCHASE',
      status: 'COMPLETED',
      accountName: 'Main',
      occurredAt: occurredAt,
    ),
    TransactionModel(
      id: 2,
      title: 'QR перевод',
      counterparty: 'Aigerim',
      amount: -1800,
      category: 'Переводы',
      iconKey: 'qr',
      type: 'QR_TRANSFER',
      status: 'COMPLETED',
      accountName: 'Main',
      occurredAt: occurredAt.subtract(const Duration(hours: 3)),
    ),
    TransactionModel(
      id: 3,
      title: 'Зарплата',
      counterparty: 'Tech Corp',
      amount: 23000,
      category: 'Поступления',
      iconKey: 'income',
      type: 'INCOME',
      status: 'COMPLETED',
      accountName: 'Main',
      occurredAt: occurredAt.subtract(const Duration(days: 1)),
    ),
  ];
}

List<ScheduledPaymentModel> sampleScheduledPayments() {
  final today = DateTime.now();
  return <ScheduledPaymentModel>[
    ScheduledPaymentModel(
      id: 10,
      accountId: 1,
      accountName: 'Main',
      title: 'Аренда',
      counterparty: 'Landlord',
      category: 'Аренда',
      iconKey: 'home',
      amount: 25000,
      dueDate: today.add(const Duration(days: 4)),
      status: 'SCHEDULED',
    ),
    ScheduledPaymentModel(
      id: 11,
      accountId: 1,
      accountName: 'Main',
      title: 'Интернет',
      counterparty: 'HomeNet',
      category: 'Подписки',
      iconKey: 'subscription',
      amount: 3900,
      dueDate: today.add(const Duration(days: 6)),
      status: 'SCHEDULED',
    ),
  ];
}

AiDashboardModel sampleDashboard([
  List<ScheduledPaymentModel>? scheduledPayments,
]) {
  final today = DateTime.now();
  final payments = scheduledPayments ?? sampleScheduledPayments();
  return AiDashboardModel(
    currentBalance: 15000,
    savingsBalance: 50000,
    minimumProjectedBalance: -10000,
    horizonDays: 10,
    points: List<ForecastPointModel>.generate(
      11,
      (int index) => ForecastPointModel(
        dayOffset: index,
        isoDate: today.add(Duration(days: index)).toIso8601String(),
        label: 'Д$index',
        balance: 15000 - (index * 2500),
      ),
    ),
    scheduledPayments: payments,
  );
}

AiAnalysisModel sampleAnalysis() {
  return const AiAnalysisModel(
    hasAlert: true,
    message: 'Перевести 10000 KGS со счета сбережений.',
    actionToken: 'action-1',
  );
}

AiExecutionModel sampleExecution() {
  return const AiExecutionModel(
    success: true,
    message: 'Перевод выполнен.',
    currentBalance: 25000,
    savingsBalance: 40000,
  );
}

TransferResultModel sampleTransferResult() {
  return TransferResultModel(
    message: 'Перевод пользователю Aigerim на 1500.0 KGS выполнен.',
    fromAccount: sampleAccounts().first,
    recipientType: 'USER',
    recipientName: 'Aigerim',
    amount: 1500,
  );
}

TransferResultModel sampleInternalTransferResult() {
  final accounts = sampleAccounts();
  return TransferResultModel(
    message: 'Перевод между счетами выполнен.',
    fromAccount: accounts.first,
    toAccount: accounts.last,
    amount: 2500,
  );
}

class FakeBankApiService extends BankApiService {
  FakeBankApiService({
    List<AccountModel>? accounts,
    List<TransactionModel>? transactions,
    AiDashboardModel? dashboard,
    AiAnalysisModel? analysis,
    AiExecutionModel? execution,
    TransferResultModel? transferResult,
    TransferResultModel? internalTransferResult,
  }) : _accounts = accounts ?? sampleAccounts(),
       _transactions = transactions ?? sampleTransactions(),
       _analysis = analysis ?? sampleAnalysis(),
       _execution = execution ?? sampleExecution(),
       _transferResult = transferResult ?? sampleTransferResult(),
       _internalTransferResult =
           internalTransferResult ?? sampleInternalTransferResult(),
       _scheduledPayments = List<ScheduledPaymentModel>.from(
         (dashboard ?? sampleDashboard()).scheduledPayments,
       ),
       _dashboardTemplate = dashboard ?? sampleDashboard(),
       super(apiClient: _NoopApiClient());

  final List<AccountModel> _accounts;
  final List<TransactionModel> _transactions;
  final AiDashboardModel _dashboardTemplate;
  final AiAnalysisModel _analysis;
  final AiExecutionModel _execution;
  final TransferResultModel _transferResult;
  final TransferResultModel _internalTransferResult;
  final List<ScheduledPaymentModel> _scheduledPayments;

  final List<int> dashboardRequests = <int>[];
  final List<int> analyzeRequests = <int>[];
  int executeCalls = 0;
  String? lastActionToken;
  int internalTransferCalls = 0;
  Map<String, Object?>? lastInternalTransfer;
  int externalTransferCalls = 0;
  Map<String, Object?>? lastExternalTransfer;
  int createScheduledPaymentCalls = 0;
  Map<String, Object?>? lastScheduledPaymentDraft;

  @override
  Future<List<AccountModel>> fetchAccounts() async => _accounts;

  @override
  Future<List<TransactionModel>> fetchTransactions() async => _transactions;

  @override
  Future<AiDashboardModel> fetchDashboard(int offsetDays) async {
    dashboardRequests.add(offsetDays);
    final sortedPayments = List<ScheduledPaymentModel>.from(_scheduledPayments)
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    return _dashboardTemplate.copyWith(scheduledPayments: sortedPayments);
  }

  @override
  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) async {
    analyzeRequests.add(offsetDays);
    return _analysis;
  }

  @override
  Future<AiExecutionModel> executeAction(String actionToken) async {
    executeCalls += 1;
    lastActionToken = actionToken;
    return _execution;
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
    createScheduledPaymentCalls += 1;
    lastScheduledPaymentDraft = <String, Object?>{
      'accountId': accountId,
      'title': title,
      'counterparty': counterparty,
      'category': category,
      'amount': amount,
      'dueDate': dueDate,
    };
    final account = _accounts.firstWhere((item) => item.id == accountId);
    final payment = ScheduledPaymentModel(
      id: 100 + createScheduledPaymentCalls,
      accountId: accountId,
      accountName: account.name,
      title: title,
      counterparty: counterparty,
      category: category,
      iconKey: 'calendar',
      amount: amount,
      dueDate: dueDate,
      status: 'SCHEDULED',
    );
    _scheduledPayments.add(payment);
    _scheduledPayments.sort(
      (left, right) => left.dueDate.compareTo(right.dueDate),
    );
    return payment;
  }

  @override
  Future<TransferResultModel> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? description,
  }) async {
    internalTransferCalls += 1;
    lastInternalTransfer = <String, Object?>{
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'description': description,
    };
    return _internalTransferResult;
  }

  @override
  Future<TransferResultModel> transferToRecipient({
    required int fromAccountId,
    required String recipientType,
    required String recipientName,
    required double amount,
    String? description,
  }) async {
    externalTransferCalls += 1;
    lastExternalTransfer = <String, Object?>{
      'fromAccountId': fromAccountId,
      'recipientType': recipientType,
      'recipientName': recipientName,
      'amount': amount,
      'description': description,
    };
    return _transferResult;
  }
}
