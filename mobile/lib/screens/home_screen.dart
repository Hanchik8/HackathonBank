import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../services/bank_api_service.dart';
import '../services/mock_notifications.dart';
import '../screens/my_bank_screen.dart';
import '../screens/notifications_screen.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';
import '../widgets/bank_card_preview.dart';
import '../widgets/promo_story_card.dart';
import '../widgets/segmented_spend_bar.dart';
import '../widgets/service_shortcut_tile.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiService,
    required this.refreshSignal,
    required this.onDataChanged,
  });

  final BankApiService apiService;
  final int refreshSignal;
  final VoidCallback onDataChanged;

  static const List<String> _monthNames = <String>[
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AccountModel>? _accounts;
  AccountModel? _mainAccount;
  List<TransactionModel>? _transactions;
  List<TransactionModel> _recentTransactions = const <TransactionModel>[];
  List<NotificationModel> _notifications = const <NotificationModel>[];
  DateTime _effectiveDate = DateTime.now();
  int _unreadNotifications = 0;
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  double _qrExpense = 0;
  double _transferExpense = 0;
  double _shoppingExpense = 0;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.apiService.fetchAccounts(),
        widget.apiService.fetchTransactions(),
        widget.apiService.getEffectiveDate(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        final accounts = results[0] as List<AccountModel>;
        final transactions = results[1] as List<TransactionModel>;
        final effectiveDate = results[2] as DateTime;
        _accounts = accounts;
        _transactions = transactions;
        _effectiveDate = effectiveDate;
        _recomputeDerivedState(
          accounts: accounts,
          transactions: transactions,
          effectiveDate: effectiveDate,
        );
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

  void _recomputeDerivedState({
    required List<AccountModel> accounts,
    required List<TransactionModel> transactions,
    required DateTime effectiveDate,
  }) {
    _mainAccount = accounts.firstWhere(
      (account) => account.type == 'MAIN',
      orElse: () => accounts.first,
    );
    _recentTransactions = transactions.take(6).toList(growable: false);
    _notifications = getMockNotifications(transactions: transactions);
    _unreadNotifications = _notifications
        .where((notification) => !notification.isRead)
        .length;

    final currentMonth = effectiveDate.month;
    final monthTransactions = transactions.where(
      (transaction) => transaction.occurredAt.month == currentMonth,
    );

    var monthlyIncome = 0.0;
    var monthlyExpense = 0.0;
    var qrExpense = 0.0;
    var transferExpense = 0.0;
    var shoppingExpense = 0.0;

    for (final transaction in monthTransactions) {
      final amount = transaction.amount;
      if (amount > 0) {
        monthlyIncome += amount;
      }
      if (amount < 0 && transaction.status == 'COMPLETED') {
        final absoluteAmount = amount.abs();
        monthlyExpense += absoluteAmount;
        if (transaction.type == 'QR_TRANSFER') {
          qrExpense += absoluteAmount;
        }
        if (transaction.type == 'TRANSFER') {
          transferExpense += absoluteAmount;
        }
        if (transaction.iconKey == 'shopping') {
          shoppingExpense += absoluteAmount;
        }
      }
    }

    _monthlyIncome = monthlyIncome;
    _monthlyExpense = monthlyExpense;
    _qrExpense = qrExpense;
    _transferExpense = transferExpense;
    _shoppingExpense = shoppingExpense;
  }

  Future<void> _openMyBankScreen(List<AccountModel> accounts) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyBankScreen(
          apiService: widget.apiService,
          accounts: accounts,
          onAccountsChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  Future<void> _openNotificationsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          apiService: widget.apiService,
          transactions: _transactions ?? const <TransactionModel>[],
          notifications: _notifications,
          onSmartListChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    final accounts = _accounts!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: <Widget>[
          _HeaderRow(
            unreadNotifications: _unreadNotifications,
            onNotificationsTap: _openNotificationsScreen,
          ),
          const SizedBox(height: 20),
          const _TopTabs(),
          const SizedBox(height: 18),
          const SizedBox(height: 130, child: _StoryRow()),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MonthSummaryCard(
                  title:
                      'За ${HomeScreen._monthNames[_effectiveDate.month - 1]}',
                  value: SomFormatter.amount(
                    _monthlyExpense,
                    fractionDigits: 0,
                  ),
                  segments: <SpendSegment>[
                    SpendSegment(color: AppTheme.blue, value: _qrExpense),
                    SpendSegment(
                      color: AppTheme.accent,
                      value: _transferExpense,
                    ),
                    SpendSegment(
                      color: AppTheme.yellow,
                      value: _shoppingExpense,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _BonusCard()),
            ],
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 156, child: _HeroBannerRow()),
          const SizedBox(height: 18),
          BankCardPreview(
            account: _mainAccount ?? accounts.first,
            cardLabel: '\u2022\u20220484',
            onTap: () => _openMyBankScreen(accounts),
          ),
          const SizedBox(height: 18),
          const _ShortcutStrip(),
          const SizedBox(height: 28),
          const _ScrolledBannerRow(),
          const SizedBox(height: 18),
          _MyBankCard(onTap: () => _openMyBankScreen(accounts)),
          const SizedBox(height: 18),
          const _MarketplacePanel(),
          const SizedBox(height: 18),
          const _ServiceGridPanel(),
          const SizedBox(height: 18),
          const SizedBox(height: 150, child: _UtilityRow()),
          const SizedBox(height: 26),
          Text(
            'Последние операции',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ..._recentTransactions.map(
            (transaction) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TransactionTile(transaction: transaction),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Поступления за ${HomeScreen._monthNames[_effectiveDate.month - 1]}: ${SomFormatter.amount(_monthlyIncome)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.unreadNotifications,
    required this.onNotificationsTap,
  });

  final int unreadNotifications;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[Color(0xFF6E6E6E), Color(0xFF1B1B1B)],
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'A',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: <Widget>[
              Text(
                'Азизхан',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
        const _HeaderIcon(icon: Icons.chat_bubble_rounded),
        const SizedBox(width: 12),
        _HeaderIcon(
          icon: Icons.notifications_outlined,
          badge: unreadNotifications > 0
              ? unreadNotifications.toString()
              : null,
          onTap: onNotificationsTap,
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.badge, this.onTap});

  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(icon, color: AppTheme.accent, size: 28),
            ),
            if (badge != null)
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8475D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _TabLabel(label: 'MMarket', active: false),
            const SizedBox(width: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8475D),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'НОВОЕ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 26),
            const _TabLabel(label: 'MBank', active: true),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 118,
          height: 3,
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: const <Widget>[
        PromoStoryCard(
          title: 'Афиша недели',
          subtitle: 'События и скидки',
          icon: Icons.theaters_rounded,
          colors: <Color>[Color(0xFF4F0F06), Color(0xFF191312)],
          borderColor: Color(0xFF8A360D),
        ),
        PromoStoryCard(
          title: 'Крипта за минуту',
          subtitle: 'Прямо в приложении',
          icon: Icons.auto_awesome_rounded,
          colors: <Color>[Color(0xFF5E37F3), Color(0xFF1D173B)],
          borderColor: Color(0xFF58A3FF),
        ),
        PromoStoryCard(
          title: '"Платина" от 1 сома',
          subtitle: 'Карты и тарифы',
          icon: Icons.credit_card_rounded,
          colors: <Color>[Color(0xFF2C7A7B), Color(0xFFE5E1D8)],
          borderColor: Color(0xFFE5E1D8),
        ),
        PromoStoryCard(
          title: 'Подарки к марту!',
          subtitle: 'Свежие предложения',
          icon: Icons.local_florist_rounded,
          colors: <Color>[Color(0xFF4AAE8E), Color(0xFFD7FCD7)],
          borderColor: Color(0xFF7DE1A5),
        ),
      ],
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.title,
    required this.value,
    required this.segments,
  });

  final String title;
  final String value;
  final List<SpendSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          SegmentedSpendBar(segments: segments, height: 18),
        ],
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Мои бонусы',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '0 Б',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            children: const <Widget>[
              _RewardChip(color: Color(0xFFB9F0EF), label: 'БИЛЕТ'),
              _RewardChip(color: Color(0xFFFFEE9B), label: 'МАРКЕТ'),
              _RewardChip(color: Color(0xFFFFA561), label: 'КЭШ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 6,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroBannerRow extends StatelessWidget {
  const _HeroBannerRow();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: const <Widget>[
        _PromoBanner(
          width: 280,
          title: 'Скидки\nдо 50%\nв MMarket!',
          colors: <Color>[Color(0xFF22A6A4), Color(0xFFD9FBD4)],
          accent: Color(0xFFEE6CB2),
        ),
        SizedBox(width: 12),
        _PromoBanner(
          width: 190,
          title: 'Кешбэк\n20% с QR',
          colors: <Color>[Color(0xFF0B8F4A), Color(0xFF30CC73)],
          accent: Color(0xFF0A773D),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.width,
    required this.title,
    required this.colors,
    required this.accent,
  });

  final double width;
  final String title;
  final List<Color> colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: 4,
            bottom: -4,
            child: Icon(Icons.filter_vintage_rounded, size: 88, color: accent),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutStrip extends StatelessWidget {
  const _ShortcutStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: <Widget>[
          ServiceShortcutTile(
            icon: Icons.shopping_cart_rounded,
            colors: <Color>[Color(0xFF8CF327), Color(0xFF38AA19)],
          ),
          ServiceShortcutTile(
            icon: Icons.airplanemode_active_rounded,
            colors: <Color>[Color(0xFF52B6FF), Color(0xFF3C7DFF)],
          ),
          ServiceShortcutTile(
            icon: Icons.contactless_rounded,
            colors: <Color>[Color(0xFF00C8A6), Color(0xFF008A76)],
          ),
          ServiceShortcutTile(
            icon: Icons.percent_rounded,
            colors: <Color>[Color(0xFFFF8B26), Color(0xFFFF5E00)],
          ),
          ServiceShortcutTile(
            icon: Icons.flag_rounded,
            colors: <Color>[Color(0xFF2A2A2A), Color(0xFF080808)],
          ),
        ],
      ),
    );
  }
}

class _ScrolledBannerRow extends StatelessWidget {
  const _ScrolledBannerRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const <Widget>[
          _WidePromoCard(
            width: 430,
            title: 'Карамазовы\n10-11 апреля',
            colors: <Color>[Color(0xFFC00000), Color(0xFF250404)],
          ),
          SizedBox(width: 12),
          _WidePromoCard(
            width: 170,
            title: 'Погаси\nрассрочку',
            colors: <Color>[Color(0xFFFE7A10), Color(0xFFD64A00)],
          ),
        ],
      ),
    );
  }
}

class _WidePromoCard extends StatelessWidget {
  const _WidePromoCard({
    required this.width,
    required this.title,
    required this.colors,
  });

  final double width;
  final String title;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _MyBankCard extends StatelessWidget {
  const _MyBankCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFF0FCD7C), Color(0xFF18B1D8)],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: <Widget>[
                        Text(
                          'Мой банк',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Счета и карты',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.secondaryText,
                      ),
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

class _MarketplacePanel extends StatelessWidget {
  const _MarketplacePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: <Widget>[
          _LabeledShortcut(
            label: 'MMarket',
            icon: Icons.shopping_cart_rounded,
            colors: <Color>[Color(0xFF8CF327), Color(0xFF38AA19)],
          ),
          _LabeledShortcut(
            label: 'MTravel',
            icon: Icons.airplanemode_active_rounded,
            colors: <Color>[Color(0xFF52B6FF), Color(0xFF16D7CB)],
          ),
          _LabeledShortcut(
            label: 'MInvest',
            icon: Icons.show_chart_rounded,
            colors: <Color>[Color(0xFF6E6BFF), Color(0xFFC97FFF)],
          ),
          _LabeledShortcut(
            label: 'Услуги',
            icon: Icons.percent_rounded,
            colors: <Color>[Color(0xFFFF8B26), Color(0xFFFF5E00)],
          ),
          _LabeledShortcut(
            label: 'MBusiness',
            icon: Icons.flag_rounded,
            colors: <Color>[Color(0xFF2A2A2A), Color(0xFF080808)],
          ),
        ],
      ),
    );
  }
}

class _LabeledShortcut extends StatelessWidget {
  const _LabeledShortcut({
    required this.label,
    required this.icon,
    required this.colors,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            height: 62,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ServiceGridPanel extends StatelessWidget {
  const _ServiceGridPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _FeatureItem(
                  label: 'Рассрочка',
                  icon: Icons.percent_rounded,
                  color: Color(0xFFFFA00A),
                ),
              ),
              Expanded(
                child: _FeatureItem(
                  label: 'Кредиты',
                  icon: Icons.percent_rounded,
                  color: Color(0xFF3B9BDB),
                ),
              ),
              Expanded(
                child: _FeatureItem(
                  label: 'Депозиты',
                  icon: Icons.savings_rounded,
                  color: Color(0xFF59C88E),
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: _FeatureItem(
                  label: 'Заказ карты',
                  icon: Icons.credit_card_rounded,
                  color: Color(0xFFF06363),
                ),
              ),
              Expanded(
                child: _FeatureItem(
                  label: 'Пригласи\nдруга!',
                  icon: Icons.card_giftcard_rounded,
                  color: Color(0xFFD55AB7),
                ),
              ),
              Expanded(
                child: _FeatureItem(
                  label: 'MBANK\nJunior',
                  icon: Icons.pets_rounded,
                  color: Color(0xFFA185EE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _UtilityRow extends StatelessWidget {
  const _UtilityRow();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: const <Widget>[
        _UtilityCard(
          label: 'Мой QR',
          icon: Icons.qr_code_rounded,
          color: Color(0xFF8D45FF),
        ),
        SizedBox(width: 14),
        _UtilityCard(
          label: 'Онлайн\nочередь',
          icon: Icons.chair_rounded,
          color: Color(0xFF4C72FF),
        ),
        SizedBox(width: 14),
        _UtilityCard(
          label: 'Лимиты\nMBANK',
          icon: Icons.tune_rounded,
          color: Color(0xFFB17CFF),
        ),
        SizedBox(width: 14),
        _UtilityCard(
          label: 'Пункты\nсервиса',
          icon: Icons.storefront_rounded,
          color: Color(0xFF11B79B),
        ),
      ],
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Не удалось загрузить данные',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryText),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
