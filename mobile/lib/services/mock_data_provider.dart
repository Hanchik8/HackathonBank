import '../models/account_model.dart';
import '../models/ai_dashboard_model.dart';
import '../models/transaction_model.dart';

class MockDataProvider {
  MockDataProvider._();

  static final List<_MockLoanRecord> _loans = <_MockLoanRecord>[];
  static int _nextLoanId = 9000;

  static List<AccountModel> applyLoanOverlayToAccounts(
    List<AccountModel> accounts,
  ) {
    if (_loans.isEmpty) {
      return accounts;
    }

    final creditByAccount = <int, double>{};
    for (final loan in _loans) {
      creditByAccount.update(
        loan.accountId,
        (value) => value + loan.amount,
        ifAbsent: () => loan.amount,
      );
    }

    return accounts
        .map(
          (account) => AccountModel(
            id: account.id,
            name: account.name,
            type: account.type,
            balance: account.balance + (creditByAccount[account.id] ?? 0),
            currency: account.currency,
          ),
        )
        .toList(growable: false);
  }

  static List<TransactionModel> applyLoanOverlayToTransactions(
    List<TransactionModel> transactions,
    List<AccountModel> accounts,
  ) {
    if (_loans.isEmpty) {
      return transactions;
    }

    final accountNames = <int, String>{
      for (final account in accounts) account.id: account.name,
    };

    final merged = <TransactionModel>[
      ...transactions,
      ..._loans.map(
        (loan) => TransactionModel(
          id: loan.id,
          title: loan.title,
          counterparty: 'MBank',
          amount: loan.amount,
          category: 'Кредит',
          iconKey: 'income',
          type: 'INCOME',
          status: 'COMPLETED',
          accountName: accountNames[loan.accountId] ?? 'Main',
          occurredAt: loan.createdAt,
        ),
      ),
    ]..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

    return merged;
  }

  static AiDashboardModel computeDashboard({
    required List<AccountModel> accounts,
    required List<TransactionModel> transactions,
    required int offsetDays,
    AiDashboardModel? baseDashboard,
  }) {
    final effectiveAccounts = applyLoanOverlayToAccounts(accounts);
    final effectiveTransactions = applyLoanOverlayToTransactions(
      transactions,
      accounts,
    );
    final accountNames = <int, String>{
      for (final account in effectiveAccounts) account.id: account.name,
    };

    final mainAccount = _pickAccount(effectiveAccounts, 'MAIN');
    final savingsAccount = _pickAccount(effectiveAccounts, 'SAVINGS');
    final currentBalance =
        mainAccount?.balance ??
        baseDashboard?.currentBalance ??
        _fallbackCurrentBalance(effectiveTransactions);
    final savingsBalance =
        savingsAccount?.balance ?? baseDashboard?.savingsBalance ?? 0.0;

    final scheduledPayments = <ScheduledPaymentModel>[
      ...?baseDashboard?.scheduledPayments,
      ..._loans.map(
        (loan) => ScheduledPaymentModel(
          id: loan.id,
          accountId: loan.accountId,
          accountName: accountNames[loan.accountId] ?? mainAccount?.name ?? 'Main',
          title: loan.repaymentTitle,
          counterparty: 'MBank',
          category: 'Кредит',
          iconKey: 'loan',
          amount: loan.repaymentAmount,
          dueDate: loan.dueDate,
          status: 'SCHEDULED',
        ),
      ),
    ]..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    final horizonDays = offsetDays.clamp(0, 10);
    var runningBalance = currentBalance;
    final points = List<ForecastPointModel>.generate(horizonDays + 1, (
      int index,
    ) {
      final date = DateTime.now().add(Duration(days: index));
      final dayExpenses = scheduledPayments
          .where((payment) => _isSameDay(payment.dueDate, date))
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      if (index > 0) {
        runningBalance -= dayExpenses;
      }
      return ForecastPointModel(
        dayOffset: index,
        isoDate: date.toIso8601String(),
        label: _shortDateLabel(date),
        balance: runningBalance,
      );
    });

    final minimumProjectedBalance = points.isEmpty
        ? currentBalance
        : points
            .map((point) => point.balance)
            .reduce((left, right) => left < right ? left : right);

    return AiDashboardModel(
      currentBalance: currentBalance,
      savingsBalance: savingsBalance,
      minimumProjectedBalance: minimumProjectedBalance,
      horizonDays: horizonDays,
      points: points,
      scheduledPayments: scheduledPayments,
    );
  }

  static Future<void> createLoan({
    required int accountId,
    required String title,
    required double amount,
    required DateTime dueDate,
    required List<AccountModel> accounts,
  }) async {
    final account = accounts.firstWhere(
      (item) => item.id == accountId,
      orElse: () => const AccountModel(
        id: 1,
        name: 'Main',
        type: 'MAIN',
        balance: 0,
        currency: 'KGS',
      ),
    );
    _loans.add(
      _MockLoanRecord(
        id: _nextLoanId++,
        accountId: account.id,
        title: title,
        amount: amount,
        dueDate: dueDate,
        createdAt: DateTime.now(),
      ),
    );
  }

  static AccountModel? _pickAccount(List<AccountModel> accounts, String type) {
    for (final account in accounts) {
      if (account.type == type) {
        return account;
      }
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  static double _fallbackCurrentBalance(List<TransactionModel> transactions) {
    return transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

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

class _MockLoanRecord {
  const _MockLoanRecord({
    required this.id,
    required this.accountId,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.createdAt,
  });

  final int id;
  final int accountId;
  final String title;
  final double amount;
  final DateTime dueDate;
  final DateTime createdAt;

  String get repaymentTitle => '$title · Погашение';

  double get repaymentAmount => amount * 1.12;
}
