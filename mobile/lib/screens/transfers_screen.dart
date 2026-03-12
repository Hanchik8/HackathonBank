import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/api_client.dart';
import '../services/bank_api_service.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

enum TransferRecipientMode { user, merchant }

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({
    super.key,
    required this.apiService,
    required this.refreshSignal,
    required this.onDataChanged,
    required this.preferredMode,
  });

  final BankApiService apiService;
  final int refreshSignal;
  final VoidCallback onDataChanged;
  final TransferRecipientMode preferredMode;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<AccountModel>? _accounts;
  String? _errorMessage;
  int? _selectedAccountId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  TransferRecipientMode _mode = TransferRecipientMode.user;

  @override
  void initState() {
    super.initState();
    _mode = widget.preferredMode;
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant TransfersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferredMode != widget.preferredMode) {
      setState(() {
        _mode = widget.preferredMode;
      });
    }
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadAccounts();
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await widget.apiService.fetchAccounts();
      if (!mounted) {
        return;
      }

      setState(() {
        _accounts = accounts;
        _selectedAccountId ??= accounts.first.id;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (_selectedAccountId == null || _isSubmitting) {
      return;
    }

    final recipientName = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (recipientName.isEmpty) {
      _showMessage('Укажи получателя.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Укажи корректную сумму.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await widget.apiService.transferToRecipient(
        fromAccountId: _selectedAccountId!,
        recipientType: _mode == TransferRecipientMode.user
            ? 'USER'
            : 'MERCHANT',
        recipientName: recipientName,
        amount: amount,
        description: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      _recipientController.clear();
      _amountController.clear();
      _noteController.clear();
      widget.onDataChanged();
      _showMessage(result.message);
      await _loadAccounts();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _quickRecipients {
    return switch (_mode) {
      TransferRecipientMode.user => <String>['Aigerim', 'Daniyar', 'Элдияр'],
      TransferRecipientMode.merchant => <String>[
        'Globus',
        'Green Market',
        'MMarket',
      ],
    };
  }

  String get _screenTitle {
    return switch (_mode) {
      TransferRecipientMode.user => 'Перевод пользователю',
      TransferRecipientMode.merchant => 'Оплата магазину',
    };
  }

  String get _recipientLabel {
    return switch (_mode) {
      TransferRecipientMode.user => 'Имя или номер',
      TransferRecipientMode.merchant => 'Название магазина',
    };
  }

  String get _submitLabel {
    return switch (_mode) {
      TransferRecipientMode.user => 'Перевести',
      TransferRecipientMode.merchant => 'Оплатить',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final accounts = _accounts!;
    final selectedAccount = accounts.firstWhere(
      (account) => account.id == _selectedAccountId,
      orElse: () => accounts.first,
    );

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: <Widget>[
          Text(
            'Платежи',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _screenTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'С выбранного счета деньги будут списаны сразу после подтверждения.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ModeChip(
                        label: 'Пользователь',
                        selected: _mode == TransferRecipientMode.user,
                        onTap: () => setState(() {
                          _mode = TransferRecipientMode.user;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeChip(
                        label: 'Магазин',
                        selected: _mode == TransferRecipientMode.merchant,
                        onTap: () => setState(() {
                          _mode = TransferRecipientMode.merchant;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: _selectedAccountId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceSoft,
                  decoration: _inputDecoration('Счет списания'),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem<int>(
                          value: account.id,
                          child: Text(
                            '${account.name} • ${SomFormatter.amount(account.balance)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedAccountId = value;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _recipientController,
                  decoration: _inputDecoration(_recipientLabel),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration('Сумма в KGS'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  decoration: _inputDecoration('Комментарий'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _quickRecipients
                      .map(
                        (recipient) => ActionChip(
                          backgroundColor: AppTheme.surfaceSoft,
                          side: const BorderSide(color: Colors.white10),
                          label: Text(recipient),
                          onPressed: () {
                            _recipientController.text = recipient;
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _SourceAccountPreview(account: selectedAccount),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTransfer,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SourceAccountPreview extends StatelessWidget {
  const _SourceAccountPreview({required this.account});

  final AccountModel account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF18B869), Color(0xFF00773D)],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'с',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SomFormatter.amount(account.balance),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
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
