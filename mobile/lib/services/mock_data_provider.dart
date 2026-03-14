import '../models/account_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/save_suggestion_model.dart';
import '../models/smart_category_model.dart';
import '../models/transaction_model.dart';

class MockDataProvider {
  MockDataProvider._();

  static bool _initialized = false;
  static bool _smartListEnabled = true;
  static int _nextTransactionId = 2000;
  static int _nextScheduledPaymentId = 4000;
  static int _nextLoanId = 6000;
  static int _nextSmartCategoryId = 1;

  static List<AccountModel> _accounts = <AccountModel>[];
  static List<TransactionModel> _transactions = <TransactionModel>[];
  static List<ScheduledPaymentModel> _scheduledPayments =
      <ScheduledPaymentModel>[];
  static List<SmartCategory> _smartCategoryDefinitions = <SmartCategory>[];
  static Map<int, String> _transactionSmartCategoryIds = <int, String>{};

  static bool get isInitialized => _initialized;

  static List<AccountModel> get accounts => List<AccountModel>.unmodifiable(
    _accounts,
  );

  static List<TransactionModel> get transactions =>
      List<TransactionModel>.unmodifiable(_transactions);

  static List<ScheduledPaymentModel> get scheduledPayments =>
      List<ScheduledPaymentModel>.unmodifiable(_scheduledPayments);

  static List<SmartCategory> get smartCategories =>
      List<SmartCategory>.unmodifiable(_buildSmartCategories());

  static bool get smartListEnabled => _smartListEnabled;

  static void resetForTest() {
    _initialized = false;
    _smartListEnabled = true;
    _nextTransactionId = 2000;
    _nextScheduledPaymentId = 4000;
    _nextLoanId = 6000;
    _nextSmartCategoryId = 1;
    _accounts = <AccountModel>[];
    _transactions = <TransactionModel>[];
    _scheduledPayments = <ScheduledPaymentModel>[];
    _smartCategoryDefinitions = <SmartCategory>[];
    _transactionSmartCategoryIds = <int, String>{};
  }

  static void initDemoData({
    required List<AccountModel> accounts,
    required List<TransactionModel> transactions,
    List<ScheduledPaymentModel> scheduledPayments =
        const <ScheduledPaymentModel>[],
  }) {
    if (_initialized) {
      return;
    }

    _accounts = accounts
        .map(
          (account) => AccountModel(
            id: account.id,
            name: account.name,
            type: account.type,
            balance: account.balance,
            currency: account.currency,
          ),
        )
        .toList(growable: false);

    _transactions = transactions
        .map(
          (transaction) => TransactionModel(
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
          ),
        )
        .toList();

    _scheduledPayments = scheduledPayments
        .map(
          (payment) => ScheduledPaymentModel(
            id: payment.id,
            accountId: payment.accountId,
            accountName: payment.accountName,
            title: payment.title,
            counterparty: payment.counterparty,
            category: payment.category,
            iconKey: payment.iconKey,
            amount: payment.amount,
            dueDate: payment.dueDate,
            status: payment.status,
            isReminder: payment.isReminder,
          ),
        )
        .toList();

    _smartCategoryDefinitions = <SmartCategory>[
      const SmartCategory(
        id: 'food',
        name: 'Еда',
        plannedMonthly: 12000,
        remaining: 12000,
      ),
      const SmartCategory(
        id: 'transfer',
        name: 'Переводы',
        plannedMonthly: 9000,
        remaining: 9000,
      ),
      const SmartCategory(
        id: 'fun',
        name: 'Развлечения',
        plannedMonthly: 7000,
        remaining: 7000,
      ),
    ];
    _transactionSmartCategoryIds = _inferSmartCategoryAssignments(_transactions);
    _syncCounters();
    _initialized = true;
  }

  static Future<ScheduledPaymentModel> createReminderScheduledPayment({
    required int accountId,
    required String title,
    required String counterparty,
    required String category,
    required double amount,
    required DateTime dueDate,
    required bool isReminder,
  }) async {
    final account = _findAccount(accountId);
    final payment = ScheduledPaymentModel(
      id: _nextScheduledPaymentId++,
      accountId: account.id,
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
    _scheduledPayments = <ScheduledPaymentModel>[
      ..._scheduledPayments,
      payment,
    ]..sort((left, right) => left.dueDate.compareTo(right.dueDate));
    return payment;
  }

  static Future<TransactionModel> createTransaction({
    required int accountId,
    required String title,
    required String counterparty,
    required double amount,
    required String type,
    required String category,
    required String iconKey,
    String? smartCategoryId,
  }) async {
    final account = _findAccount(accountId);
    final normalizedAmount = _normalizeTransactionAmount(type, amount);
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
      occurredAt: DateTime.now(),
    );

    _transactions = <TransactionModel>[transaction, ..._transactions];
    _updateAccountBalance(accountId, normalizedAmount);
    if (smartCategoryId != null && smartCategoryId.isNotEmpty) {
      _transactionSmartCategoryIds[transaction.id] = smartCategoryId;
    }
    return transaction;
  }

  static Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    final account = _findAccount(accountId);
    _updateAccountBalance(accountId, amount);
    _transactions = <TransactionModel>[
      TransactionModel(
        id: _nextLoanId++,
        title: title,
        counterparty: 'MBank',
        amount: amount,
        category: 'Кредит',
        iconKey: 'income',
        type: 'INCOME',
        status: 'COMPLETED',
        accountName: account.name,
        occurredAt: DateTime.now(),
      ),
      ..._transactions,
    ];

    await createReminderScheduledPayment(
      accountId: accountId,
      title: '$title · Погашение',
      counterparty: 'MBank',
      category: 'Кредит',
      amount: amount * 1.12,
      dueDate: dueDate,
      isReminder: true,
    );
  }

  static Future<SmartCategory> createSmartCategory({
    required String name,
    required double plannedMonthly,
  }) async {
    final category = SmartCategory(
      id: 'smart-${_nextSmartCategoryId++}',
      name: name,
      plannedMonthly: plannedMonthly,
      remaining: plannedMonthly,
    );
    _smartCategoryDefinitions = <SmartCategory>[
      ..._smartCategoryDefinitions,
      category,
    ];
    return category;
  }

  static Future<void> deleteSmartCategory(String categoryId) async {
    _smartCategoryDefinitions = _smartCategoryDefinitions
        .where((category) => category.id != categoryId)
        .toList(growable: false);
    _transactionSmartCategoryIds.removeWhere(
      (_, assignedCategoryId) => assignedCategoryId == categoryId,
    );
  }

  static Future<void> setSmartListEnabled(bool enabled) async {
    _smartListEnabled = enabled;
  }

  static AiDashboardModel computeDashboard(int horizonDays) {
    final trackedAccount = _pickTrackedAccount();
    final savingsAccount = _pickSavingsAccount();
    final today = _today();
    final normalizedHorizon = horizonDays < 0 ? 0 : horizonDays;
    final trackedPayments = _scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .toList()
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    var runningBalance = trackedAccount.balance;
    final points = List<ForecastPointModel>.generate(
      normalizedHorizon + 1,
      (int index) {
        final date = today.add(Duration(days: index));
        if (index > 0) {
          final dailyOutflow = trackedPayments
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
      savingsBalance: savingsAccount?.balance ?? 0.0,
      minimumProjectedBalance: minimumProjectedBalance,
      horizonDays: normalizedHorizon,
      points: points,
      scheduledPayments: trackedPayments,
    );
  }

  static SaveSuggestionModel computeSuggestedSave() {
    final trackedAccount = _pickTrackedAccount();
    final today = _today();
    final monthEnd = _monthEnd(today);
    final scheduledOutflow = _scheduledPayments
        .where((payment) => payment.accountId == trackedAccount.id)
        .where((payment) => !payment.dueDate.isBefore(today))
        .where((payment) => !payment.dueDate.isAfter(monthEnd))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
    final reservedByBudgets = smartListEnabled
        ? _buildSmartCategories().fold<double>(
            0.0,
            (sum, category) =>
                sum + (category.remaining > 0 ? category.remaining : 0),
          )
        : 0.0;
    final safetyReserve = (trackedAccount.balance * 0.15).clamp(3000.0, 15000.0);
    final freeAmount =
        trackedAccount.balance - scheduledOutflow - reservedByBudgets - safetyReserve;
    final suggestionAmount = freeAmount <= 0
        ? 0.0
        : (freeAmount / 100).floorToDouble() * 100;

    final reason = suggestionAmount <= 0
        ? 'До конца месяца свободного остатка нет: оставьте деньги на платежи и обязательные траты.'
        : 'Можно безопасно отложить часть остатка: ближайшие списания и лимиты категорий уже учтены.';

    return SaveSuggestionModel(
      amount: suggestionAmount,
      reason: reason,
      safetyReserve: safetyReserve,
    );
  }

  static List<SmartCategory> _buildSmartCategories() {
    final windowStart = _monthStart(DateTime.now());
    final windowEnd = DateTime.now();

    return _smartCategoryDefinitions.map((definition) {
      final spent = _transactions
          .where((transaction) => transaction.status == 'COMPLETED')
          .where((transaction) => transaction.amount < 0)
          .where(
            (transaction) =>
                !transaction.occurredAt.isBefore(windowStart) &&
                !transaction.occurredAt.isAfter(windowEnd),
          )
          .where(
            (transaction) =>
                _resolveSmartCategoryId(transaction) == definition.id,
          )
          .fold<double>(0.0, (sum, transaction) => sum + transaction.amount.abs());

      return SmartCategory(
        id: definition.id,
        name: definition.name,
        plannedMonthly: definition.plannedMonthly,
        remaining: definition.plannedMonthly - spent,
      );
    }).toList(growable: false);
  }

  static Map<int, String> _inferSmartCategoryAssignments(
    List<TransactionModel> transactions,
  ) {
    final assignments = <int, String>{};
    for (final transaction in transactions) {
      final categoryId = _inferCategoryFromTransaction(transaction);
      if (categoryId != null) {
        assignments[transaction.id] = categoryId;
      }
    }
    return assignments;
  }

  static String? _resolveSmartCategoryId(TransactionModel transaction) {
    return _transactionSmartCategoryIds[transaction.id] ??
        _inferCategoryFromTransaction(transaction);
  }

  static String? _inferCategoryFromTransaction(TransactionModel transaction) {
    final category = transaction.category.toLowerCase();
    final iconKey = transaction.iconKey.toLowerCase();
    return switch (true) {
      _ when category.contains('ед') || iconKey == 'food' => 'food',
      _ when category.contains('перевод') || transaction.type == 'TRANSFER' =>
        'transfer',
      _ when category.contains('развлеч') || iconKey == 'shopping' => 'fun',
      _ => null,
    };
  }

  static void _updateAccountBalance(int accountId, double delta) {
    _accounts = _accounts
        .map(
          (account) => account.id == accountId
              ? AccountModel(
                  id: account.id,
                  name: account.name,
                  type: account.type,
                  balance: account.balance + delta,
                  currency: account.currency,
                )
              : account,
        )
        .toList(growable: false);
  }

  static void _syncCounters() {
    if (_transactions.isNotEmpty) {
      _nextTransactionId =
          _transactions.map((transaction) => transaction.id).reduce(_maxInt) + 1;
      _nextLoanId =
          _transactions.map((transaction) => transaction.id).reduce(_maxInt) + 1000;
    }
    if (_scheduledPayments.isNotEmpty) {
      _nextScheduledPaymentId = _scheduledPayments
              .map((payment) => payment.id)
              .reduce(_maxInt) +
          1;
    }
  }

  static AccountModel _findAccount(int accountId) {
    return _accounts.firstWhere(
      (account) => account.id == accountId,
      orElse: () => _pickTrackedAccount(),
    );
  }

  static AccountModel _pickTrackedAccount() {
    for (final account in _accounts) {
      if (account.type == 'MAIN') {
        return account;
      }
    }
    return _accounts.first;
  }

  static AccountModel? _pickSavingsAccount() {
    for (final account in _accounts) {
      if (account.type == 'SAVINGS') {
        return account;
      }
    }
    return null;
  }

  static double _normalizeTransactionAmount(String type, double amount) {
    if (type == 'INCOME') {
      return amount.abs();
    }
    return -amount.abs();
  }

  static String _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('аренд')) {
      return 'home';
    }
    if (normalized.contains('подпис')) {
      return 'subscription';
    }
    if (normalized.contains('кредит')) {
      return 'loan';
    }
    if (normalized.contains('перевод')) {
      return 'qr';
    }
    return 'calendar';
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _monthStart(DateTime now) {
    return DateTime(now.year, now.month, 1);
  }

  static DateTime _monthEnd(DateTime now) {
    return DateTime(now.year, now.month + 1, 0);
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static int _maxInt(int left, int right) => left > right ? left : right;

  static String _shortDateLabel(DateTime value) {
    const months = <String>[
      'янв.',
      'фев.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }
}
