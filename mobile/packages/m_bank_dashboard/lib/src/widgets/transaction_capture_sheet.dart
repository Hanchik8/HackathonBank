import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/smart_category_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class TransactionCaptureDraft {
  const TransactionCaptureDraft({
    required this.accountId,
    required this.title,
    required this.counterparty,
    required this.amount,
    required this.type,
    required this.categoryLabel,
    required this.iconKey,
    this.smartCategoryId,
  });

  final int accountId;
  final String title;
  final String counterparty;
  final double amount;
  final String type;
  final String categoryLabel;
  final String iconKey;
  final String? smartCategoryId;
}

class TransactionCaptureSheet extends StatefulWidget {
  const TransactionCaptureSheet({
    super.key,
    required this.accounts,
    required this.smartCategories,
    required this.smartListEnabled,
  });

  final List<AccountModel> accounts;
  final List<SmartCategory> smartCategories;
  final bool smartListEnabled;

  @override
  State<TransactionCaptureSheet> createState() => _TransactionCaptureSheetState();
}

class _TransactionCaptureSheetState extends State<TransactionCaptureSheet> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Оплата',
  );
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  int? _accountId;
  String _type = 'QR_TRANSFER';
  String? _smartCategoryId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _counterpartyController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final accountId = _accountId;
    final title = _titleController.text.trim();
    final counterparty = _counterpartyController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (accountId == null || title.isEmpty || amount == null || amount <= 0) {
      return;
    }

    final selectedSmartCategory =
        !widget.smartListEnabled || _smartCategoryId == null
        ? null
        : widget.smartCategories.firstWhere(
            (category) => category.id == _smartCategoryId,
            orElse: () => const SmartCategory(
              id: '',
              name: '',
              plannedMonthly: 0,
              remaining: 0,
            ),
          );

    Navigator.of(context).pop(
      TransactionCaptureDraft(
        accountId: accountId,
        title: title,
        counterparty: counterparty.isEmpty ? title : counterparty,
        amount: amount,
        type: _type,
        categoryLabel: selectedSmartCategory == null || selectedSmartCategory.id.isEmpty
            ? (_type == 'QR_TRANSFER' ? 'Оплата по QR' : 'Переводы')
            : selectedSmartCategory.name,
        iconKey: _iconForTransactionType(_type, selectedSmartCategory),
        smartCategoryId:
            selectedSmartCategory == null || selectedSmartCategory.id.isEmpty
            ? null
            : selectedSmartCategory.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 32,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Новый платеж',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.smartListEnabled
                    ? 'После оплаты можно сразу привязать расход к smart-категории.'
                    : 'Smart List выключен. Платеж сохранится без привязки к категории.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceSoft,
                decoration: _inputDecoration('Счет списания'),
                items: widget.accounts
                    .map(
                      (account) => DropdownMenuItem<int>(
                        value: account.id,
                        child: Text(
                          '${_displayAccountName(account.name)} · ${SomFormatter.amount(account.balance)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 14),
              Text(
                'Тип операции',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _OptionChip(
                      label: 'QR',
                      selected: _type == 'QR_TRANSFER',
                      onTap: () => setState(() => _type = 'QR_TRANSFER'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OptionChip(
                      label: 'Перевод',
                      selected: _type == 'TRANSFER',
                      onTap: () => setState(() => _type = 'TRANSFER'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: _inputDecoration('Название операции'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _counterpartyController,
                decoration: _inputDecoration('Получатель'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Сумма в KGS'),
              ),
              if (widget.smartListEnabled) ...<Widget>[
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _smartCategoryId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceSoft,
                  decoration: _inputDecoration('Smart-категория'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Без smart-категории'),
                    ),
                    ...widget.smartCategories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: _SmartCategoryMenuItem(category: category),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _smartCategoryId = value),
                ),
                if (_selectedSmartCategory != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Остаток по лимиту: ${_formatRemaining(_selectedSmartCategory!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _selectedSmartCategory!.remaining < 0
                            ? AppTheme.coral
                            : AppTheme.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Сохранить платеж'),
                ),
              ),
            ],
          ),
        ),
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

  String _iconForTransactionType(
    String type,
    SmartCategory? selectedSmartCategory,
  ) {
    final name = selectedSmartCategory?.name.toLowerCase() ?? '';
    if (name.contains('ед')) {
      return 'food';
    }
    if (name.contains('развлеч')) {
      return 'shopping';
    }
    return type == 'QR_TRANSFER' ? 'qr' : 'payment';
  }

  String _displayAccountName(String name) {
    return switch (name) {
      'Main' => 'Основной счет',
      'Savings' => 'Сбережения',
      _ => name,
    };
  }

  SmartCategory? get _selectedSmartCategory {
    if (_smartCategoryId == null) {
      return null;
    }
    for (final category in widget.smartCategories) {
      if (category.id == _smartCategoryId) {
        return category;
      }
    }
    return null;
  }

  String _formatRemaining(SmartCategory category) {
    final absolute = SomFormatter.amount(category.remaining.abs());
    return category.remaining < 0 ? '-$absolute' : absolute;
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
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
