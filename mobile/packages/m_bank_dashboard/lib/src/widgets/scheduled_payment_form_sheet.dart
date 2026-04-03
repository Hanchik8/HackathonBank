import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class ScheduledPaymentDraft {
  const ScheduledPaymentDraft({
    required this.accountId,
    required this.title,
    required this.counterparty,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.isReminder,
  });

  final int accountId;
  final String title;
  final String counterparty;
  final String category;
  final double amount;
  final DateTime dueDate;
  final bool isReminder;
}

class ScheduledPaymentFormSheet extends StatefulWidget {
  const ScheduledPaymentFormSheet({
    super.key,
    required this.accounts,
    required this.initialOffsetDays,
    this.referenceDate,
  });

  final List<AccountModel> accounts;
  final int initialOffsetDays;
  final DateTime? referenceDate;

  @override
  State<ScheduledPaymentFormSheet> createState() =>
      _ScheduledPaymentFormSheetState();
}

class _ScheduledPaymentFormSheetState extends State<ScheduledPaymentFormSheet> {
  static const List<String> _quickCategories = <String>[
    'Аренда',
    'Подписки',
    'Коммунальные',
    'Образование',
    'Страхование',
    'Покупки',
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: _quickCategories.first,
  );

  int? _accountId;
  bool _isReminder = true;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    final base = widget.referenceDate ?? DateTime.now();
    _selectedDate = DateTime(
      base.year,
      base.month,
      base.day,
    ).add(Duration(days: widget.initialOffsetDays));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _counterpartyController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final base = widget.referenceDate ?? DateTime.now();
    final firstDate = DateTime(base.year, base.month, base.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(base.year + 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              surface: AppTheme.surface,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppTheme.surface),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final counterparty = _counterpartyController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final category = _categoryController.text.trim();
    if (_accountId == null ||
        title.isEmpty ||
        category.isEmpty ||
        amount == null ||
        amount <= 0) {
      return;
    }

    Navigator.of(context).pop(
      ScheduledPaymentDraft(
        accountId: _accountId!,
        title: title,
        counterparty: counterparty.isEmpty ? title : counterparty,
        category: category,
        amount: amount,
        dueDate: _selectedDate,
        isReminder: _isReminder,
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
                'Новый отложенный платеж',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Добавьте будущее списание, и ИИ сразу учтет его в прогнозе.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.45,
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
                          '${_displayAccountName(account.name)} • ${SomFormatter.amount(account.balance)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: _inputDecoration('Название платежа'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _counterpartyController,
                decoration: _inputDecoration('Получатель'),
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
                controller: _categoryController,
                decoration: _inputDecoration('Категория'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _quickCategories
                    .map(
                      (category) => _SelectableChip(
                        label: category,
                        selected: _categoryController.text.trim() == category,
                        onTap: () => setState(() {
                          _categoryController.text = category;
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isReminder,
                activeTrackColor: AppTheme.accent,
                title: Text(
                  'Напоминание для прогноза',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _isReminder
                      ? 'Будет выделено как напоминание в списке будущих списаний.'
                      : 'Будет учтено как обычный обязательный платеж.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                onChanged: (value) => setState(() => _isReminder = value),
              ),
              const SizedBox(height: 18),
              Text(
                'Когда списать',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(
                  'Выбрать дату: ${AppDateFormatter.shortDate(_selectedDate)}',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Дата списания: ${AppDateFormatter.shortDate(_selectedDate)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Запланировать платеж'),
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

  String _displayAccountName(String name) {
    return switch (name) {
      'Main' => 'Основной счет',
      'Savings' => 'Сбережения',
      _ => name,
    };
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
