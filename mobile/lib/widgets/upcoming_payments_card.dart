import 'package:flutter/material.dart';

import '../models/ai_dashboard_model.dart';
import '../theme/app_theme.dart';
import 'scheduled_payment_tile.dart';

class UpcomingPaymentsCard extends StatelessWidget {
  const UpcomingPaymentsCard({
    super.key,
    required this.payments,
    required this.isCreatingPayment,
    required this.onCreate,
  });

  final List<ScheduledPaymentModel> payments;
  final bool isCreatingPayment;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final sortedPayments = List<ScheduledPaymentModel>.from(payments)
      ..sort((left, right) => left.dueDate.compareTo(right.dueDate));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Upcoming debits',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI uses this list to estimate cash gaps and payment postpones.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                child: ElevatedButton(
                  onPressed: isCreatingPayment ? null : onCreate,
                  child: isCreatingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('New'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (sortedPayments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'No scheduled payments yet. Add one so AI includes it in the forecast.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryText,
                  height: 1.45,
                ),
              ),
            )
          else
            Column(
              children: sortedPayments
                  .take(4)
                  .map(
                    (payment) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ScheduledPaymentTile(payment: payment),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
