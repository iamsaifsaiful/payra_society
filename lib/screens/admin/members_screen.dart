import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';
import '../member/home_screen.dart' show ArrearsCard;
import '../../services/admin_more.dart';
import '../../widgets/shell_nav.dart';
import '../../widgets/statement_export.dart';
import '../../widgets/wa_list.dart';
import '../../services/whatsapp.dart';
import 'entries_screen.dart';
import 'entry_screen.dart';
import 'member_form_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.repo});
  final AdminRepo repo;
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _q = TextEditingController();
  final _loader = GlobalKey<LoaderState<List<AdminMember>>>();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: shellBack(context), title: const Text('সদস্য')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MemberFormScreen(repo: widget.repo)));
          if (ok == true) _loader.currentState?.reload();
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('নতুন সদস্য'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(hintText: 'নাম, আইডি বা মোবাইল দিয়ে খুঁজুন', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _loader.currentState?.reload());
              },
            ),
          ),
          Expanded(
            child: Loader<List<AdminMember>>(
              key: _loader,
              load: () => widget.repo.members(search: _q.text.trim(), perPage: 50),
              builder: (context, items, _) => items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      Text('কাউকে পাওয়া যায়নি।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = items[i];
                        return Panel(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => MemberDetailScreen(repo: widget.repo, memberId: m.id)),
                            );
                            _loader.currentState?.reload();
                          },
                          child: Row(
                            children: [
                              Avatar(text: initials(m.name), size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                                    Text(bn('${m.uid} · ${m.mobile}'), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              if (!m.active) _Chip(m.statusBn, AppColors.muted),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _Detail {
  final AdminMember member;
  final Balances balances;
  final Arrears arrears;
  final List<StatementRow> rows;
  final MemberForm form;
  const _Detail(this.member, this.balances, this.arrears, this.rows, this.form);

  Iterable<StatementRow> get _savings => rows.where((r) => r.type == 'saving');
  double get totalSaved => _savings.fold(0, (a, r) => a + r.credit);
  int get savingCount => _savings.length;
  double get savingWithdrawn => rows.where((r) => r.type == 'withdrawal' && r.withdrawType != 'profits').fold(0, (a, r) => a + r.debit);
}

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.repo, required this.memberId});
  final AdminRepo repo;
  final int memberId;
  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  AdminRepo get repo => widget.repo;
  int get memberId => widget.memberId;
  final loader = GlobalKey<LoaderState<_Detail>>();

  Future<_Detail> _load() async {
    final r = await Future.wait([
      repo.member(memberId),
      repo.balance(memberId),
      repo.arrears(memberId),
      repo.statement(memberId),
      repo.memberForm(memberId),
    ]);
    return _Detail(r[0] as AdminMember, r[1] as Balances, r[2] as Arrears, r[3] as List<StatementRow>, r[4] as MemberForm);
  }

  Future<void> _reset(BuildContext context, AdminMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পাসওয়ার্ড রিসেট'),
        content: Text(
          '${m.name}-এর জন্য নতুন ৮ অঙ্কের পাসওয়ার্ড তৈরি হবে। পুরনো সব ফোন থেকে লগআউট হয়ে যাবে। নতুন পাসওয়ার্ড WhatsApp-এ পাঠাতে পারবেন।',
          style: const TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('রিসেট'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final (pw, link) = await repo.resetPassword(m.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('নতুন পাসওয়ার্ড'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(pw ?? '', style: head(30, color: AppColors.brand)),
              const SizedBox(height: 8),
              const Text('সদস্যকে পাঠিয়ে দিন। লগইনের পর তিনি নিজে বদলে নেবেন।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: pw ?? '')),
              child: const Text('কপি'),
            ),
            if (link.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44), backgroundColor: const Color(0xFF1FA855)),
                onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  Future<void> _whatsapp(BuildContext context, AdminMember m) async {
    final prefs = SessionScope.read(context).prefs;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_rounded, color: waGreen),
              title: const Text('হিসাবের সারসংক্ষেপ পাঠান'),
              subtitle: const Text('সঞ্চয়, বিনিয়োগ, লভ্যাংশ, মোট ব্যালেন্স, বকেয়া মাস'),
              onTap: () => Navigator.pop(c, 'summary'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded, color: waGreen),
              title: const Text('বকেয়ার রিমাইন্ডার পাঠান'),
              subtitle: const Text('কোন কোন মাস বাকি তা লেখা থাকবে'),
              onTap: () => Navigator.pop(c, 'arrears'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: waGreen),
              title: const Text('শুধু চ্যাট খুলুন'),
              onTap: () => Navigator.pop(c, 'chat'),
            ),
          ],
        ),
      ),
    );
    if (pick == null || !context.mounted) return;
    if (pick == 'chat') {
      await WhatsApp.send(prefs, phone: m.mobile, text: '');
      return;
    }
    try {
      final w = await repo.memberWhatsapp(m.id, arrears: pick == 'arrears');
      if (context.mounted) await showWaPreview(context, w, () => sendWa(context, prefs, w));
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = SessionScope.of(context).config;
    return Scaffold(
      appBar: AppBar(
        title: const Text('সদস্যের হিসাব'),
        actions: [
          IconButton(
            tooltip: 'স্টেটমেন্ট PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () async {
              final m = await repo.member(memberId);
              if (!context.mounted) return;
              showMemberStatementSheet(
                context,
                session: SessionScope.read(context),
                title: '${m.name}-এর হিসাব বিবরণী',
                build: (from, to) => StatementRequest.member(memberId, m.uid, from, to),
              );
            },
          ),
          IconButton(
            tooltip: 'তথ্য বদলান',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => MemberFormScreen(repo: repo, memberId: memberId)),
              );
              if (ok == true) loader.currentState?.reload();
            },
          ),
        ],
      ),
      body: Loader<_Detail>(
        key: loader,
        load: _load,
        builder: (context, d, reload) {
          final m = d.member;
          final rows = d.rows.where((r) => !r.isOpening).toList().reversed.toList();
          Future<void> entry(EntryKind k) async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => EntryScreen(repo: repo, initialKind: k, member: m, standalone: true)),
            );
            if (changed == true) reload();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Avatar(text: initials(m.name), size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: head(19)),
                              Text(bn('${m.uid} · যোগদান ${dateBn(m.joinDate)}'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              const SizedBox(height: 4),
                              _Chip(m.statusBn, m.active ? AppColors.brand : AppColors.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                            onPressed: m.mobile.isEmpty ? null : () => launchUrl(Uri(scheme: 'tel', path: m.mobile)),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('কল'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: waGreen),
                            onPressed: m.mobile.isEmpty ? null : () => _whatsapp(context, m),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Panel(
                color: AppColors.brandSoft,
                child: Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: AppColors.brand, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('মোট সঞ্চয় জমা', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text(taka(d.totalSaved), style: head(26, color: AppColors.brand)),
                          Text(
                            bn('${d.savingCount}টি জমা${d.savingWithdrawn > 0 ? ' · সঞ্চয় থেকে উত্তোলন ${taka(d.savingWithdrawn)}' : ''}'),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => EntriesScreen(repo: repo, uid: m.uid)),
                      ),
                      child: const Text('তালিকা'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'মোট ব্যালেন্স', value: taka(d.balances.total))),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'বর্তমান', value: taka(d.balances.current))),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'লাভ', value: taka(d.balances.profits))),
                ],
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: AppColors.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.form.monthlySaving != null
                            ? 'মাসিক সঞ্চয় ${taka(d.form.monthlySaving)} (এই সদস্যের নিজস্ব)'
                            : (d.form.effectiveMonthly > 0 ? 'মাসিক সঞ্চয় ${taka(d.form.effectiveMonthly)} (সমিতির সাধারণ অঙ্ক)' : 'মাসিক সঞ্চয় ঠিক করা নেই'),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ArrearsCard(arrears: d.arrears, dueDay: cfg?.dueDay ?? 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: m.active ? () => entry(EntryKind.saving) : null,
                      icon: const Icon(Icons.savings_rounded),
                      label: const Text('সঞ্চয় জমা'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => entry(EntryKind.withdrawal),
                      icon: const Icon(Icons.north_east_rounded),
                      label: const Text('উত্তোলন'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _reset(context, m),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('পাসওয়ার্ড রিসেট করে পাঠান'),
              ),
              SectionTitle(bn('লেনদেন (${rows.length})')),
              Panel(
                padding: EdgeInsets.zero,
                child: rows.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text('কোনো লেনদেন নেই।', style: TextStyle(color: AppColors.muted)))
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length && i < 30; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 66, color: AppColors.line),
                            LedgerTile(
                              row: rows[i],
                              showBalance: true,
                              onTap: (rows[i].type == 'saving' || rows[i].type == 'withdrawal') && rows[i].ref > 0
                                  ? () async {
                                      final r = rows[i];
                                      final e = Entry(
                                        id: r.ref,
                                        type: r.type == 'saving' ? EntryType.saving : EntryType.withdrawal,
                                        date: r.date,
                                        method: r.method,
                                        note: r.note,
                                        uid: m.uid,
                                        name: m.name,
                                        withdrawType: r.withdrawType,
                                        amount: r.type == 'saving' ? r.credit : r.debit,
                                      );
                                      final changed = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(builder: (_) => EntryEditScreen(repo: repo, entry: e)),
                                      );
                                      if (changed == true) reload();
                                    }
                                  : null,
                            ),
                          ],
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
