import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class MyBankScreen extends StatefulWidget {
  const MyBankScreen({super.key, required this.accounts});

  final List<AccountModel> accounts;

  @override
  State<MyBankScreen> createState() => _MyBankScreenState();
}

class _MyBankScreenState extends State<MyBankScreen> {
  bool _depositOpened = true;

  @override
  Widget build(BuildContext context) {
    final mainAccount = widget.accounts.firstWhere(
      (account) => account.type == 'MAIN',
      orElse: () => widget.accounts.first,
    );
    final savingsAccount = widget.accounts.firstWhere(
      (account) => account.type == 'SAVINGS',
      orElse: () => mainAccount,
    );

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
                    _DepositRow(
                      account: savingsAccount,
                      opened: _depositOpened,
                      onToggle: () {
                        setState(() {
                          _depositOpened = !_depositOpened;
                        });
                      },
                    ),
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

class _DepositRow extends StatelessWidget {
  const _DepositRow({
    required this.account,
    required this.opened,
    required this.onToggle,
  });

  final AccountModel account;
  final bool opened;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: opened
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
                  color: opened
                      ? AppTheme.accent.withValues(alpha: 0.16)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  opened ? 'Открыт' : 'Закрыт',
                  style: TextStyle(
                    color: opened ? AppTheme.accent : AppTheme.secondaryText,
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
              color: opened ? AppTheme.accent : Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            opened
                ? 'Доходный продукт MBank. Средства доступны для контроля в любое время.'
                : 'Депозит скрыт из активных продуктов. Его можно снова открыть одной кнопкой.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onToggle,
              style: opened
                  ? null
                  : ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
              child: Text(opened ? 'Закрыть депозит' : 'Открыть депозит'),
            ),
          ),
        ],
      ),
    );
  }
}
