import 'package:flutter/material.dart';
import 'package:m_bank_dashboard/m_bank_dashboard.dart';

import '../models/notification_model.dart';
import '../services/bank_api_service.dart';
import '../services/mock_notifications.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiService,
    this.transactions = const <TransactionModel>[],
    this.notifications,
    this.onSmartListChanged,
  });

  final BankApiService apiService;
  final List<TransactionModel> transactions;
  final List<NotificationModel>? notifications;
  final VoidCallback? onSmartListChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationModel> _notifications;
  final Set<int> _selectedTransactionIds = <int>{};
  bool _isSaving = false;

  bool get _isSelectionMode => _selectedTransactionIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _notifications = _buildNotifications(
      widget.notifications,
      widget.transactions,
    );
  }

  Future<void> _reloadNotifications() async {
    final transactions = await widget.apiService.fetchTransactions();
    if (!mounted) {
      return;
    }
    setState(() {
      _notifications = _buildNotifications(null, transactions);
      _selectedTransactionIds.clear();
    });
  }

  Future<void> _handleTap(NotificationModel notification) async {
    if (!notification.canAddToSmartList || notification.transactionId == null) {
      return;
    }
    if (_isSelectionMode) {
      _toggleSelection(notification);
      return;
    }
    await _assignTransactions(
      transactionIds: <int>[notification.transactionId!],
      title: 'Привязать расход к категории',
    );
  }

  void _handleLongPress(NotificationModel notification) {
    if (!notification.canAddToSmartList || notification.transactionId == null) {
      return;
    }
    setState(() {
      _selectedTransactionIds.add(notification.transactionId!);
    });
  }

  void _toggleSelection(NotificationModel notification) {
    final transactionId = notification.transactionId;
    if (transactionId == null || !notification.canAddToSmartList) {
      return;
    }
    setState(() {
      if (_selectedTransactionIds.contains(transactionId)) {
        _selectedTransactionIds.remove(transactionId);
      } else {
        _selectedTransactionIds.add(transactionId);
      }
    });
  }

  Future<void> _assignSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) {
      return;
    }
    await _assignTransactions(
      transactionIds: _selectedTransactionIds.toList(growable: false),
      title: 'Выберите Smart List категорию',
    );
  }

  Future<void> _assignTransactions({
    required List<int> transactionIds,
    required String title,
  }) async {
    if (_isSaving) {
      return;
    }

    final categories = await widget.apiService.fetchSmartCategories();
    if (!mounted) {
      return;
    }
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала создайте хотя бы одну Smart List категорию.'),
        ),
      );
      return;
    }

    final category = await _pickCategory(categories, title);
    if (!mounted || category == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.apiService.bulkCategorizeTransactions(
        transactionIds: transactionIds,
        categoryId: category.id,
      );
      widget.onSmartListChanged?.call();
      if (!mounted) {
        return;
      }
      await _reloadNotifications();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transactionIds.length == 1
                ? 'Расход привязан к категории "${category.name}".'
                : 'Выбрано ${transactionIds.length} расходов, категория: "${category.name}".',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<SmartCategory?> _pickCategory(
    List<SmartCategory> categories,
    String title,
  ) {
    return showModalBottomSheet<SmartCategory>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
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
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите существующую Smart List категорию.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final remainingColor = category.remaining < 0
                          ? AppTheme.coral
                          : AppTheme.secondaryText;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(category),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: AppTheme.surfaceSoft,
                        title: Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Лимит: ${SomFormatter.amount(category.plannedMonthly)}',
                        ),
                        trailing: Text(
                          _remainingLabel(category.remaining),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: remainingColor,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_NotificationGroup> _buildGroups() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationModel>[];
    final yesterdayItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final notification in _notifications) {
      final day = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );
      if (day == today) {
        todayItems.add(notification);
      } else if (day == yesterday) {
        yesterdayItems.add(notification);
      } else {
        earlierItems.add(notification);
      }
    }

    return <_NotificationGroup>[
      if (todayItems.isNotEmpty)
        _NotificationGroup(label: 'Сегодня', items: todayItems),
      if (yesterdayItems.isNotEmpty)
        _NotificationGroup(label: 'Вчера', items: yesterdayItems),
      if (earlierItems.isNotEmpty)
        _NotificationGroup(label: 'Ранее', items: earlierItems),
    ];
  }

  List<NotificationModel> _buildNotifications(
    List<NotificationModel>? explicitNotifications,
    List<TransactionModel> transactions,
  ) {
    final notifications = List<NotificationModel>.from(
      explicitNotifications ?? getMockNotifications(transactions: transactions),
    );
    notifications.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    return notifications;
  }

  String _remainingLabel(double remaining) {
    final absolute = SomFormatter.amount(remaining.abs());
    return remaining < 0 ? '-$absolute' : absolute;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'Выбрано: ${_selectedTransactionIds.length}' : 'Уведомления'),
        actions: <Widget>[
          if (_isSelectionMode)
            IconButton(
              onPressed: _isSaving ? null : _assignSelectedTransactions,
              icon: const Icon(Icons.label_important_outline_rounded),
              tooltip: 'Привязать к категории',
            ),
          if (_isSelectionMode)
            IconButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                      _selectedTransactionIds.clear();
                    }),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Отменить выбор',
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 22),
        itemBuilder: (context, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ),
              ...group.items.map((notification) {
                final transactionId = notification.transactionId;
                final selected =
                    transactionId != null &&
                    _selectedTransactionIds.contains(transactionId);
                final canAttach =
                    notification.canAddToSmartList && !_isSaving;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NotificationTile(
                    notification: notification,
                    selected: selected,
                    selectionMode: _isSelectionMode,
                    onTap: canAttach ? () => _handleTap(notification) : null,
                    onLongPress: canAttach
                        ? () => _handleLongPress(notification)
                        : null,
                    onAddToSmartList:
                        canAttach && !_isSelectionMode
                        ? () => _handleTap(notification)
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<NotificationModel> items;
}
