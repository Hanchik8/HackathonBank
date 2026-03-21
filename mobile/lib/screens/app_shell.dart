import 'package:flutter/material.dart';

import '../models/scheduled_payment_model.dart';
import '../models/smart_category_model.dart';
import '../services/bank_api_dashboard_repository.dart';
import '../services/bank_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/due_payment_banner.dart';
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
  int _quickCategorySignal = 0;
  TransferRecipientMode _preferredTransferMode = TransferRecipientMode.user;
  String? _preferredSmartCategoryId;
  List<SmartCategory> _favoriteSmartCategories = const <SmartCategory>[];
  List<ScheduledPaymentModel> _dueTodayPayments =
      const <ScheduledPaymentModel>[];
  bool _isDueBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? BankApiService();
    _dashboardRepository = BankApiDashboardRepository(apiService: _apiService);
    _refreshFavoriteCategories();
    _refreshDuePaymentBanner();
  }

  void _handleDataChanged() {
    setState(() {
      _refreshSignal++;
    });
    _refreshFavoriteCategories();
    _refreshDuePaymentBanner(resetDismissal: true);
  }

  Future<void> _refreshFavoriteCategories() async {
    try {
      final smartListEnabled = await _apiService.getSmartListEnabled();
      if (!smartListEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _favoriteSmartCategories = const <SmartCategory>[];
          _preferredSmartCategoryId = null;
        });
        return;
      }

      final categories = await _apiService.fetchSmartCategories();
      if (!mounted) {
        return;
      }
      final favorites = categories
          .where((category) => category.isFavorite)
          .take(3)
          .toList(growable: false);
      final hasPreferred = _preferredSmartCategoryId != null &&
          favorites.any((category) => category.id == _preferredSmartCategoryId);
      setState(() {
        _favoriteSmartCategories = favorites;
        if (!hasPreferred) {
          _preferredSmartCategoryId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteSmartCategories = const <SmartCategory>[];
      });
    }
  }

  Future<void> _refreshDuePaymentBanner({bool resetDismissal = false}) async {
    const noPayments = <ScheduledPaymentModel>[];

    try {
      final effectiveDate = await _apiService.getEffectiveDate();
      final horizonDays = _daysUntilEndOfMonthFrom(effectiveDate);
      final dashboard = await _apiService.fetchDashboard(horizonDays);
      final dueTodayPayments = dashboard.scheduledPayments
          .where((payment) => _isSameDay(payment.dueDate, effectiveDate))
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      _setDuePaymentBannerState(
        dueTodayPayments,
        resetDismissal: resetDismissal,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _setDuePaymentBannerState(noPayments, resetDismissal: resetDismissal);
    }
  }

  void _setDuePaymentBannerState(
    List<ScheduledPaymentModel> payments, {
    required bool resetDismissal,
  }) {
    setState(() {
      _dueTodayPayments = payments;
      if (resetDismissal || payments.isEmpty) {
        _isDueBannerDismissed = false;
      }
    });
  }

  void _openQrAction({String? smartCategoryId}) {
    final selectedCategory = _favoriteSmartCategories
        .where((category) => category.id == smartCategoryId)
        .firstOrNull;

    setState(() {
      _preferredTransferMode = TransferRecipientMode.merchant;
      _preferredSmartCategoryId = smartCategoryId;
      _quickCategorySignal++;
      _currentIndex = 2;
    });

    final message = selectedCategory == null
        ? 'Открыта оплата магазину.'
        : 'Открыта оплата магазину с категорией "${selectedCategory.name}".';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showDueBanner =
        _dueTodayPayments.isNotEmpty && !_isDueBannerDismissed;
    final screens = <Widget>[
      HomeScreen(
        apiService: _apiService,
        refreshSignal: _refreshSignal,
        onDataChanged: _handleDataChanged,
      ),
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
        preferredSmartCategoryId: _preferredSmartCategoryId,
        quickCategorySignal: _quickCategorySignal,
      ),
      const PlaceholderScreen(
        title: 'Еще',
        subtitle:
            'Здесь позже можно разместить настройки, уведомления и профиль.',
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
              child: Column(
                children: <Widget>[
                  if (showDueBanner)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: DuePaymentBanner(
                        payments: _dueTodayPayments,
                        onOpenAnalysis: () => setState(() => _currentIndex = 1),
                        onDismiss: () => setState(
                          () => _isDueBannerDismissed = true,
                        ),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(index: _currentIndex, children: screens),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _MbankBottomBar(
        currentIndex: _currentIndex,
        favoriteCategories: _favoriteSmartCategories,
        onSelect: (index) => setState(() => _currentIndex = index),
        onQrTap: () => _openQrAction(),
        onQuickCategorySelected: (category) =>
            _openQrAction(smartCategoryId: category.id),
      ),
    );
  }
}

class _MbankBottomBar extends StatelessWidget {
  const _MbankBottomBar({
    required this.currentIndex,
    required this.favoriteCategories,
    required this.onSelect,
    required this.onQrTap,
    required this.onQuickCategorySelected,
  });

  final int currentIndex;
  final List<SmartCategory> favoriteCategories;
  final ValueChanged<int> onSelect;
  final VoidCallback onQrTap;
  final ValueChanged<SmartCategory> onQuickCategorySelected;

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
            _QrActionButton(
              onTap: onQrTap,
              favoriteCategories: favoriteCategories,
              onQuickCategorySelected: onQuickCategorySelected,
            ),
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

class _QrActionButton extends StatefulWidget {
  const _QrActionButton({
    required this.onTap,
    required this.favoriteCategories,
    required this.onQuickCategorySelected,
  });

  final VoidCallback onTap;
  final List<SmartCategory> favoriteCategories;
  final ValueChanged<SmartCategory> onQuickCategorySelected;

  @override
  State<_QrActionButton> createState() => _QrActionButtonState();
}

class _QrActionButtonState extends State<_QrActionButton> {
  final GlobalKey _buttonKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  String? _hoveredCategoryId;
  List<_QuickCategoryAnchor> _anchors = const <_QuickCategoryAnchor>[];

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QrActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null &&
        oldWidget.favoriteCategories != widget.favoriteCategories) {
      _removeOverlay();
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.favoriteCategories.isEmpty) {
      return;
    }
    _showOverlay();
    _updateHovered(details.globalPosition);
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    _updateHovered(details.globalPosition);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final selectedCategory = _anchors
        .where((anchor) => anchor.category.id == _hoveredCategoryId)
        .map((anchor) => anchor.category)
        .firstOrNull;
    _removeOverlay();
    if (selectedCategory != null) {
      widget.onQuickCategorySelected(selectedCategory);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || renderBox == null) {
      return;
    }

    final origin = renderBox.localToGlobal(Offset.zero);
    final buttonRect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
    _anchors = _buildAnchors(buttonRect, widget.favoriteCategories);

    _overlayEntry = OverlayEntry(
      builder: (context) => _QuickQrOverlay(
        anchors: _anchors,
        hoveredCategoryId: _hoveredCategoryId,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _hoveredCategoryId = null;
    _anchors = const <_QuickCategoryAnchor>[];
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateHovered(Offset globalPosition) {
    if (_overlayEntry == null) {
      return;
    }
    final hoveredAnchor = _anchors
        .where(
          (anchor) =>
              (anchor.center - globalPosition).distance <= anchor.radius + 10,
        )
        .firstOrNull;
    final nextHoveredId = hoveredAnchor?.category.id;
    if (nextHoveredId == _hoveredCategoryId) {
      return;
    }
    setState(() {
      _hoveredCategoryId = nextHoveredId;
    });
    _overlayEntry?.markNeedsBuild();
  }

  List<_QuickCategoryAnchor> _buildAnchors(
    Rect buttonRect,
    List<SmartCategory> categories,
  ) {
    const radius = 34.0;
    final center = buttonRect.center;
    final positions = switch (categories.length) {
      1 => <Offset>[Offset(center.dx, center.dy - 92)],
      2 => <Offset>[
        Offset(center.dx - 58, center.dy - 78),
        Offset(center.dx + 58, center.dy - 78),
      ],
      _ => <Offset>[
        Offset(center.dx - 68, center.dy - 78),
        Offset(center.dx, center.dy - 110),
        Offset(center.dx + 68, center.dy - 78),
      ],
    };

    return List<_QuickCategoryAnchor>.generate(
      categories.length,
      (index) => _QuickCategoryAnchor(
        category: categories[index],
        center: positions[index],
        radius: radius,
      ),
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: widget.onTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressMoveUpdate: _handleLongPressMove,
      onLongPressEnd: _handleLongPressEnd,
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

class _QuickQrOverlay extends StatelessWidget {
  const _QuickQrOverlay({
    required this.anchors,
    required this.hoveredCategoryId,
  });

  final List<_QuickCategoryAnchor> anchors;
  final String? hoveredCategoryId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
            for (final anchor in anchors)
              Positioned(
                left: anchor.center.dx - anchor.radius,
                top: anchor.center.dy - anchor.radius,
                child: _QuickCategoryBubble(
                  category: anchor.category,
                  highlighted: anchor.category.id == hoveredCategoryId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickCategoryBubble extends StatelessWidget {
  const _QuickCategoryBubble({
    required this.category,
    required this.highlighted,
  });

  final SmartCategory category;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category.name);
    return AnimatedScale(
      duration: const Duration(milliseconds: 100),
      scale: highlighted ? 1.12 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted ? AppTheme.surface : const Color(0xFFF2F2F2),
          border: Border.all(
            color: highlighted ? AppTheme.accent : Colors.white,
            width: 2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.35 : 0.18),
              blurRadius: highlighted ? 22 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(_categoryIcon(category.name), color: color, size: 24),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: highlighted ? Colors.white : Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('ед') ||
        normalized.contains('продукт') ||
        normalized.contains('food') ||
        normalized.contains('grocery')) {
      return Icons.restaurant_rounded;
    }
    if (normalized.contains('транспорт') ||
        normalized.contains('такси') ||
        normalized.contains('travel') ||
        normalized.contains('transport')) {
      return Icons.directions_car_filled_rounded;
    }
    if (normalized.contains('перевод') || normalized.contains('transfer')) {
      return Icons.swap_horiz_rounded;
    }
    if (normalized.contains('развлеч') || normalized.contains('fun')) {
      return Icons.movie_filter_rounded;
    }
    if (normalized.contains('покуп') ||
        normalized.contains('shop') ||
        normalized.contains('market')) {
      return Icons.shopping_bag_rounded;
    }
    return Icons.category_rounded;
  }

  static Color _categoryColor(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('ед') ||
        normalized.contains('продукт') ||
        normalized.contains('food') ||
        normalized.contains('grocery')) {
      return const Color(0xFF0EBE7F);
    }
    if (normalized.contains('транспорт') ||
        normalized.contains('такси') ||
        normalized.contains('travel') ||
        normalized.contains('transport')) {
      return const Color(0xFF3F8CFF);
    }
    if (normalized.contains('перевод') || normalized.contains('transfer')) {
      return const Color(0xFF23D160);
    }
    if (normalized.contains('развлеч') || normalized.contains('fun')) {
      return const Color(0xFFE8505B);
    }
    if (normalized.contains('покуп') ||
        normalized.contains('shop') ||
        normalized.contains('market')) {
      return const Color(0xFFF5D547);
    }
    return AppTheme.accent;
  }
}

class _QuickCategoryAnchor {
  const _QuickCategoryAnchor({
    required this.category,
    required this.center,
    required this.radius,
  });

  final SmartCategory category;
  final Offset center;
  final double radius;
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

int _daysUntilEndOfMonthFrom(DateTime date) {
  final monthEnd = DateTime(date.year, date.month + 1, 0);
  final current = DateTime(date.year, date.month, date.day);
  return monthEnd.difference(current).inDays;
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
