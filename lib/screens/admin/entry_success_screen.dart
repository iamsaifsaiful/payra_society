import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logic/format.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../member/receipts_screen.dart';
import 'entry_screen.dart';

/// After an entry: what was saved, before → after, and the WhatsApp receipt.
class EntrySuccessScreen extends StatelessWidget {
  const EntrySuccessScreen({super.key, required this.kind, required this.result, required this.amount});
  final EntryKind kind;
  final EntryResult result;
  final double amount;

  String get _title => switch (kind) {
        EntryKind.saving => 'সঞ্চয় জমা হয়েছে',
        EntryKind.installment => 'কিস্তি জমা হয়েছে',
        EntryKind.withdrawal => 'উত্তোলন সম্পন্ন',
      };

  @override
  Widget build(BuildContext context) {
    final r = result.receipt;
    final d = result.details;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.brandSoft,
              child: Icon(Icons.check_rounded, size: 44, color: AppColors.brand),
            ),
          ),
          const SizedBox(height: 14),
          Text(_title, textAlign: TextAlign.center, style: head(22)),
          const SizedBox(height: 4),
          Text(
            [result.memberName, if (r != null) r.receiptNo].where((x) => x.isNotEmpty).join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(taka(amount), textAlign: TextAlign.center, style: head(36, color: AppColors.brand)),
          const SizedBox(height: 18),
          if (kind == EntryKind.installment)
            Panel(
              child: Column(
                children: [
                  _Row('আগে পরিশোধিত', taka(d['paidBefore'])),
                  _Row('এখন মোট পরিশোধিত', taka(d['paidAfter']), strong: true),
                  _Row('বাকি রইল', taka(d['dueAfter'])),
                  if (result.distribution.isNotEmpty)
                    _Row('ভাগ পেলেন', bn('${result.distribution.where((x) => x['member_uid'] != '__SOCIETY__').length} জন বিনিয়োগকারী + সমিতি')),
                ],
              ),
            )
          else if (r != null)
            Panel(
              child: Row(
                children: [
                  Expanded(child: _Col('আগের ব্যালেন্স', taka(r.beforeTotal))),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(child: _Col('এখনকার ব্যালেন্স', taka(r.afterTotal), strong: true)),
                ],
              ),
            ),
          const SizedBox(height: 18),
          if (result.whatsappLink.isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855)),
              onPressed: () => launchUrl(Uri.parse(result.whatsappLink), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('WhatsApp-এ রসিদ পাঠান'),
            ),
            const SizedBox(height: 6),
            const Text(
              'WhatsApp খুলবে, বার্তা লেখা থাকবে — শুধু Send চাপুন।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          if (r != null)
            OutlinedButton.icon(
              onPressed: () => openReceipt(context, r),
              icon: const Icon(Icons.print_rounded),
              label: const Text('রসিদ দেখুন / প্রিন্ট'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ঠিক আছে'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('আরেকটি এন্ট্রি'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
            Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w600, color: strong ? AppColors.brand : AppColors.ink)),
          ],
        ),
      );
}

class _Col extends StatelessWidget {
  const _Col(this.label, this.value, {this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: head(19, color: strong ? AppColors.brand : AppColors.ink)),
          ),
        ],
      );
}
