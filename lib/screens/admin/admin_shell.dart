import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';

class Defaulter {
  final String memberUid, name, mobile;
  final int monthsDue;
  final double amountDue;
  final bool irregular;
  const Defaulter(this.memberUid, this.name, this.mobile, this.monthsDue, this.amountDue, this.irregular);
  factory Defaulter.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return Defaulter(
      (m['memberUid'] ?? '').toString(),
      (m['name'] ?? '').toString(),
      (m['mobile'] ?? '').toString(),
      toInt(m['monthsDue']),
      toNum(m['amountDue']),
      m['irregular'] == true,
    );
  }
}

class _AdminData {
  final SocietyStats stats;
  final List<Defaulter> defaulters;
  final bool arrearsOn;
  const _AdminData(this.stats, this.defaulters, this.arrearsOn);
}

/// Admin dashboard (first version). Entry, collections and member screens
/// come in the next build.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    Future<_AdminData> load() async {
      final stats = SocietyStats.fromJson(await s.cachedGet('/admin/dashboard'));
      var list = <Defaulter>[];
      var on = false;
      try {
        final d = await s.cachedGet('/admin/defaulters', query: {'min_months': '1'}) as Map;
        list = (d['items'] as List? ?? const []).map(Defaulter.fromJson).toList();
        on = d['configured'] == true;
      } catch (_) {}
      return _AdminData(stats, list, on);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.branding.name),
        actions: [
          IconButton(tooltip: 'লগআউট', onPressed: s.logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: Loader<_AdminData>(
        load: load,
        builder: (context, d, _) {
          final st = d.stats;
          final irregular = d.defaulters.where((x) => x.irregular).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (s.offline) const OfflineBanner(),
              Text(bn('স্বাগতম, ${s.user?.name ?? ''}'), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatTile(icon: Icons.groups_rounded, label: 'সক্রিয় সদস্য', value: bn('${st.activeMembers}/${st.members}')),
                  StatTile(icon: Icons.inventory_2_rounded, label: 'প্রজেক্ট', value: bn(st.projects)),
                  StatTile(icon: Icons.savings_rounded, label: 'মোট সঞ্চয়', value: taka(st.savings)),
                  StatTile(icon: Icons.payments_rounded, label: 'কিস্তি আদায়', value: taka(st.installments)),
                  StatTile(icon: Icons.north_east_rounded, label: 'মোট উত্তোলন', value: taka(st.withdrawals)),
                  StatTile(icon: Icons.volunteer_activism_rounded, label: 'সমিতির তহবিল', value: taka(st.societyFund)),
                ],
              ),
              const SizedBox(height: 8),
              SectionTitle(bn('বকেয়া সদস্য (${d.defaulters.length})')),
              if (!d.arrearsOn)
                const Panel(
                  child: Text(
                    'মাসিক সঞ্চয়ের অঙ্ক এখনো ঠিক করা হয়নি, তাই বকেয়া হিসাব বন্ধ আছে। পরের আপডেটে এখান থেকেই সেট করা যাবে।',
                    style: TextStyle(height: 1.55, color: AppColors.muted),
                  ),
                )
              else if (d.defaulters.isEmpty)
                const Panel(child: Text('কারো বকেয়া নেই।', style: TextStyle(color: AppColors.muted)))
              else
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final x in d.defaulters)
                        ListTile(
                          leading: Avatar(text: initials(x.name), size: 40),
                          title: Text(x.name),
                          subtitle: Text(bn('${x.memberUid} · ${x.monthsDue} মাস · ${taka(x.amountDue)}')),
                          trailing: x.irregular
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(99)),
                                  child: const Text('অনিয়মিত', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              if (irregular.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bn('${irregular.length} জন অনিয়মিত (${s.config?.irregularAfterMonths ?? 3}+ মাস বকেয়া)।'),
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              const Panel(
                color: AppColors.brandSoft,
                child: Text(
                  'অ্যাডমিনের এন্ট্রি (সঞ্চয়, কিস্তি, উত্তোলন), আদায় তালিকা আর সদস্য বিস্তারিত পরের ধাপে আসছে। এখন এন্ট্রি ওয়েব অ্যাডমিন থেকে দিন — রসিদ আর নোটিফিকেশন অ্যাপে সদস্যরা পেয়ে যাবেন।',
                  style: TextStyle(height: 1.6),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
