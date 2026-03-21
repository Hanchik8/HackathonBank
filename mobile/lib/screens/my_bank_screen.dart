import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/api_client.dart';
import '../services/bank_api_service.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class MyBankScreen extends StatefulWidget {
  const MyBankScreen({
    super.key,
    required this.apiService,
    required this.accounts,
    required this.onAccountsChanged,
  });

  final BankApiService apiService;
  final List<AccountModel> accounts;
  final VoidCallback onAccountsChanged;

  @override
  State<MyBankScreen> createState() => _MyBankScreenState();
}

class _MyBankScreenState extends State<MyBankScreen> {
  late List<AccountModel> _accounts;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _accounts = List<AccountModel>.of(widget.accounts);
  }

  AccountModel get _mainAccount {
    for (final account in _accounts) {
      if (account.type == 'MAIN') {
        return account;
      }
    }
    return _accounts.first;
  }

  AccountModel? get _savingsAccount {
    for (final account in _accounts) {
      if (account.type == 'SAVINGS') {
        return account;
      }
    }
    return null;
  }

  Future<void> _refreshAccounts() async {
    final accounts = await widget.apiService.fetchAccounts();
    if (!mounted) {
      return;
    }
    setState(() {
      _accounts = accounts;
    });
  }

  Future<void> _closeDeposit(AccountModel savingsAccount) async {
    if (_isProcessing || savingsAccount.balance <= 0) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await widget.apiService.executeAction(
        'CLOSE_DEPOSIT:${savingsAccount.id}',
      );
      await _refreshAccounts();
      widget.onAccountsChanged();
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _openDeposit({
    required AccountModel mainAccount,
    required AccountModel savingsAccount,
  }) async {
    if (_isProcessing) {
      return;
    }

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DepositTopUpSheet(mainAccount: mainAccount),
    );
    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await widget.apiService.transferBetweenAccounts(
        fromAccountId: mainAccount.id,
        toAccountId: savingsAccount.id,
        amount: amount,
        description: 'Пополнение накопительного депозита',
      );
      await _refreshAccounts();
      widget.onAccountsChanged();
      if (!mounted) {
        return;
      }
      _showMessage(result.message);
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mainAccount = _mainAccount;
    final savingsAccount = _savingsAccount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppTheme.background,
              Color(0xFF090909),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Мой банк',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Счета и карты',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MBANK',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AccountTile(
                      account: mainAccount,
                      accent: const LinearGradient(
                        colors: <Color>[Color(0xFFD7B165), Color(0xFF8E6C31)],
                      ),
                      maskedPan: '••0484',
                      plasticMask: '*4477',
                      favorite: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Мои продукты',
                child: Column(
                  children: <Widget>[
                    const _ProductRow(
                      icon: Icons.percent_rounded,
                      title: 'Кредиты',
                    ),
                    const Divider(color: Color(0xFF2A2A2E), height: 28),
                    const _ProductRow(
                      icon: Icons.payments_outlined,
                      title: 'Рассрочки',
                    ),
                    const Divider(color: Color(0xFF2A2A2E), height: 28),
                    if (savingsAccount != null)
                      _DepositCard(
                        account: savingsAccount,
                        mainAccount: mainAccount,
                        isProcessing: _isProcessing,
                        onCloseDeposit: () => _closeDeposit(savingsAccount),
                        onOpenDeposit: () => _openDeposit(
                          mainAccount: mainAccount,
                          savingsAccount: savingsAccount,
                        ),
                      )
                    else
                      const _UnavailableDepositCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.accent,
    required this.maskedPan,
    required this.plasticMask,
    required this.favorite,
  });

  final AccountModel account;
  final Gradient accent;
  final String maskedPan;
  final String plasticMask;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      maskedPan,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: favorite ? const Color(0xFFF0E928) : Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plasticMask,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  SomFormatter.amount(account.balance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 128,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: accent,
            ),
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Mbank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'VISA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppTheme.accent, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.secondaryText,
        ),
      ],
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({
    required this.account,
    required this.mainAccount,
    required this.isProcessing,
    required this.onCloseDeposit,
    required this.onOpenDeposit,
  });

  final AccountModel account;
  final AccountModel mainAccount;
  final bool isProcessing;
  final VoidCallback onCloseDeposit;
  final VoidCallback onOpenDeposit;

  bool get _isOpened => account.balance > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isOpened
              ? AppTheme.accent.withValues(alpha: 0.24)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.savings_rounded, color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Накопительный депозит',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOpened
                      ? AppTheme.accent.withValues(alpha: 0.16)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isOpened ? 'Открыт' : 'Закрыт',
                  style: TextStyle(
                    color: _isOpened ? AppTheme.accent : AppTheme.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            SomFormatter.amount(account.balance),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: _isOpened ? AppTheme.accent : Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isOpened
                ? 'Деньги находятся на накопительном депозите. При закрытии весь остаток вернется на основной счет.'
                : 'Депозит пуст. Его можно снова пополнить переводом с основного счета.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Основной счет: ${SomFormatter.amount(mainAccount.balance)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          if (_isOpened) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onOpenDeposit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Пополнить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onCloseDeposit,
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Закрыть депозит'),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isProcessing || mainAccount.balance <= 0 ? null : onOpenDeposit,
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Открыть депозит'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableDepositCard extends StatelessWidget {
  const _UnavailableDepositCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'Накопительный депозит недоступен для этого профиля.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
      ),
    );
  }
}

class _DepositTopUpSheet extends StatefulWidget {
  const _DepositTopUpSheet({required this.mainAccount});

  final AccountModel mainAccount;

  @override
  State<_DepositTopUpSheet> createState() => _DepositTopUpSheetState();
}

class _DepositTopUpSheetState extends State<_DepositTopUpSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showMessage('Введите корректную сумму.');
      return;
    }
    if (amount > widget.mainAccount.balance) {
      _showMessage('На основном счете недостаточно средств.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    Navigator.of(context).pop(amount);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 16),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Открыть накопительный депозит',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Укажите сумму перевода с основного счета.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 16),
              Text(
                'Доступно: ${SomFormatter.amount(widget.mainAccount.balance)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Сумма в KGS',
                  labelStyle: const TextStyle(color: AppTheme.secondaryText),
                  filled: true,
                  fillColor: AppTheme.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Перевести в депозит'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
