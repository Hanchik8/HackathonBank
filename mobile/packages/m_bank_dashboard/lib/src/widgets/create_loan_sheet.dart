import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class LoanDraft {
  const LoanDraft({
    required this.accountId,
    required this.title,
    required this.amount,
    required this.dueDate,
  });

  final int accountId;
  final String title;
  final double amount;
  final DateTime dueDate;
}

class CreateLoanSheet extends StatefulWidget {
  const CreateLoanSheet({
    super.key,
    required this.accounts,
    required this.initialOffsetDays,
  });

  final List<AccountModel> accounts;
  final int initialOffsetDays;

  @override
  State<CreateLoanSheet> createState() => _CreateLoanSheetState();
}

class _CreateLoanSheetState extends State<CreateLoanSheet> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Экспресс-кредит',
  );
  final TextEditingController _amountController = TextEditingController();

  int? _accountId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    final today = DateTime.now();
    _selectedDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: widget.initialOffsetDays));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10, 12, 31),
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
    final accountId = _accountId;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (accountId == null || title.isEmpty || amount == null || amount <= 0) {
      return;
    }

    Navigator.of(context).pop(
      LoanDraft(
        accountId: accountId,
        title: title,
        amount: amount,
        dueDate: _selectedDate,
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
                'Новый кредит',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'В демо-режиме кредит сразу пополнит выбранный счет и появится в прогнозе как будущее погашение.',
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
                decoration: _inputDecoration('Счет зачисления'),
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
                decoration: _inputDecoration('Название кредита'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Сумма кредита в KGS'),
              ),
              const SizedBox(height: 18),
              Text(
                'Дата погашения',
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
                  'Дата погашения: ${AppDateFormatter.shortDate(_selectedDate)}',
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
                  child: const Text('Создать кредит'),
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
