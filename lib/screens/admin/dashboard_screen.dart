import 'package:flutter/material.dart';

import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'collections_screen.dart';
import 'entry_screen.dart';
import 'members_screen.dart';
import 'projects_admin_screen.dart';
import 'share_transfer_screen.dart';

/// The web dashboard's 8 KPIs, in the same order and with the same rules.
enum Kpi {
  activeMembers('activeMembers', 'সক্রিয় সদস্য', Icons.groups_rounded, Color(0xFF1D5C46), false),
  activeProjects('activeProjects', 'সক্রিয় প্রজেক্ট', Icons.inventory_2_rounded, Color(0xFF2E6FA8), false),
  currentInvestment('currentInvestment', 'বর্তমান বিনিয়োগ', Icons.area_chart_rounded, Color(0xFFB7791F), true),
  installmentsDue('installmentsDue', 'বকেয়া কিস্তি', Icons.event_busy_rounded, Color(0xFFA33A22), true),
  currentBalance('currentBalance', 'বর্তমান ব্যালেন্স', Icons.account_balance_wallet_rounded, Color(0xFF13261D), true),
  availableProfits('availableProfits', 'উপলভ্য মুনাফা', Icons.trending_up_rounded, Color(0xFF1D7A4F), true),
  administrationFunds('administrationFunds', 'প্রশাসন তহবিল', Icons.account_balance_rounded, Color(0xFF6B4BA8), true),
  memberWelfareFunds('memberWelfareFunds', 'সদস্য কল্যাণ তহবিল', Icons.volunteer_activism_rounded, Color(0xFFB0476E), true);

  const Kpi(this.key, this.label, this.icon, this.color, this.money);
  final String key, label;
  final IconData icon;
  final Color color;
  final bool money;

  String get explain => switch (this) {
        Kpi.activeMembers => 'এখন সক্রিয় সদস্যরা। চাপ দিলে সদস্যের পুরো হিসাব।',
        Kpi.activeProjects => 'যেসব প্রজেক্টে এখনো কিস্তি বাকি আছে।',
        Kpi.currentInvestment => 'প্রজেক্টে খাটানো মূলধনের যে অংশ কিস্তির মূলধন হিসেবে এখনো ফেরত আসেনি (কেনা দাম − ফেরত মূলধন)।',
        Kpi.installmentsDue => 'বিক্রয়মূল্য − এ পর্যন্ত আদায় হওয়া কিস্তি।',
        Kpi.currentBalance => 'সঞ্চয় − চলমান বিনিয়োগ − সঞ্চয় থেকে উত্তোলন। লাভ আলাদা দেখানো হয়।',
        Kpi.availableProfits => 'সদস্যদের পাওয়া লাভ থেকে লাভ-উত্তোলন বাদে যা জমা আছে।',
        Kpi.administrationFunds => 'প্রজেক্টের লাভের ৫% + অন্যান্য আয়ের ৮০% − প্রশাসনিক খরচ।',
        Kpi.memberWelfareFunds => 'প্রজেক্টের লাভের ৫% + অন্যান্য আয়ের ২০% − সদস্য কল্যাণ খরচ।',
      };

  String value(Overview o) => money ? taka(o.k(key)) : bn(o.k(key).round());
}

class _DashData {
  final Overview ov;
  final List<Defaulter> defaulters;
  const _DashData(this.ov, this.defaulters);
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.repo, required this.goTab});
  final AdminRepo repo;
  final void Function(int) goTab;

  Future<_DashData> _load() async {
    final ov = await repo.overview();
    var list = <Defaulter>[];
    try {
      (list, _) = await repo.defaulters();
    } catch (_) {}
    return _DashData(ov, list);
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.branding.name)),
      body: Loader<_DashData>(
        load: _load,
        builder: (context, d, _) {
          final o = d.ov;
          final irregular = d.defaulters.where((x) => x.irregular).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (s.offline) const OfflineBanner(),
              Text(bn('${greeting(DateTime.now())}, ${s.user?.name ?? ''}'), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final q in <(IconData, String, VoidCallback)>[
                    (Icons.savings_rounded, 'সঞ্চয় জমা', () => _push(context, EntryScreen(repo: repo, standalone: true))),
                    (Icons.payments_rounded, 'কিস্তি জমা', () => _push(context, EntryScreen(repo: repo, initialKind: EntryKind.installment, standalone: true))),
                    (Icons.swap_horiz_rounded, 'শেয়ার ট্রান্সফার', () => _push(context, ShareTransferScreen(repo: repo))),
                    (Icons.notifications_active_rounded, 'আদায়', () => _push(context, CollectionsScreen(repo: repo))),
                  ])
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: q.$3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(17)),
                                child: Icon(q.$1, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(q.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (d.defaulters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    color: AppColors.dangerSoft,
                    onTap: () => _push(context, CollectionsScreen(repo: repo)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bn('${d.defaulters.length} জনের সঞ্চয় বকেয়া${irregular > 0 ? ', $irregular জন অনিয়মিত' : ''}'),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
                      ],
                    ),
                  ),
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final k in Kpi.values)
                    _KpiTile(kpi: k, value: k.value(o), onTap: () => _push(context, KpiDetailScreen(kpi: k, overview: o, repo: repo))),
                ],
              ),
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  children: [
                    _Line('মোট সদস্য / প্রজেক্ট', bn('${o.t('members').round()} / ${o.t('projects').round()}')),
                    _Line('মোট সঞ্চয় জমা', taka(o.t('savings'))),
                    _Line('মোট কিস্তি আদায়', taka(o.t('installmentsPaid'))),
                    _Line('সঞ্চয় থেকে উত্তোলন', taka(o.t('savingsWithdrawn'))),
                    _Line('লাভ থেকে উত্তোলন', taka(o.t('profitWithdrawn'))),
                    _Line('অন্যান্য আয়', taka(o.t('otherIncome'))),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi, required this.value, required this.onTap});
  final Kpi kpi;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: kpi.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(kpi.icon, size: 19, color: kpi.color),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded, size: 16, color: kpi.color.withValues(alpha: 0.7)),
            ],
          ),
          const Spacer(),
          Text(kpi.label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: head(20, color: kpi.color == const Color(0xFF13261D) ? AppColors.ink : kpi.color)),
          ),
        ],
      ),
    );
  }
}

/// What lies behind one KPI.
class KpiDetailScreen extends StatelessWidget {
  const KpiDetailScreen({super.key, required this.kpi, required this.overview, required this.repo});
  final Kpi kpi;
  final Overview overview;
  final AdminRepo repo;

  void _member(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemberDetailScreen(repo: repo, memberId: id)));
  void _project(BuildContext context, int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectDetailScreen(repo: repo, projectId: id)));

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final children = <Widget>[];
    switch (kpi) {
      case Kpi.activeMembers:
        final ms = o.members.where((m) => m.active).toList()..sort((a, b) => b.total.compareTo(a.total));
        children.addAll(ms.map((m) => _Row(
              title: m.name,
              sub: bn('${m.uid} · সঞ্চয় ${taka(m.savings)} · বিনিয়োগ ${taka(m.investment)}'),
              value: taka(m.total),
              onTap: () => _member(context, m.id),
            )));
      case Kpi.activeProjects:
      case Kpi.installmentsDue:
        final ps = o.projects.where((p) => p.running).toList()..sort((a, b) => b.due.compareTo(a.due));
        children.addAll(ps.map((p) => _Row(
              title: '${p.code} · ${p.customer}',
              sub: bn('বিক্রয় ${taka(p.sell)} · আদায় ${taka(p.paid)} (${p.installments}টি কিস্তি)'),
              value: taka(p.due),
              valueColor: AppColors.danger,
              progress: p.progress,
              onTap: () => _project(context, p.id),
            )));
      case Kpi.currentInvestment:
        final ps = o.projects.where((p) => p.investment > 0.009).toList()..sort((a, b) => b.investment.compareTo(a.investment));
        children.addAll(ps.map((p) => _Row(
              title: '${p.code} · ${p.customer}',
              sub: bn('কেনা ${taka(p.buy)} · মূলধন ফেরত ${taka(p.capitalReturned)}'),
              value: taka(p.investment),
              onTap: () => _project(context, p.id),
            )));
      case Kpi.currentBalance:
        final ms = o.members.where((m) => m.current.abs() > 0.009).toList()..sort((a, b) => b.current.compareTo(a.current));
        children.addAll(ms.map((m) => _Row(
              title: m.name,
              sub: bn('${m.uid} · সঞ্চয় ${taka(m.savings)} − বিনিয়োগ ${taka(m.investment)}'),
              value: taka(m.current),
              onTap: () => _member(context, m.id),
            )));
      case Kpi.availableProfits:
        final ms = o.members.where((m) => m.profits > 0.009).toList()..sort((a, b) => b.profits.compareTo(a.profits));
        children.addAll(ms.map((m) => _Row(title: m.name, sub: m.uid, value: taka(m.profits), valueColor: AppColors.credit, onTap: () => _member(context, m.id))));
      case Kpi.administrationFunds:
      case Kpi.memberWelfareFunds:
        final admin = kpi == Kpi.administrationFunds;
        children.add(const _Head('প্রজেক্টের লাভ থেকে (৫%)'));
        children.addAll(o.fundProjects.map((r) => _Row(
              title: '${r['code']} · ${r['customer']}',
              sub: 'সমিতির ১০% = ${taka(r['total'])}',
              value: taka(r['half'], sign: true),
              valueColor: AppColors.credit,
            )));
        if (o.fundProjects.isEmpty) children.add(const _Empty());
        children.add(_Head(admin ? 'অন্যান্য আয় থেকে (৮০%)' : 'অন্যান্য আয় থেকে (২০%)'));
        children.addAll(o.fundIncome.map((r) => _Row(
              title: (r['details'] ?? '').toString().isEmpty ? 'অন্যান্য আয়' : r['details'].toString(),
              sub: '${dateBn(r['date'])} · মোট ${taka(r['amount'])}',
              value: taka(admin ? r['admin'] : r['welfare'], sign: true),
              valueColor: AppColors.credit,
            )));
        if (o.fundIncome.isEmpty) children.add(const _Empty());
        final ex = admin ? o.adminExpenses : o.welfareExpenses;
        children.add(_Head(admin ? 'প্রশাসনিক খরচ' : 'সদস্য কল্যাণ খরচ'));
        children.addAll(ex.map((r) => _Row(
              title: (r['details'] ?? '').toString().isEmpty ? 'খরচ' : r['details'].toString(),
              sub: '${dateBn(r['date'])} · ${methodBn(r['method'])}',
              value: taka(-toNum(r['amount'])),
              valueColor: AppColors.danger,
            )));
        if (ex.isEmpty) children.add(const _Empty());
    }

    return Scaffold(
      appBar: AppBar(title: Text(kpi.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            color: kpi.color.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kpi.value(o), style: head(30, color: kpi.color == const Color(0xFF13261D) ? AppColors.ink : kpi.color)),
                const SizedBox(height: 6),
                Text(kpi.explain, style: const TextStyle(height: 1.55, fontSize: 13.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (children.isEmpty) const _Empty() else ...children,
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(text, style: head(15, weight: FontWeight.w600)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('কিছু নেই।', style: TextStyle(color: AppColors.muted)),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.sub, required this.value, this.valueColor, this.onTap, this.progress});
  final String title, sub, value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: head(15, color: valueColor ?? AppColors.ink, weight: FontWeight.w600)),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.line, color: AppColors.brand),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
