import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/bank_api_service.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HackathonBankApp());
}

class HackathonBankApp extends StatelessWidget {
  const HackathonBankApp({super.key, this.apiService});

  final BankApiService? apiService;

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'ru_RU';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HackathonBank',
      theme: AppTheme.darkTheme,
      home: AppShell(apiService: apiService),
    );
  }
}
