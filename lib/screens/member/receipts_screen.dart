import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Opens the A4 receipt page in the browser, where it can be printed or
/// saved as PDF with correct Bengali text.
Future<void> openReceipt(BuildContext context, Receipt r) async {
  if (r.publicUrl.isEmpty) {
    toast(context, 'এই রসিদের লিংক পাওয়া যায়নি।');
    return;
  }
  final ok = await launchUrl(Uri.parse(r.publicUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'ব্রাউজার খোলা গেল না।');
}

class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key, required this.repo});
  final MemberRepo repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার রসিদ')),
      body: Loader<List<Receipt>>(
        load: repo.receipts,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: const [
                SizedBox(height: 60),
                Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.muted),
                SizedBox(height: 12),
                Text(
                  'এখনো কোনো রসিদ নেই।\nনতুন সঞ্চয় বা উত্তোলন এন্ট্রি হলে এখানে রসিদ দেখা যাবে।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.6),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ReceiptCard(r: items[i]),
          );
        },
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.r});
  final Receipt r;

  @override
  Widget build(BuildContext context) {
    final out = r.type == 'withdrawal';
    return Panel(
      onTap: () => openReceipt(context, r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      [r.receiptNo, dateBn(r.date.isEmpty ? r.createdAt : r.date), if (r.method.isNotEmpty) methodBn(r.method)].join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Amount(out ? taka(-r.amount) : taka(r.amount, sign: true), positive: !out),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: _BeforeAfter(label: 'আগে', value: taka(r.beforeTotal))),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.muted),
                const SizedBox(width: 12),
                Expanded(child: _BeforeAfter(label: 'এখন', value: taka(r.afterTotal), strong: true)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => openReceipt(context, r),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('দেখুন / প্রিন্ট'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: r.publicUrl));
                  if (context.mounted) toast(context, 'রসিদের লিংক কপি হয়েছে');
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('লিংক কপি'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.label, required this.value, this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(value, style: head(15, color: strong ? AppColors.brand : AppColors.ink, weight: FontWeight.w600)),
        ],
      );
}
