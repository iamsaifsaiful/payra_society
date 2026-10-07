import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/wa_list.dart';

/// কিস্তি বকেয়া: projects behind their monthly installment schedule, with a WhatsApp reminder to the customer.
class ProjectDuesScreen extends StatelessWidget {
  const ProjectDuesScreen({super.key, required this.repo, this.initial});
  final AdminRepo repo;
  final List<ProjectDue>? initial;

  @override
  Widget build(BuildContext context) {
    final prefs = SessionScope.of(context).prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('কিস্তি বকেয়া')),
      body: Loader<List<ProjectDue>>(
        load: () async => initial ?? await repo.projectDues(),
        builder: (context, items, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'যে প্রজেক্টের কিস্তি মাসিক সময়সূচির চেয়ে পিছিয়ে আছে। গ্রাহককে WhatsApp-এ কোন কোন মাস বাকি তা লিখে পাঠানো যায়।',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('সব প্রজেক্টের কিস্তি সময়মতো আছে ✅', style: TextStyle(color: AppColors.muted))),
                ),
              for (final p in items) ...[
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.code} · ${p.customer}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                                Text(p.product, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(taka(p.behind), style: head(17, color: AppColors.danger)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(bn('বকেয়া ${p.missedMonths} মাস: ${p.missedText}'), style: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.4)),
                      Text(
                        bn('পরিশোধ ${taka(p.paid)} / ${taka(p.sell)} · বাকি ${taka(p.remaining)}${p.lastInstallment.isEmpty ? '' : ' · শেষ কিস্তি ${dateBn(p.lastInstallment)}'}'),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (p.mobile.isNotEmpty)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(90, 42)),
                              onPressed: () => launchUrl(Uri(scheme: 'tel', path: p.mobile)),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('কল'),
                            ),
                          const Spacer(),
                          if (p.whatsapp != null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: waGreen, minimumSize: const Size(120, 42)),
                              onPressed: () => showWaPreview(context, p.whatsapp!, () => sendWa(context, prefs, p.whatsapp!)),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('গ্রাহককে মনে করান'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
