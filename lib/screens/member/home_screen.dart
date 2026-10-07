import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';
import 'notifications_screen.dart';
import 'receipts_screen.dart';
import 'society_screen.dart';

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key, required this.repo, required this.goTab});
  final MemberRepo repo;
  final void Function(int tab) goTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Loader<MemberHome>(
        load: repo.home,
        builder: (context, h, reload) => _HomeBody(home: h, repo: repo, goTab: goTab, reload: reload),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.home, required this.repo, required this.goTab, required this.reload});
  final MemberHome home;
  final MemberRepo repo;
  final void Function(int tab) goTab;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final b = home.summary.balances;
    final active = home.projects.where((p) => p.active).toList();
    final total = taka(b.total, paisa: true);
    final dot = total.lastIndexOf('.');
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (s.offline) const OfflineBanner(),
        // Green header with the total balance.
        Container(
          color: AppColors.brand,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(text: initials(home.member.name), url: home.member.photoUrl, dark: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting(DateTime.now()), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                        Text(home.member.name, style: head(19, color: Colors.white, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _Bell(
                    unread: home.unread,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NotificationsScreen(repo: repo)));
                      reload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('মোট ব্যালেন্স', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                    child: Text(home.member.memberId, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: dot > 0 ? total.substring(0, dot) : total, style: head(38, color: Colors.white)),
                  if (dot > 0) TextSpan(text: total.substring(dot), style: head(20, color: Colors.white.withValues(alpha: 0.7))),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: _HeaderStat(label: 'বর্তমান ব্যালেন্স', value: taka(b.current))),
                    Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(width: 14),
                    Expanded(child: _HeaderStat(label: 'উত্তোলনযোগ্য লাভ', value: taka(b.profits))),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Quick(icon: Icons.receipt_long_rounded, label: 'রসিদ', onTap: () => _push(context, ReceiptsScreen(repo: repo))),
                  _Quick(icon: Icons.groups_rounded, label: 'সমিতি', onTap: () => _push(context, SocietyScreen(repo: repo))),
                  _Quick(icon: Icons.savings_rounded, label: 'সঞ্চয়', onTap: () => goTab(1)),
                  _Quick(
                    icon: Icons.call_rounded,
                    label: 'কোষাধ্যক্ষ',
                    onTap: () {
                      final phone = s.config?.treasurerPhone ?? '';
                      if (phone.isEmpty) {
                        toast(context, 'কোষাধ্যক্ষের নম্বর এখনো দেওয়া হয়নি।');
                      } else {
                        launchUrl(Uri(scheme: 'tel', path: phone));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ArrearsCard(arrears: home.arrears, dueDay: s.config?.dueDay ?? 10, onTap: () => goTab(1)),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.savings_rounded,
                      label: 'মোট সঞ্চয়',
                      value: taka(home.summary.savings),
                      sub: home.arrears.configured && home.arrears.regularStreak > 0
                          ? bn('${home.arrears.regularStreak} মাস নিয়মিত')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.inventory_2_rounded,
                      label: 'চলমান বিনিয়োগ',
                      value: taka(home.summary.investment),
                      sub: bn('${active.length}টি প্রজেক্টে'),
                    ),
                  ),
                ],
              ),
              if (home.projects.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionTitle('আমার প্রজেক্ট', action: 'সব দেখুন', onAction: () => goTab(2)),
                for (final p in (active.isEmpty ? home.projects : active).take(2)) ...[
                  ProjectCard(stake: p, onTap: () => goTab(2)),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 6),
              SectionTitle('সাম্প্রতিক লেনদেন', action: 'সব দেখুন', onAction: () => goTab(3)),
              Panel(
                padding: EdgeInsets.zero,
                child: home.recent.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('এখনো কোনো লেনদেন নেই।', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < home.recent.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 66, color: AppColors.line),
                            LedgerTile(row: home.recent[i]),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: head(18, color: Colors.white, weight: FontWeight.w600)),
          ),
        ],
      );
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.gold,
            textColor: AppColors.ink,
            label: Text(bn(unread > 9 ? '9+' : '$unread')),
            offset: const Offset(-6, 6),
            child: const Center(child: Icon(Icons.notifications_rounded, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(icon, color: AppColors.brand),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overdue warning, or a gentle "this month's saving is due by the 10th".
class ArrearsCard extends StatelessWidget {
  const ArrearsCard({super.key, required this.arrears, required this.dueDay, this.onTap});
  final Arrears arrears;
  final int dueDay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!arrears.configured) return const SizedBox.shrink();
    final now = DateTime.now();
    final thisMonth = arrears.months.isEmpty ? null : arrears.months.last;
    final String title;
    final String body;
    final bool bad;
    if (arrears.monthsDue > 0) {
      bad = true;
      title = arrears.irregular
          ? bn('অনিয়মিত সদস্য · ${arrears.monthsDue} মাস বকেয়া')
          : bn('${arrears.monthsDue} মাসের সঞ্চয় বকেয়া');
      body = arrears.irregular
          ? 'বকেয়া ${taka(arrears.amountDue)}। শোধ না হওয়া পর্যন্ত নতুন প্রজেক্ট ও শেয়ার কেনা বন্ধ থাকবে; চলমান লাভ আগের মতোই আসবে।'
          : 'বকেয়া ${taka(arrears.amountDue)}। দ্রুত জমা দিন।';
    } else if (thisMonth != null && !thisMonth.paid) {
      bad = false;
      title = bn('${monthsFull[now.month - 1]} মাসের সঞ্চয় ${taka(arrears.monthlyAmount)}');
      body = bn('শেষ তারিখ $dueDay ${monthsFull[now.month - 1]}। জমা দিলে অ্যাডমিন এন্ট্রি দেবেন, রসিদ পাবেন।');
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        onTap: onTap,
        color: bad ? AppColors.dangerSoft : AppColors.brandSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(bad ? Icons.warning_amber_rounded : Icons.event_available_rounded, color: bad ? AppColors.danger : AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: bad ? AppColors.danger : AppColors.brandDark)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 13.5, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
