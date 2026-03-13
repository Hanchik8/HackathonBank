import 'package:flutter/material.dart';

import '../services/bank_api_dashboard_repository.dart';
import '../services/bank_api_service.dart';
import '../theme/app_theme.dart';
import 'ai_dashboard_screen.dart';
import 'home_screen.dart';
import 'placeholder_screen.dart';
import 'transfers_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.apiService});

  final BankApiService? apiService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final BankApiService _apiService;
  late final BankApiDashboardRepository _dashboardRepository;

  int _currentIndex = 0;
  int _refreshSignal = 0;
  TransferRecipientMode _preferredTransferMode = TransferRecipientMode.user;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? BankApiService();
    _dashboardRepository = BankApiDashboardRepository(apiService: _apiService);
  }

  void _handleDataChanged() {
    setState(() {
      _refreshSignal++;
    });
  }

  void _openQrAction() {
    setState(() {
      _preferredTransferMode = TransferRecipientMode.merchant;
      _currentIndex = 2;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Открыта оплата магазину.')));
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(apiService: _apiService, refreshSignal: _refreshSignal),
      AiDashboardScreen(
        repository: _dashboardRepository,
        refreshSignal: _refreshSignal,
        onDataChanged: _handleDataChanged,
      ),
      TransfersScreen(
        apiService: _apiService,
        refreshSignal: _refreshSignal,
        onDataChanged: _handleDataChanged,
        preferredMode: _preferredTransferMode,
      ),
      const PlaceholderScreen(
        title: 'Еще',
        subtitle: 'Здесь позже можно разместить настройки, уведомления и профиль.',
      ),
    ];

    return Scaffold(
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
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -110,
              right: -70,
              child: _GlowOrb(
                color: AppTheme.accent.withValues(alpha: 0.08),
                size: 250,
              ),
            ),
            Positioned(
              top: 280,
              left: -60,
              child: _GlowOrb(
                color: AppTheme.blue.withValues(alpha: 0.07),
                size: 200,
              ),
            ),
            SafeArea(
              bottom: false,
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _MbankBottomBar(
        currentIndex: _currentIndex,
        onSelect: (index) => setState(() => _currentIndex = index),
        onQrTap: _openQrAction,
      ),
    );
  }
}

class _MbankBottomBar extends StatelessWidget {
  const _MbankBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onQrTap,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQrTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF151515))),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _NavItem(
              label: 'Главная',
              icon: Icons.home_rounded,
              active: currentIndex == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              label: 'Анализ',
              icon: Icons.bar_chart_rounded,
              active: currentIndex == 1,
              onTap: () => onSelect(1),
            ),
            _QrActionButton(onTap: onQrTap),
            _NavItem(
              label: 'Платежи',
              icon: Icons.swap_horiz_rounded,
              active: currentIndex == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              label: 'Еще',
              icon: Icons.more_horiz_rounded,
              active: currentIndex == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accent : AppTheme.secondaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrActionButton extends StatelessWidget {
  const _QrActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF9D94D), Color(0xFFE2B100)],
          ),
          border: Border.all(color: Colors.black, width: 6),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2600D26A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
