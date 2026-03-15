import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../theme/app_date_formatter.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

enum AdminModeActionKind { setDate, addFunds, removeFunds }

class AdminModeAction {
  const AdminModeAction({
    required this.kind,
    required this.effectiveDate,
    this.accountId,
    this.amount = 0,
    this.title = '',
  });

  final AdminModeActionKind kind;
  final DateTime effectiveDate;
  final int? accountId;
  final double amount;
  final String title;
}

class AdminModeSheet extends StatefulWidget {
  const AdminModeSheet({
    super.key,
    required this.accounts,
    required this.effectiveDate,
  });

  final List<AccountModel> accounts;
  final DateTime effectiveDate;

  @override
  State<AdminModeSheet> createState() => _AdminModeSheetState();
}

class _AdminModeSheetState extends State<AdminModeSheet> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Зарплата',
  );
  final TextEditingController _amountController = TextEditingController();

  int? _accountId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.first.id;
    _selectedDate = DateTime(
      widget.effectiveDate.year,
      widget.effectiveDate.month,
      widget.effectiveDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final firstDate = DateTime(2024, 1, 1);
    final lastDate = DateTime(DateTime.now().year + 2, 12, 31);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              surface: AppTheme.surface,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.surface,
            ),
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

  void _submit(AdminModeActionKind kind) {
    if (kind == AdminModeActionKind.setDate) {
      Navigator.of(context).pop(
        AdminModeAction(kind: kind, effectiveDate: _selectedDate),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (_accountId == null || amount == null || amount <= 0) {
      return;
    }
    Navigator.of(context).pop(
      AdminModeAction(
        kind: kind,
        effectiveDate: _selectedDate,
        accountId: _accountId,
        amount: amount,
        title: _titleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
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
                'Режим Админа',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Задайте текущую дату и вручную скорректируйте баланс, чтобы проверить аналитику дохода и переносы платежей.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.manage_history_rounded),
                label: Text(
                  'Текущая дата: ${AppDateFormatter.shortDate(_selectedDate)}',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submit(AdminModeActionKind.setDate),
                  child: const Text('Применить дату'),
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                dropdownColor: AppTheme.surfaceSoft,
                decoration: _inputDecoration('Счет'),
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
                decoration: _inputDecoration('Комментарий / источник'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Сумма в KGS'),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(AdminModeActionKind.removeFunds),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.coral,
                        side: const BorderSide(color: Color(0x44FF8B8B)),
                      ),
                      child: const Text('Списать'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submit(AdminModeActionKind.addFunds),
                      child: const Text('Пополнить'),
                    ),
                  ),
                ],
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
      'Savings' => 'Накопительный депозит',
      _ => name,
    };
  }
}
