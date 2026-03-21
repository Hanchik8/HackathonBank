import 'package:flutter/material.dart';

import '../models/scheduled_payment_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class DuePaymentBanner extends StatelessWidget {
  const DuePaymentBanner({
    super.key,
    required this.payments,
    required this.onOpenAnalysis,
    required this.onDismiss,
  });

  final List<ScheduledPaymentModel> payments;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final paymentCount = payments.length;
    final firstPayment = payments.first;
    final totalAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final title = paymentCount == 1
        ? '\u0421\u0435\u0433\u043e\u0434\u043d\u044f \u043d\u0443\u0436\u043d\u043e '
            '\u0432\u044b\u043f\u043e\u043b\u043d\u0438\u0442\u044c \u043f\u043b\u0430\u0442\u0435\u0436'
        : '\u0421\u0435\u0433\u043e\u0434\u043d\u044f \u043d\u0443\u0436\u043d\u043e '
            '\u0432\u044b\u043f\u043e\u043b\u043d\u0438\u0442\u044c $paymentCount '
            '\u043f\u043b\u0430\u0442\u0435\u0436\u0430';
    final description = paymentCount == 1
        ? '\u041f\u043b\u0430\u0442\u0435\u0436 "${firstPayment.title}" '
            '\u043d\u0430 ${SomFormatter.amount(firstPayment.amount)} '
            '\u0433\u043e\u0442\u043e\u0432 \u043a \u0438\u0441\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044e.'
        : '\u041a \u0438\u0441\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044e '
            '\u0433\u043e\u0442\u043e\u0432\u044b $paymentCount '
            '\u043f\u043b\u0430\u0442\u0435\u0436\u0430 \u043d\u0430 ${SomFormatter.amount(totalAmount)}.';

    return Container(
      key: const ValueKey<String>('due-payment-banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.secondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    ElevatedButton(
                      key: const ValueKey<String>(
                        'due-payment-banner-open-analysis',
                      ),
                      onPressed: onOpenAnalysis,
                      child: const Text('\u041a \u0430\u043d\u0430\u043b\u0438\u0437\u0443'),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'due-payment-banner-dismiss',
                      ),
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        minimumSize: const Size(108, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('\u0421\u043a\u0440\u044b\u0442\u044c'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
