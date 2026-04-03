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
  const SmartCategoryFormSheet({
    super.key,
    this.initialName = '',
    this.initialPlannedMonthly,
    this.title,
    this.submitLabel,
  });

  final String initialName;
  final double? initialPlannedMonthly;
  final String? title;
  final String? submitLabel;

  @override
  State<SmartCategoryFormSheet> createState() => _SmartCategoryFormSheetState();
}

class _SmartCategoryFormSheetState extends State<SmartCategoryFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _plannedMonthlyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _plannedMonthlyController = TextEditingController(
      text: widget.initialPlannedMonthly == null
          ? ''
          : widget.initialPlannedMonthly!.toStringAsFixed(0),
    );
  }

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
                widget.title ?? '\u041d\u043e\u0432\u0430\u044f smart-\u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044f',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(
                  '\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u0438',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _plannedMonthlyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  '\u041c\u0435\u0441\u044f\u0447\u043d\u044b\u0439 \u043b\u0438\u043c\u0438\u0442 \u0432 KGS',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    widget.submitLabel ??
                        '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043a\u0430\u0442\u0435\u0433\u043e\u0440\u0438\u044e',
                  ),
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
