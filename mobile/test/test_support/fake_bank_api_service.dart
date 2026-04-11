import 'package:hackathon_bank_mobile/models/account_model.dart';
import 'package:hackathon_bank_mobile/models/ai_analysis_model.dart';
import 'package:hackathon_bank_mobile/models/ai_chat_reply_model.dart';
import 'package:hackathon_bank_mobile/models/ai_dashboard_model.dart';
import 'package:hackathon_bank_mobile/models/daily_safe_to_save_model.dart';
import 'package:hackathon_bank_mobile/models/simulate_day_response_model.dart';
import 'package:hackathon_bank_mobile/models/smart_category_model.dart';
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
      title: 'РџСЂРѕРґСѓРєС‚С‹',
      counterparty: 'Green Market',
      amount: -3200,
      category: 'Р•РґР°',
      iconKey: 'food',
      type: 'PURCHASE',
      status: 'COMPLETED',
      accountName: 'Main',
      occurredAt: occurredAt,
    ),
    TransactionModel(
      id: 2,
      title: 'QR РїРµСЂРµРІРѕРґ',
      counterparty: 'Aigerim',
      amount: -1800,
      category: 'РџРµСЂРµРІРѕРґС‹',
      iconKey: 'qr',
      type: 'QR_TRANSFER',
      status: 'COMPLETED',
      accountName: 'Main',
      occurredAt: occurredAt.subtract(const Duration(hours: 3)),
    ),
    TransactionModel(
      id: 3,
      title: 'Р—Р°СЂРїР»Р°С‚Р°',
      counterparty: 'Tech Corp',
      amount: 23000,
      category: 'РџРѕСЃС‚СѓРїР»РµРЅРёСЏ',
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
      title: 'РђСЂРµРЅРґР°',
      counterparty: 'Landlord',
      category: 'РђСЂРµРЅРґР°',
      iconKey: 'home',
      amount: 25000,
      dueDate: today.add(const Duration(days: 4)),
      status: 'SCHEDULED',
      isReminder: true,
    ),
    ScheduledPaymentModel(
      id: 11,
      accountId: 1,
      accountName: 'Main',
      title: 'РРЅС‚РµСЂРЅРµС‚',
      counterparty: 'HomeNet',
      category: 'РџРѕРґРїРёСЃРєРё',
      iconKey: 'subscription',
      amount: 3900,
      dueDate: today.add(const Duration(days: 6)),
      status: 'SCHEDULED',
      isReminder: true,
    ),
  ];
}

List<SmartCategory> sampleSmartCategories() {
  return const <SmartCategory>[
    SmartCategory(
      id: 'food',
      name: 'Р•РґР°',
      plannedMonthly: 12000,
      remaining: 8800,
      isFavorite: true,
    ),
    SmartCategory(
      id: 'transfer',
      name: 'РџРµСЂРµРІРѕРґС‹',
      plannedMonthly: 9000,
      remaining: 7500,
      isFavorite: false,
    ),
  ];
}

DailySafeToSaveModel sampleDailySafeToSave() {
  return DailySafeToSaveModel(
    enabled: true,
    suggestedAmount: 1200,
    safeBalance: 10800,
    currentBalance: 15000,
    requiredPayments: 3200,
    lifeBuffer: 3000,
    nextIncomeDate: DateTime.now().add(const Duration(days: 8)),
    daysToNextIncome: 8,
    status: 'OK',
  );
}

SimulateDayResponseModel sampleSimulateDayResponse() {
  final now = DateTime.now();
  return SimulateDayResponseModel(
    currentDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    currentBalance: 13800,
    savingsBalance: 51200,
    savedAmount: 1200,
    autoSaveExecuted: true,
    notification: 'Safe-to-Save РІС‹РїРѕР»РЅРёР» РїРµСЂРµРІРѕРґ 1 200 KGS.',
  );
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
        label: 'Р”$index',
        balance: 15000 - (index * 2500),
      ),
    ),
    scheduledPayments: payments,
  );
}

AiExecutionModel sampleExecution() {
  return const AiExecutionModel(
    success: true,
    message: 'РџРµСЂРµРІРѕРґ РІС‹РїРѕР»РЅРµРЅ.',
    currentBalance: 25000,
    savingsBalance: 40000,
  );
}

TransferResultModel sampleTransferResult() {
  return TransferResultModel(
    message: 'РџРµСЂРµРІРѕРґ РїРѕР»СЊР·РѕРІР°С‚РµР»СЋ Aigerim РЅР° 1500.0 KGS РІС‹РїРѕР»РЅРµРЅ.',
    fromAccount: sampleAccounts().first,
    recipientType: 'USER',
    recipientName: 'Aigerim',
    amount: 1500,
  );
}

TransferResultModel sampleInternalTransferResult() {
  final accounts = sampleAccounts();
  return TransferResultModel(
    message: 'РџРµСЂРµРІРѕРґ РјРµР¶РґСѓ СЃС‡РµС‚Р°РјРё РІС‹РїРѕР»РЅРµРЅ.',
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
    List<SmartCategory>? smartCategories,
    DailySafeToSaveModel? dailySafeToSave,
    TransferResultModel? transferResult,
    TransferResultModel? internalTransferResult,
  }) : _accounts =
           accounts?.map(_copyAccount).toList() ??
           sampleAccounts().map(_copyAccount).toList(),
       _transactions =
           transactions?.map(_copyTransaction).toList() ??
           sampleTransactions().map(_copyTransaction).toList(),
       _analysisOverride = analysis,
       _executionFallback = execution ?? sampleExecution(),
       _smartCategories = List<SmartCategory>.from(
         smartCategories ?? sampleSmartCategories(),
       ),
       _dailySafeToSaveTemplate = dailySafeToSave ?? sampleDailySafeToSave(),
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
  final List<SmartCategory> _smartCategories;
  final AiDashboardModel _dashboardTemplate;
  final AiAnalysisModel? _analysisOverride;
  final AiExecutionModel _executionFallback;
  final DailySafeToSaveModel _dailySafeToSaveTemplate;
  final TransferResultModel _transferResult;
  final TransferResultModel _internalTransferResult;
  final List<ScheduledPaymentModel> _scheduledPayments;
  bool _smartListEnabled = true;
  bool _adminModeEnabled = false;
  bool _autoDailySaveEnabled = false;
  DateTime _effectiveDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  int _nextTransactionId = 300;
  int _nextScheduledPaymentId = 100;
  int _nextLoanId = 200;
  int _nextSmartCategoryId = 1;

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
  int createLoanCalls = 0;
  Map<String, Object?>? lastLoanDraft;
  int createTransactionCalls = 0;
  Map<String, Object?>? lastTransactionDraft;
  int createSmartCategoryCalls = 0;
  Map<String, Object?>? lastSmartCategoryDraft;
  int createSmartCategoryFromTransactionCalls = 0;
  Map<String, Object?>? lastSmartCategoryFromTransactionDraft;
  int bulkCategorizeTransactionsCalls = 0;
  List<int>? lastBulkCategorizeTransactionIds;
  String? lastBulkCategorizeCategoryId;
  int simulateDayCalls = 0;
  bool? lastAutoDailySaveEnabled;
  List<Map<String, String>> lastChatHistory = const <Map<String, String>>[];
  List<Map<String, String>> chatHistory = const <Map<String, String>>[];
  String? lastChatMessage;
  String? lastResolvedAiActionToken;
  bool? lastResolvedAiActionConfirmed;

  @override
  Future<List<AccountModel>> fetchAccounts() async => _accounts;

  @override
  Future<List<TransactionModel>> fetchTransactions() async => _transactions;

  @override
  Future<List<SmartCategory>> fetchSmartCategories() async =>
      _smartListEnabled ? _smartCategories : const <SmartCategory>[];

  @override
  Future<DailySafeToSaveModel> fetchDailySafeToSave() async =>
      _buildDailySafeToSave();

  @override
  Future<bool> getAutoDailySaveEnabled() async => _autoDailySaveEnabled;

  @override
  Future<void> setAutoDailySaveEnabled(bool enabled) async {
    _autoDailySaveEnabled = enabled;
    lastAutoDailySaveEnabled = enabled;
  }

  @override
  Future<SimulateDayResponseModel> simulateDay() async {
    simulateDayCalls += 1;
    _effectiveDate = _today().add(const Duration(days: 1));
    final preview = _buildDailySafeToSave();
    var savedAmount = 0.0;
    var executed = false;
    var notification = 'Р”РµРЅСЊ СЃРјРѕРґРµР»РёСЂРѕРІР°РЅ.';

    if (_autoDailySaveEnabled &&
        preview.enabled &&
        preview.suggestedAmount > 0 &&
        _savingsAccount() != null) {
      savedAmount = preview.suggestedAmount;
      executed = true;
      _updateAccountBalance(_mainAccount().id, -savedAmount);
      _updateAccountBalance(_savingsAccount()!.id, savedAmount);
      notification =
          'РђРІС‚РѕСЃРµР№РІ РїРµСЂРµРІРµР» ${savedAmount.toStringAsFixed(0)} KGS РІ РЅР°РєРѕРїР»РµРЅРёСЏ.';
    }

    return SimulateDayResponseModel(
      currentDate: _effectiveDate,
      currentBalance: _mainAccount().balance,
      savingsBalance: _savingsAccount()?.balance ?? 0.0,
      savedAmount: savedAmount,
      autoSaveExecuted: executed,
      notification: notification,
    );
  }

  @override
  Future<bool> getSmartListEnabled() async => _smartListEnabled;

  @override
  Future<void> setSmartListEnabled(bool enabled) async {
    _smartListEnabled = enabled;
  }

  @override
  Future<void> deleteSmartCategory(String categoryId) async {
    _smartCategories.removeWhere((category) => category.id == categoryId);
  }

  @override
  Future<void> deleteScheduledPayment(int paymentId) async {
    _scheduledPayments.removeWhere((payment) => payment.id == paymentId);
  }

  @override
  Future<bool> getAdminModeEnabled() async => _adminModeEnabled;

  @override
  Future<void> setAdminModeEnabled(bool enabled) async {
    _adminModeEnabled = enabled;
  }

  @override
  Future<DateTime> getEffectiveDate() async => _effectiveDate;

  @override
  Future<void> setEffectiveDate(DateTime date) async {
    _effectiveDate = DateTime(date.year, date.month, date.day);
  }

  @override
  Future<TransactionModel> adjustAccountBalance({
    required int accountId,
    required double delta,
    required String title,
  }) async {
    final account = _accounts.firstWhere((item) => item.id == accountId);
    _updateAccountBalance(accountId, delta);
    final transaction = TransactionModel(
      id: _nextTransactionId++,
      title: title.isEmpty ? 'РђРґРјРёРЅ РєРѕСЂСЂРµРєС‚РёСЂРѕРІРєР°' : title,
      counterparty: 'Admin',
      amount: delta,
      category: delta >= 0 ? 'РџРѕСЃС‚СѓРїР»РµРЅРёСЏ' : 'РљРѕСЂСЂРµРєС‚РёСЂРѕРІРєРё',
      iconKey: delta >= 0 ? 'income' : 'calendar',
      type: delta >= 0 ? 'INCOME' : 'ADJUSTMENT',
      status: 'COMPLETED',
      accountName: account.name,
      occurredAt: DateTime(
        _effectiveDate.year,
        _effectiveDate.month,
        _effectiveDate.day,
        12,
      ),
    );
    _transactions.insert(0, transaction);
    return transaction;
  }

  @override
  Future<AiDashboardModel> fetchDashboard(int offsetDays) async {
    dashboardRequests.add(offsetDays);
    return _buildDashboard(offsetDays);
  }

  @override
  Future<AiAnalysisModel> analyzeCashFlow(int offsetDays) async {
    analyzeRequests.add(offsetDays);
    if (_analysisOverride != null) {
      return _analysisOverride;
    }

    final dashboard = _buildDashboard(_daysUntilEndOfMonth());
    final deficit = dashboard.minimumProjectedBalance < 0
        ? dashboard.minimumProjectedBalance.abs()
        : 0.0;
    if (deficit <= 0) {
      return const AiAnalysisModel(
        hasAlert: false,
        message: 'Р”Рѕ РєРѕРЅС†Р° РјРµСЃСЏС†Р° РґРµС„РёС†РёС‚ РЅРµ РѕР¶РёРґР°РµС‚СЃСЏ.',
        actionToken: null,
      );
    }

    final suggestions = _buildSuggestions(dashboard, deficit);
    return AiAnalysisModel(
      hasAlert: suggestions.isNotEmpty,
      message:
          'Рљ РєРѕРЅС†Сѓ РјРµСЃСЏС†Р° РїСЂРѕРіРЅРѕР·РёСЂСѓРµС‚СЃСЏ РґРµС„РёС†РёС‚ ${deficit.toStringAsFixed(2)} KGS.',
      actionToken: suggestions.isEmpty ? null : suggestions.first.actionToken,
      suggestions: suggestions,
    );
  }

  @override
  Future<AiExecutionModel> executeAction(String actionToken) async {
    executeCalls += 1;
    lastActionToken = actionToken;

    final parts = actionToken.split(':');
    final command = parts.isEmpty ? '' : parts.first;
    switch (command) {
      case 'CLOSE_DEPOSIT':
        final depositId = parts.length > 1 ? int.tryParse(parts[1]) : null;
        return _closeDeposit(depositId);
      case 'POSTPONE':
        final paymentId = parts.length > 1 ? int.tryParse(parts[1]) : null;
        final days = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        if (paymentId == null || days <= 0) {
          return _executionFallback;
        }
        return _postponePayments(<int>[paymentId], days);
      case 'POSTPONE_GROUP':
        final ids = parts.length > 1 ? _parsePaymentIds(parts[1]) : <int>[];
        final days = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        if (ids.isEmpty || days <= 0) {
          return _executionFallback;
        }
        return _postponePayments(ids, days);
      case 'CLOSE_DEPOSIT_AND_POSTPONE':
        final depositId = parts.length > 1 ? int.tryParse(parts[1]) : null;
        final ids = parts.length > 2 ? _parsePaymentIds(parts[2]) : <int>[];
        final days = parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0;
        await _closeDeposit(depositId);
        if (ids.isEmpty || days <= 0) {
          return _currentExecution('Р”РµРїРѕР·РёС‚ Р·Р°РєСЂС‹С‚.');
        }
        return _postponePayments(ids, days, messagePrefix: 'Р”РµРїРѕР·РёС‚ Р·Р°РєСЂС‹С‚.');
      default:
        return _executionFallback;
    }
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

  @override
  Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) async {
    createScheduledPaymentCalls += 1;
    lastScheduledPaymentDraft = <String, Object?>{
      'accountId': accountId,
      'title': title,
      'counterparty': counterparty,
      'category': category,
      'amount': amount,
      'dueDate': dueDate,
      'isReminder': isReminder,
    };
    final account = _accounts.firstWhere((item) => item.id == accountId);
    final payment = ScheduledPaymentModel(
      id: _nextScheduledPaymentId++,
      accountId: accountId,
      accountName: account.name,
      title: title,
      counterparty: counterparty,
      category: category,
      iconKey: _iconForCategory(category),
      amount: amount,
      dueDate: dueDate,
      status: 'SCHEDULED',
      isReminder: isReminder,
    );
    _scheduledPayments.add(payment);
    _scheduledPayments.sort(
      (left, right) => left.dueDate.compareTo(right.dueDate),
    );
    return payment;
  }

  @override
  Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    createLoanCalls += 1;
    lastLoanDraft = <String, Object?>{
      'accountId': accountId,
      'title': title,
      'amount': amount,
      'dueDate': dueDate,
    };
    _updateAccountBalance(accountId, amount);
    final account = _accounts.firstWhere((item) => item.id == accountId);
    _transactions.insert(
      0,
      TransactionModel(
        id: _nextLoanId++,
        title: title,
        counterparty: 'MBank',
        amount: amount,
        category: 'РљСЂРµРґРёС‚',
        iconKey: 'income',
        type: 'INCOME',
        status: 'COMPLETED',
        accountName: account.name,
        occurredAt: DateTime(
          _effectiveDate.year,
          _effectiveDate.month,
          _effectiveDate.day,
          12,
        ),
      ),
    );
    _scheduledPayments.add(
      ScheduledPaymentModel(
        id: _nextScheduledPaymentId++,
        accountId: accountId,
        accountName: account.name,
        title: '$title В· РџРѕРіР°С€РµРЅРёРµ',
        counterparty: 'MBank',
        category: 'РљСЂРµРґРёС‚',
        iconKey: 'loan',
        amount: amount * 1.12,
        dueDate: dueDate,
        status: 'SCHEDULED',
        isReminder: true,
      ),
    );
    _scheduledPayments.sort(
      (left, right) => left.dueDate.compareTo(right.dueDate),
    );
  }

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
  }) async {
    createTransactionCalls += 1;
    lastTransactionDraft = <String, Object?>{
      'accountId': accountId,
      'title': title,
      'counterparty': counterparty,
      'amount': amount,
      'type': type,
      'category': category,
      'iconKey': iconKey,
      'smartCategoryId': smartCategoryId,
    };
    if (smartCategoryId != null) {
      final index = _smartCategories.indexWhere(
        (item) => item.id == smartCategoryId,
      );
      if (index >= 0) {
        final current = _smartCategories[index];
        _smartCategories[index] = SmartCategory(
          id: current.id,
          name: current.name,
          plannedMonthly: current.plannedMonthly,
          remaining: current.remaining - amount,
          isFavorite: current.isFavorite,
        );
      }
    }

    final account = _accounts.firstWhere((item) => item.id == accountId);
    final normalizedAmount = type == 'INCOME' ? amount.abs() : -amount.abs();
    final transaction = TransactionModel(
      id: _nextTransactionId++,
      title: title,
      counterparty: counterparty,
      amount: normalizedAmount,
      category: category,
      iconKey: iconKey,
      type: type,
      status: 'COMPLETED',
      accountName: account.name,
      occurredAt: DateTime(
        _effectiveDate.year,
        _effectiveDate.month,
        _effectiveDate.day,
        12,
      ),
    );
    _transactions.insert(0, transaction);
    _updateAccountBalance(accountId, normalizedAmount);
    return transaction;
  }

  @override
  Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
    createSmartCategoryCalls += 1;
    lastSmartCategoryDraft = <String, Object?>{
      'name': name,
      'plannedMonthly': plannedMonthly,
    };
    final category = SmartCategory(
      id: 'smart-${_nextSmartCategoryId++}',
      name: name,
      plannedMonthly: plannedMonthly,
      remaining: plannedMonthly,
      isFavorite: false,
    );
    _smartCategories.add(category);
    return category;
  }

  @override
  Future<SmartCategory> createSmartCategoryFromTransaction({
    required int transactionId,
    required String name,
    required double plannedMonthly,
  }) async {
    createSmartCategoryFromTransactionCalls += 1;
    lastSmartCategoryFromTransactionDraft = <String, Object?>{
      'transactionId': transactionId,
      'name': name,
      'plannedMonthly': plannedMonthly,
    };
    final category = await createSmartCategory(
      name: name,
      plannedMonthly: plannedMonthly,
    );
    return category;
  }

  @override
  Future<void> bulkCategorizeTransactions({
    required List<int> transactionIds,
    String? categoryId,
  }) async {
    bulkCategorizeTransactionsCalls += 1;
    lastBulkCategorizeTransactionIds = List<int>.from(transactionIds);
    lastBulkCategorizeCategoryId = categoryId;

    SmartCategory? category;
    if (categoryId != null) {
      final categoryIndex = _smartCategories.indexWhere(
        (item) => item.id == categoryId,
      );
      if (categoryIndex < 0) {
        throw const ApiException(404, 'Smart category not found.');
      }
      category = _smartCategories[categoryIndex];
    }

    final transactionIdSet = transactionIds.toSet();
    for (var index = 0; index < _transactions.length; index += 1) {
      final transaction = _transactions[index];
      if (!transactionIdSet.contains(transaction.id)) {
        continue;
      }
      _transactions[index] = TransactionModel(
        id: transaction.id,
        title: transaction.title,
        counterparty: transaction.counterparty,
        amount: transaction.amount,
        category: transaction.category,
        iconKey: transaction.iconKey,
        type: transaction.type,
        status: transaction.status,
        accountName: transaction.accountName,
        occurredAt: transaction.occurredAt,
        smartCategoryId: categoryId,
        smartCategoryName: category?.name,
      );

      if (category != null && transaction.amount < 0) {
        final existingCategoryIndex = _smartCategories.indexWhere(
          (item) => item.id == categoryId,
        );
        if (existingCategoryIndex >= 0) {
          final current = _smartCategories[existingCategoryIndex];
          _smartCategories[existingCategoryIndex] = SmartCategory(
            id: current.id,
            name: current.name,
            plannedMonthly: current.plannedMonthly,
            remaining: current.remaining - transaction.amount.abs(),
            isFavorite: current.isFavorite,
          );
        }
      }
    }
  }

  @override
  Future<void> setSmartCategoryFavorite(
    String categoryId,
    bool isFavorite,
  ) async {
    final currentIndex = _smartCategories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (currentIndex < 0) {
      throw const ApiException(404, 'Smart-РєР°С‚РµРіРѕСЂРёСЏ РЅРµ РЅР°Р№РґРµРЅР°.');
    }

    if (isFavorite && !_smartCategories[currentIndex].isFavorite) {
      final favoriteCount = _smartCategories
          .where((category) => category.isFavorite)
          .length;
      if (favoriteCount >= 3) {
        throw const ApiException(
          400,
          'РњРѕР¶РЅРѕ РІС‹Р±СЂР°С‚СЊ РЅРµ Р±РѕР»СЊС€Рµ С‚СЂРµС… РёР·Р±СЂР°РЅРЅС‹С… РєР°С‚РµРіРѕСЂРёР№.',
        );
      }
    }

    final current = _smartCategories[currentIndex];
    _smartCategories[currentIndex] = SmartCategory(
      id: current.id,
      name: current.name,
      plannedMonthly: current.plannedMonthly,
      remaining: current.remaining,
      isFavorite: isFavorite,
    );
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

    final fromAccount = _findAccountById(fromAccountId);
    final toAccount = _findAccountById(toAccountId);
    if (fromAccount == null || toAccount == null) {
      return _internalTransferResult;
    }

    _updateAccountBalance(fromAccountId, -amount);
    _updateAccountBalance(toAccountId, amount);
    return TransferResultModel(
      message:
          description?.isNotEmpty == true
              ? description!
              : 'РџРµСЂРµРІРѕРґ РјРµР¶РґСѓ СЃС‡РµС‚Р°РјРё РІС‹РїРѕР»РЅРµРЅ.',
      fromAccount: _findAccountById(fromAccountId) ?? fromAccount,
      toAccount: _findAccountById(toAccountId) ?? toAccount,
      amount: amount,
    );
  }

  @override
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
    externalTransferCalls += 1;
    lastExternalTransfer = <String, Object?>{
      'fromAccountId': fromAccountId,
      'recipientType': recipientType,
      'recipientName': recipientName,
      'amount': amount,
      'description': description,
      'category': category,
      'iconKey': iconKey,
      'smartCategoryId': smartCategoryId,
    };
    return _transferResult;
  }

  @override
  Future<List<Map<String, String>>> fetchAiChatHistory() async {
    return chatHistory
        .map((message) => Map<String, String>.from(message))
        .toList(growable: false);
  }

  @override
  Future<AiChatReplyModel> sendAiChatMessage({
    required List<Map<String, String>> history,
    required String newMessage,
  }) async {
    lastChatHistory = history
        .map((message) => Map<String, String>.from(message))
        .toList(growable: false);
    lastChatMessage = newMessage;
    const role = 'assistant';
    const content =
        'Safe-to-Save suggests keeping reserve for upcoming payments before increasing savings.';
    chatHistory = <Map<String, String>>[
      ...history,
      <String, String>{'role': 'user', 'content': newMessage},
      <String, String>{'role': role, 'content': content},
    ];
    return const AiChatReplyModel(role: role, content: content);
  }

  @override
  Future<AiChatReplyModel> resolveAiChatAction({
    required String token,
    required bool confirmed,
  }) async {
    lastResolvedAiActionToken = token;
    lastResolvedAiActionConfirmed = confirmed;
    return AiChatReplyModel(
      role: 'assistant',
      content: confirmed
          ? 'Category deleted.'
          : 'Category deletion canceled.',
    );
  }

  AiDashboardModel _buildDashboard(int offsetDays) {
    final trackedAccount = _mainAccount();
    final savingsBalance = _savingsAccount()?.balance ?? _dashboardTemplate.savingsBalance;
    final today = _today();
    final horizon = offsetDays < 0 ? 0 : offsetDays;
    final endDate = today.add(Duration(days: horizon));
    final payments = _scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .where((payment) => !payment.dueDate.isAfter(endDate))
        .toList()
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    var runningBalance = trackedAccount.balance;
    final points = List<ForecastPointModel>.generate(
      horizon + 1,
      (int index) {
        final date = today.add(Duration(days: index));
        if (index > 0) {
          final dailyOutflow = payments
              .where((payment) => _isSameDay(payment.dueDate, date))
              .fold<double>(0.0, (sum, payment) => sum + payment.amount);
          runningBalance -= dailyOutflow;
        }
        return ForecastPointModel(
          dayOffset: index,
          isoDate: date.toIso8601String(),
          label: _shortDateLabel(date),
          balance: runningBalance,
        );
      },
    );

    final minimumProjectedBalance = points.isEmpty
        ? trackedAccount.balance
        : points
            .map((point) => point.balance)
            .reduce((left, right) => left < right ? left : right);

    return AiDashboardModel(
      currentBalance: trackedAccount.balance,
      savingsBalance: savingsBalance,
      minimumProjectedBalance: minimumProjectedBalance,
      horizonDays: horizon,
      points: points,
      scheduledPayments: payments,
    );
  }

  List<BalanceSuggestionModel> _buildSuggestions(
    AiDashboardModel dashboard,
    double deficit,
  ) {
    final suggestions = <BalanceSuggestionModel>[];
    final savingsAccount = _savingsAccount();
    final postponeDays = 7;
    final flexiblePayments = dashboard.scheduledPayments
        .where(_isFlexiblePayment)
        .toList(growable: false);

    if (savingsAccount != null && savingsAccount.balance > 0) {
      suggestions.add(
        BalanceSuggestionModel(
          id: 'close-deposit-${savingsAccount.id}',
          title: 'Р—Р°РєСЂС‹С‚СЊ РґРµРїРѕР·РёС‚',
          description:
              'Р—Р°РєСЂС‹С‚РёРµ РЅР°РєРѕРїРёС‚РµР»СЊРЅРѕРіРѕ РґРµРїРѕР·РёС‚Р° РґР°СЃС‚ ${savingsAccount.balance.toStringAsFixed(2)} KGS.',
          actionToken: 'CLOSE_DEPOSIT:${savingsAccount.id}',
        ),
      );
    }

    ScheduledPaymentModel? single;
    for (final payment in flexiblePayments) {
      if (single == null || payment.amount > single.amount) {
        single = payment;
      }
      if (payment.amount >= deficit) {
        single = payment;
        break;
      }
    }
    if (single != null) {
      suggestions.add(
        BalanceSuggestionModel(
          id: 'postpone-${single.id}',
          title: 'РџРµСЂРµРЅРµСЃС‚Рё РїР»Р°С‚РµР¶ "${single.title}"',
          description:
              'РЎРґРІРёРі РЅР° $postponeDays РґРЅ. РѕСЃРІРѕР±РѕРґРёС‚ ${single.amount.toStringAsFixed(2)} KGS.',
          actionToken: 'POSTPONE:${single.id}:$postponeDays',
        ),
      );
    }

    if (flexiblePayments.isNotEmpty) {
      final grouped = <ScheduledPaymentModel>[];
      var covered = 0.0;
      for (final payment in flexiblePayments) {
        grouped.add(payment);
        covered += payment.amount;
        if (covered >= deficit) {
          break;
        }
      }
      final ids = grouped.map((payment) => payment.id).join(',');
      suggestions.add(
        BalanceSuggestionModel(
          id: 'postpone-group-$ids',
          title: grouped.length == 1
              ? 'РџРµСЂРµРЅРµСЃС‚Рё РіРёР±РєРёР№ РїР»Р°С‚РµР¶'
              : 'РџРµСЂРµРЅРµСЃС‚Рё РіСЂСѓРїРїСѓ РїР»Р°С‚РµР¶РµР№',
          description:
              'РџРµСЂРµРЅРѕСЃ ${grouped.length} РїР»Р°С‚РµР¶РµР№ РѕСЃРІРѕР±РѕРґРёС‚ ${covered.toStringAsFixed(2)} KGS.',
          actionToken: 'POSTPONE_GROUP:$ids:$postponeDays',
        ),
      );
      if (savingsAccount != null &&
          savingsAccount.balance > 0 &&
          savingsAccount.balance < deficit &&
          savingsAccount.balance + covered >= deficit) {
        suggestions.add(
          BalanceSuggestionModel(
            id: 'combo-${savingsAccount.id}-$ids',
            title: 'РљРѕРјР±РёРЅРёСЂРѕРІР°С‚СЊ РґРµРїРѕР·РёС‚ Рё РїРµСЂРµРЅРѕСЃ',
            description:
                'Р—Р°РєСЂРѕР№С‚Рµ РґРµРїРѕР·РёС‚ Рё РїРµСЂРµРЅРµСЃРёС‚Рµ ${grouped.length} РїР»Р°С‚РµР¶РµР№, С‡С‚РѕР±С‹ СѓР±СЂР°С‚СЊ СЂР°Р·СЂС‹РІ.',
            actionToken:
                'CLOSE_DEPOSIT_AND_POSTPONE:${savingsAccount.id}:$ids:$postponeDays',
          ),
        );
      }
    }

    return suggestions;
  }

  Future<AiExecutionModel> _closeDeposit(int? depositId) async {
    final savingsAccount = depositId == null
        ? _savingsAccount()
        : _findAccountById(depositId);
    if (savingsAccount == null) {
      return _currentExecution('РќР°РєРѕРїРёС‚РµР»СЊРЅС‹Р№ РґРµРїРѕР·РёС‚ РЅРµ РЅР°Р№РґРµРЅ.', success: false);
    }
    if (savingsAccount.balance <= 0) {
      return _currentExecution('РќР°РєРѕРїРёС‚РµР»СЊРЅС‹Р№ РґРµРїРѕР·РёС‚ СѓР¶Рµ РїСѓСЃС‚.', success: false);
    }

    final amount = savingsAccount.balance;
    _updateAccountBalance(savingsAccount.id, -amount);
    _updateAccountBalance(_mainAccount().id, amount);
    return _currentExecution('Р”РµРїРѕР·РёС‚ Р·Р°РєСЂС‹С‚.');
  }

  Future<AiExecutionModel> _postponePayments(
    List<int> paymentIds,
    int days, {
    String? messagePrefix,
  }) async {
    var changed = 0;
    for (var index = 0; index < _scheduledPayments.length; index += 1) {
      final payment = _scheduledPayments[index];
      if (!paymentIds.contains(payment.id)) {
        continue;
      }
      changed += 1;
      _scheduledPayments[index] = ScheduledPaymentModel(
        id: payment.id,
        accountId: payment.accountId,
        accountName: payment.accountName,
        title: payment.title,
        counterparty: payment.counterparty,
        category: payment.category,
        iconKey: payment.iconKey,
        amount: payment.amount,
        dueDate: payment.dueDate.add(Duration(days: days)),
        status: payment.status,
        isReminder: payment.isReminder,
      );
    }
    _scheduledPayments.sort(
      (left, right) => left.dueDate.compareTo(right.dueDate),
    );

    if (changed == 0) {
      return _currentExecution('РџР»Р°С‚РµР¶ РґР»СЏ РїРµСЂРµРЅРѕСЃР° РЅРµ РЅР°Р№РґРµРЅ.', success: false);
    }

    final prefix = messagePrefix == null ? '' : '$messagePrefix ';
    final noun = changed == 1 ? 'РїР»Р°С‚РµР¶' : 'РїР»Р°С‚РµР¶РµР№';
    return _currentExecution('$prefixРџРµСЂРµРЅРµСЃРµРЅРѕ $changed $noun.');
  }

  AiExecutionModel _currentExecution(
    String message, {
    bool success = true,
  }) {
    return AiExecutionModel(
      success: success,
      message: message,
      currentBalance: _mainAccount().balance,
      savingsBalance: _savingsAccount()?.balance ?? 0.0,
    );
  }

  void _updateAccountBalance(int accountId, double delta) {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index < 0) {
      return;
    }
    final current = _accounts[index];
    _accounts[index] = AccountModel(
      id: current.id,
      name: current.name,
      type: current.type,
      balance: current.balance + delta,
      currency: current.currency,
    );
  }

  AccountModel _mainAccount() {
    return _accounts.firstWhere(
      (account) => account.type == 'MAIN',
      orElse: () => _accounts.first,
    );
  }

  AccountModel? _savingsAccount() {
    for (final account in _accounts) {
      if (account.type == 'SAVINGS') {
        return account;
      }
    }
    return null;
  }

  AccountModel? _findAccountById(int? accountId) {
    if (accountId == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  bool _isFlexiblePayment(ScheduledPaymentModel payment) {
    final category = payment.category.toLowerCase();
    final title = payment.title.toLowerCase();
    return !category.contains('Р°СЂРµРЅРґ') &&
        !category.contains('РєРѕРјРјСѓРЅ') &&
        !category.contains('РєСЂРµРґРёС‚') &&
        !title.contains('Р°СЂРµРЅРґ');
  }

  List<int> _parsePaymentIds(String value) {
    return value
        .split(',')
        .map((item) => int.tryParse(item))
        .whereType<int>()
        .toList(growable: false);
  }

  int _daysUntilEndOfMonth() {
    final today = _today();
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    return monthEnd.difference(today).inDays;
  }

  DateTime _today() {
    return DateTime(
      _effectiveDate.year,
      _effectiveDate.month,
      _effectiveDate.day,
    );
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _shortDateLabel(DateTime value) {
    const months = <String>[
      'СЏРЅРІ.',
      'С„РµРІ.',
      'РјР°СЂ.',
      'Р°РїСЂ.',
      'РјР°СЏ',
      'РёСЋРЅ.',
      'РёСЋР».',
      'Р°РІРі.',
      'СЃРµРЅС‚.',
      'РѕРєС‚.',
      'РЅРѕСЏР±.',
      'РґРµРє.',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  String _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('Р°СЂРµРЅРґ')) {
      return 'home';
    }
    if (normalized.contains('РїРѕРґРїРёСЃ')) {
      return 'subscription';
    }
    if (normalized.contains('РєСЂРµРґРёС‚')) {
      return 'loan';
    }
    return 'calendar';
  }

  DailySafeToSaveModel _buildDailySafeToSave() {
    final mainBalance = _mainAccount().balance;
    final today = _today();
    final nextIncomeDate = _nextIncomeDate(today);
    final requiredPayments = _scheduledPayments
        .where((payment) => !payment.dueDate.isBefore(today))
        .where(
          (payment) => nextIncomeDate == null || !payment.dueDate.isAfter(nextIncomeDate),
        )
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
    final lifeBuffer = _dailySafeToSaveTemplate.lifeBuffer;
    final safeBalance = mainBalance - requiredPayments - lifeBuffer;
    final suggestedAmount = safeBalance > 0 ? safeBalance : 0.0;

    return DailySafeToSaveModel(
      enabled: _dailySafeToSaveTemplate.enabled,
      suggestedAmount: suggestedAmount,
      safeBalance: safeBalance,
      currentBalance: mainBalance,
      requiredPayments: requiredPayments,
      lifeBuffer: lifeBuffer,
      nextIncomeDate: nextIncomeDate,
      daysToNextIncome: nextIncomeDate == null
          ? 0
          : nextIncomeDate.difference(today).inDays,
      status: suggestedAmount > 0 ? 'READY' : 'WAIT',
    );
  }

  DateTime? _nextIncomeDate(DateTime today) {
    final incomes = _transactions
        .where((transaction) => transaction.amount > 0)
        .map(
          (transaction) => DateTime(
            transaction.occurredAt.year,
            transaction.occurredAt.month,
            transaction.occurredAt.day,
          ),
        )
        .where((date) => !date.isBefore(today))
        .toList(growable: false)
      ..sort();
    if (incomes.isNotEmpty) {
      return incomes.first;
    }
    return today.add(Duration(days: _dailySafeToSaveTemplate.daysToNextIncome));
  }
}

AccountModel _copyAccount(AccountModel account) {
  return AccountModel(
    id: account.id,
    name: account.name,
    type: account.type,
    balance: account.balance,
    currency: account.currency,
  );
}

TransactionModel _copyTransaction(TransactionModel transaction) {
  return TransactionModel(
    id: transaction.id,
    title: transaction.title,
    counterparty: transaction.counterparty,
    amount: transaction.amount,
    category: transaction.category,
    iconKey: transaction.iconKey,
    type: transaction.type,
    status: transaction.status,
    accountName: transaction.accountName,
    occurredAt: transaction.occurredAt,
    smartCategoryId: transaction.smartCategoryId,
    smartCategoryName: transaction.smartCategoryName,
  );
}
