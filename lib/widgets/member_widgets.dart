import 'package:flutter/material.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../services/member_repo.dart';
import '../theme.dart';
import 'common.dart';

/// One ledger line: icon, title, date/method and a signed amount.
class LedgerTile extends StatelessWidget {
  const LedgerTile({super.key, required this.row, this.showBalance = false, this.onTap});
  final StatementRow row;
  final bool showBalance;
  final VoidCallback? onTap;

  IconData get _icon => switch (row.type) {
        'saving' => Icons.savings_rounded,
        'investment' => Icons.inventory_2_rounded,
        'distribution' => Icons.trending_up_rounded,
        'share_sale' => Icons.swap_horiz_rounded,
        'withdrawal' => Icons.north_east_rounded,
        'penalty' => Icons.gavel_rounded,
        _ => Icons.flag_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final positive = row.amount >= 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: positive ? AppColors.brandSoft : AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 20, color: positive ? AppColors.brand : AppColors.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(row.subtitle, maxLines: 2, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (row.isOpening)
                  Text(taka(row.balance), style: head(15, weight: FontWeight.w600))
                else
                  Amount(taka(row.amount, sign: true), positive: positive),
                if (showBalance && !row.isOpening)
                  Text('ব্যালেন্স ${taka(row.balance)}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.stake, this.onTap});
  final ProjectStake stake;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (stake.progress * 100).round();
    return Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('PEC', style: head(12, color: AppColors.brand, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [stake.projectCode, if (stake.productType.isNotEmpty) stake.productType].join(' · '),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text('আমার শেয়ার ${taka(stake.invested)}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Amount(taka(stake.profit, sign: true), positive: true),
                  const Text('লাভ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stake.progress,
              minHeight: 8,
              backgroundColor: AppColors.line,
              color: stake.active ? AppColors.brand : AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  stake.sold
                      ? 'শেয়ার বিক্রি হয়েছে · ফেরত ${taka(stake.capitalReturned + stake.shareSold)}'
                      : stake.active
                          ? 'বাকি মূলধন ${taka(stake.remaining)}'
                          : 'পুরো মূলধন ফেরত এসেছে',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              Text(bn('$pct%'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two-line stat used in grids.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.icon});
  final String label, value;
  final String? sub;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: AppColors.brand), const SizedBox(width: 6)],
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: head(20))),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
