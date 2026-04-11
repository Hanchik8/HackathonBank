import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/smart_category_model.dart';
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
    this.preferredSmartCategoryId,
    this.quickCategorySignal = 0,
  });

  final BankApiService apiService;
  final int refreshSignal;
  final VoidCallback onDataChanged;
  final TransferRecipientMode preferredMode;
  final String? preferredSmartCategoryId;
  final int quickCategorySignal;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<AccountModel>? _accounts;
  List<SmartCategory> _smartCategories = const <SmartCategory>[];
  String? _errorMessage;
  int? _selectedAccountId;
  String? _selectedSmartCategoryId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _smartListEnabled = true;
  TransferRecipientMode _mode = TransferRecipientMode.user;

  @override
  void initState() {
    super.initState();
    _mode = widget.preferredMode;
    _selectedSmartCategoryId = widget.preferredSmartCategoryId;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant TransfersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferredMode != widget.preferredMode) {
      setState(() {
        _mode = widget.preferredMode;
      });
    }
    if (oldWidget.quickCategorySignal != widget.quickCategorySignal) {
      setState(() {
        _mode = TransferRecipientMode.merchant;
        _selectedSmartCategoryId = widget.preferredSmartCategoryId;
      });
    } else if (oldWidget.preferredSmartCategoryId !=
        widget.preferredSmartCategoryId) {
      setState(() {
        _selectedSmartCategoryId = widget.preferredSmartCategoryId;
      });
    }
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.apiService.fetchAccounts(),
        widget.apiService.getSmartListEnabled(),
        widget.apiService.fetchSmartCategories(),
      ]);
      if (!mounted) {
        return;
      }

      final accounts = (results[0] as List<AccountModel>)
          .where((account) => account.type == 'MAIN')
          .toList(growable: false);
      final smartListEnabled = results[1] as bool;
      final smartCategories = results[2] as List<SmartCategory>;

      setState(() {
        _accounts = accounts;
        _smartListEnabled = smartListEnabled;
        _smartCategories = smartCategories;
        if (accounts.isEmpty) {
          _selectedAccountId = null;
        } else if (!_containsAccount(accounts, _selectedAccountId)) {
          _selectedAccountId = accounts.first.id;
        }
        if (!_smartCategories.any((item) => item.id == _selectedSmartCategoryId)) {
          _selectedSmartCategoryId = null;
        }
        if (_selectedSmartCategoryId == null &&
            widget.preferredSmartCategoryId != null &&
            _smartCategories.any(
              (item) => item.id == widget.preferredSmartCategoryId,
            )) {
          _selectedSmartCategoryId = widget.preferredSmartCategoryId;
        }
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
      _showMessage('Укажите получателя.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Введите корректную сумму.');
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
        category:
            _selectedSmartCategory == null
                ? _defaultTransactionCategory()
                : _selectedSmartCategory!.name,
        iconKey: _mode == TransferRecipientMode.user ? 'transfer' : 'shopping',
        smartCategoryId: _selectedSmartCategoryId,
      );

      if (!mounted) {
        return;
      }

      _recipientController.clear();
      _amountController.clear();
      _noteController.clear();
      _selectedSmartCategoryId = null;
      widget.onDataChanged();
      _showMessage(result.message);
      await _loadData();
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
      TransferRecipientMode.user => <String>['Aigerim', 'Daniyar', 'Eldiyar'],
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
      TransferRecipientMode.user => 'Имя или телефон',
      TransferRecipientMode.merchant => 'Название магазина',
    };
  }

  String get _submitLabel {
    return switch (_mode) {
      TransferRecipientMode.user => 'Перевести',
      TransferRecipientMode.merchant => 'Оплатить',
    };
  }

  String _defaultTransactionCategory() {
    return switch (_mode) {
      TransferRecipientMode.user => 'Переводы',
      TransferRecipientMode.merchant => 'Покупки',
    };
  }

  SmartCategory? get _selectedSmartCategory {
    for (final category in _smartCategories) {
      if (category.id == _selectedSmartCategoryId) {
        return category;
      }
    }
    return null;
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
    if (accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Нет доступного счета для перевода. Переводы с накопительного депозита отключены.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final selectedAccount = accounts.firstWhere(
      (account) => account.id == _selectedAccountId,
      orElse: () => accounts.first,
    );

    return RefreshIndicator(
      onRefresh: _loadData,
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
                  'Деньги спишутся сразу после подтверждения.',
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
                            '${_displayAccountName(account.name)} • ${SomFormatter.amount(account.balance)}',
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
                if (_smartListEnabled) ...<Widget>[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedSmartCategoryId,
                    isExpanded: true,
                    dropdownColor: AppTheme.surfaceSoft,
                    decoration: _inputDecoration('Smart-категория'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Без smart-категории'),
                      ),
                      ..._smartCategories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: _SmartCategoryMenuItem(category: category),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedSmartCategoryId = value;
                    }),
                  ),
                  if (_selectedSmartCategory != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Остаток по лимиту: ${_formatCategoryRemaining(_selectedSmartCategory!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _selectedSmartCategory!.remaining < 0
                              ? AppTheme.coral
                              : AppTheme.secondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_selectedSmartCategoryId != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Категория уже выбрана из быстрого QR-меню. Можно оставить ее или поменять вручную.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                  if (_smartCategories.isEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Smart List включен, но категории пока пустые. Их можно добавить на экране анализа.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ],
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

  String _displayAccountName(String name) {
    return switch (name) {
      'Main' => 'Основной счет',
      'Savings' => 'Накопительный депозит',
      _ => name,
    };
  }

  bool _containsAccount(List<AccountModel> accounts, int? accountId) {
    if (accountId == null) {
      return false;
    }
    for (final account in accounts) {
      if (account.id == accountId) {
        return true;
      }
    }
    return false;
  }

  String _formatCategoryRemaining(SmartCategory category) {
    final absolute = SomFormatter.amount(category.remaining.abs());
    return category.remaining < 0 ? '-$absolute' : absolute;
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'C',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account.name == 'Main' ? 'Основной счет' : account.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SomFormatter.amount(account.balance),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _SmartCategoryMenuItem extends StatelessWidget {
  const _SmartCategoryMenuItem({required this.category});

  final SmartCategory category;

  @override
  Widget build(BuildContext context) {
    final remainingColor = category.remaining < 0
        ? AppTheme.coral
        : AppTheme.secondaryText;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            category.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _format(category.remaining),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: remainingColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _format(double remaining) {
    final absolute = SomFormatter.amount(remaining.abs());
    return remaining < 0 ? '-$absolute' : absolute;
  }
}
