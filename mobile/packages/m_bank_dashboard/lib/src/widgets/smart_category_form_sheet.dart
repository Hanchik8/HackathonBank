import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SmartCategoryDraft {
  const SmartCategoryDraft({
    required this.name,
    required this.plannedMonthly,
  });

  final String name;
  final double plannedMonthly;
}

class SmartCategoryFormSheet extends StatefulWidget {
  const SmartCategoryFormSheet({super.key});

  @override
  State<SmartCategoryFormSheet> createState() => _SmartCategoryFormSheetState();
}

class _SmartCategoryFormSheetState extends State<SmartCategoryFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _plannedMonthlyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _plannedMonthlyController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final plannedMonthly = double.tryParse(
      _plannedMonthlyController.text.replaceAll(',', '.'),
    );
    if (name.isEmpty || plannedMonthly == null || plannedMonthly <= 0) {
      return;
    }

    Navigator.of(context).pop(
      SmartCategoryDraft(name: name, plannedMonthly: plannedMonthly),
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
                'Новая smart-категория',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration('Название категории'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _plannedMonthlyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Месячный лимит в KGS'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Добавить категорию'),
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
}
