import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../theme/app_theme.dart';
import '../theme/som_formatter.dart';

class BankCardPreview extends StatelessWidget {
  const BankCardPreview({
    super.key,
    required this.account,
    required this.cardLabel,
  });

  final AccountModel account;
  final String cardLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFF18B869), Color(0xFF00773D)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'с',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                cardLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: Color(0xFFF0E928)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            SomFormatter.amount(account.balance),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            width: 76,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFD7B165), Color(0xFF8E6C31)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Mbank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '4477   VISA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
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
