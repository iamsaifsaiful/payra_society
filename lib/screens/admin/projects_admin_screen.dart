import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_nav.dart';
import 'entry_screen.dart';
import 'members_screen.dart';
import 'pickers.dart';

/// প্রজেক্ট tab: running and finished projects, and "নতুন প্রজেক্ট".
class ProjectsAdminScreen extends StatefulWidget {
  const ProjectsAdminScreen({super.key, required this.repo});
  final AdminRepo repo;
  @override
  State<ProjectsAdminScreen> createState() => _ProjectsAdminScreenState();
}

class _ProjectsAdminScreenState extends State<ProjectsAdminScreen> {
  int _filter = 0; // 0 running, 1 finished, 2 all
  final _loader = GlobalKey<LoaderState<Overview>>();

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: shellBack(context), title: const Text('প্রজেক্ট')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => _open(NewProjectScreen(repo: widget.repo)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('নতুন প্রজেক্ট'),
      ),
      body: Loader<Overview>(
        key: _loader,
        load: widget.repo.overview,
        builder: (context, o, _) {
          final list = o.projects.where((p) => _filter == 2 || (_filter == 0 ? p.running : !p.running)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(child: _Stat('চলমান', bn(o.projects.where((p) => p.running).length))),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('বর্তমান বিনিয়োগ', taka(o.k('currentInvestment')))),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('বকেয়া কিস্তি', taka(o.k('installmentsDue')))),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in const [(0, 'চলমান'), (1, 'শেষ'), (2, 'সব')])
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(color: _filter == f.$1 ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('এই তালিকায় কোনো প্রজেক্ট নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                ),
              for (final p in list) ...[
                Panel(
                  onTap: () => _open(ProjectDetailScreen(repo: widget.repo, projectId: p.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text([p.code, if (p.product.isNotEmpty) p.product].join(' · '), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                                Text(p.customer, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(p.running ? taka(p.due) : 'শেষ', style: head(16, color: p.running ? AppColors.danger : AppColors.brand)),
                              Text(p.running ? 'বাকি' : bn('${p.installments}টি কিস্তি'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: p.progress, minHeight: 7, backgroundColor: AppColors.line, color: AppColors.brand),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bn('কেনা ${taka(p.buy)} · বিক্রয় ${taka(p.sell)} · আদায় ${taka(p.paid)}'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: head(16))),
          ],
        ),
      );
}

/// One project: figures, investors, installments.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.repo, required this.projectId});
  final AdminRepo repo;
  final int projectId;
  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _loader = GlobalKey<LoaderState<ProjectDetail>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('প্রজেক্টের বিস্তারিত')),
      body: Loader<ProjectDetail>(
        key: _loader,
        load: () => widget.repo.projectDetail(widget.projectId),
        builder: (context, d, reload) {
          final p = d.project;
          final r = d.raw;
          String s(String k) => (r[k] ?? '').toString();
          final profit = p.sell - p.buy;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text([p.code, if (p.product.isNotEmpty) p.product].join(' · '), style: head(19)),
                    const SizedBox(height: 4),
                    Text(bn('${p.customer} ${p.customerMobile}'), style: const TextStyle(color: AppColors.muted)),
                    if (s('customer_address').isNotEmpty) Text(s('customer_address'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    if (s('guarantor_name').isNotEmpty)
                      Text(bn('জামিনদার: ${s('guarantor_name')} ${s('guarantor_mobile')}'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.sell <= 0 ? 0 : (d.paid / p.sell).clamp(0, 1).toDouble(),
                        minHeight: 9,
                        backgroundColor: AppColors.line,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Kv('কেনা দাম', taka(p.buy)),
                    _Kv('বিক্রয়মূল্য', taka(p.sell)),
                    _Kv('মোট লাভ (৯০% সদস্য, ১০% সমিতি)', taka(profit)),
                    _Kv('আদায় হয়েছে', bn('${taka(d.paid)} (${d.installments.length}টি কিস্তি)')),
                    _Kv('বাকি', taka(d.due), strong: true),
                    _Kv('সমিতির তহবিলে গেছে', taka(d.societyFund)),
                    if (p.firstInstallment > 0) _Kv('প্রথম কিস্তি', taka(p.firstInstallment)),
                    if (p.perInstallment > 0) _Kv('পরের প্রতি কিস্তি', taka(p.perInstallment)),
                    if (s('buy_date').isNotEmpty) _Kv('কেনার তারিখ', dateBn(s('buy_date'))),
                    if (s('installment_start').isNotEmpty) _Kv('কিস্তি শুরু', dateBn(s('installment_start'))),
                    if (s('note').isNotEmpty) _Kv('নোট', s('note')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (d.due > 0)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
                            builder: (_) => EntryScreen(repo: widget.repo, initialKind: EntryKind.installment, project: p, standalone: true),
                          ));
                          if (ok == true) reload();
                        },
                        icon: const Icon(Icons.payments_rounded),
                        label: const Text('কিস্তি জমা'),
                      ),
                    ),
                  if (d.due > 0 && p.customerMobile.isNotEmpty) const SizedBox(width: 10),
                  if (p.customerMobile.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: p.customerMobile)),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('গ্রাহককে কল'),
                      ),
                    ),
                ],
              ),
              SectionTitle(bn('বিনিয়োগকারী (${d.investors.length})')),
              for (final iv in d.investors) ...[
                Panel(
                  onTap: () async {
                    final id = (await widget.repo.members(search: iv.uid)).where((m) => m.uid == iv.uid).map((m) => m.id).firstOrNull;
                    if (id != null && context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemberDetailScreen(repo: widget.repo, memberId: id)));
                    }
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${iv.name.isEmpty ? iv.uid : iv.name} · ${iv.uid}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          if (!iv.active)
                            const Text('শেয়ার বিক্রি', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bn('বিনিয়োগ ${taka(iv.invested)} · মূলধন ফেরত ${taka(iv.capitalReturned)}'
                            '${iv.shareSold > 0 ? ' · শেয়ার বিক্রি ${taka(iv.shareSold)}' : ''}'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                      Text(
                        bn('লাভ ${taka(iv.profit)}${iv.active ? ' · বাকি মূলধন ${taka(iv.remaining)}' : ''}'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.credit, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SectionTitle(bn('কিস্তি (${d.installments.length})')),
              Panel(
                padding: EdgeInsets.zero,
                child: d.installments.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('এখনো কোনো কিস্তি নেই।', style: TextStyle(color: AppColors.muted)))
                    : Column(
                        children: [
                          for (var i = 0; i < d.installments.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppColors.line),
                            ListTile(
                              dense: true,
                              title: Text(dateBn(d.installments[i]['installment_date'])),
                              subtitle: Text(methodBn(d.installments[i]['method'])),
                              trailing: Text(taka(d.installments[i]['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v, {this.strong = false});
  final String k, v;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13.5))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w600, color: strong ? AppColors.danger : AppColors.ink)),
            ),
          ],
        ),
      );
}

/// New project: customer, product, prices, schedule, and who invests
/// ("lowest balance first, equal cut" — the plugin's own rule, previewed live).
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key, required this.repo});
  final AdminRepo repo;
  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _Candidate {
  final OvMember m;
  final bool irregular;
  bool selected;
  _Candidate(this.m, this.irregular, this.selected);
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _c = <String, TextEditingController>{
    for (final k in [
      'customer_name', 'customer_mobile', 'customer_nid', 'customer_address', 'guarantor_name', 'guarantor_mobile',
      'guarantor_nid', 'product_type', 'buy_amount', 'sell_amount', 'first_installment_amount',
      'remaining_per_installment_amount', 'count', 'note',
    ])
      k: TextEditingController(),
  };
  DateTime _buyDate = DateTime.now();
  DateTime? _start;
  List<_Candidate>? _candidates;
  AllocationPreview? _preview;
  bool _previewBusy = false;
  Timer? _debounce;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    for (final k in ['buy_amount', 'sell_amount', 'first_installment_amount', 'count']) {
      _c[k]!.addListener(_onNumbers);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(String k) => parseAmount(_c[k]!.text);

  Future<void> _loadCandidates() async {
    try {
      final ov = await widget.repo.overview();
      var irregular = <String>{};
      try {
        final (list, _) = await widget.repo.defaulters();
        irregular = list.where((x) => x.irregular).map((x) => x.memberUid).toSet();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _candidates = ov.members
            .where((m) => m.active)
            .map((m) => _Candidate(m, irregular.contains(m.uid), m.current > 0))
            .toList()
          ..sort((a, b) => a.m.current.compareTo(b.m.current));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onNumbers() {
    // Per-installment amount from the number of installments, when not typed.
    final count = _n('count').round();
    final sell = _n('sell_amount');
    final first = _n('first_installment_amount');
    if (count > 0 && sell > 0) {
      final rest = first > 0 ? count - 1 : count;
      if (rest > 0) {
        final per = ((sell - first) / rest);
        final txt = per.toStringAsFixed(per % 1 == 0 ? 0 : 2);
        if (_c['remaining_per_installment_amount']!.text != txt) _c['remaining_per_installment_amount']!.text = txt;
      }
    }
    _schedulePreview();
    setState(() {});
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _runPreview);
  }

  Future<void> _runPreview() async {
    final buy = _n('buy_amount');
    final sel = _candidates?.where((c) => c.selected).map((c) => c.m.uid).toList() ?? const [];
    if (buy <= 0 || sel.isEmpty) {
      if (mounted) setState(() => _preview = null);
      return;
    }
    setState(() => _previewBusy = true);
    try {
      final p = await widget.repo.allocationPreview(buy, sel);
      if (mounted) setState(() => _preview = p);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final buy = _n('buy_amount'), sell = _n('sell_amount');
    final sel = _candidates?.where((c) => c.selected).map((c) => c.m.uid).toList() ?? const <String>[];
    String? err;
    if (_c['customer_name']!.text.trim().isEmpty) err = 'গ্রাহকের নাম দিন।';
    if (err == null && _c['product_type']!.text.trim().isEmpty) err = 'পণ্যের নাম/ধরন দিন।';
    if (err == null && buy <= 0) err = 'কেনা দাম দিন।';
    if (err == null && sell <= buy) err = 'বিক্রয়মূল্য কেনা দামের চেয়ে বেশি হতে হবে।';
    if (err == null && sel.isEmpty) err = 'অন্তত একজন বিনিয়োগকারী বাছুন।';
    if (err == null && _preview != null && !_preview!.ok) err = _preview!.error;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('প্রজেক্ট তৈরি করবেন?'),
        content: Text(
          bn('${_c['customer_name']!.text.trim()} · ${_c['product_type']!.text.trim()}\n'
              'কেনা ${taka(buy)} · বিক্রয় ${taka(sell)} · লাভ ${taka(sell - buy)}\n'
              '${sel.length} জন বিনিয়োগকারীর ব্যালেন্স থেকে কেনা দাম কাটা হবে।'),
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('আবার দেখি')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('তৈরি করুন'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final project = <String, dynamic>{
        for (final k in _c.keys.where((k) => k != 'count')) k: _c[k]!.text.trim(),
        'buy_amount': buy,
        'sell_amount': sell,
        'first_installment_amount': _n('first_installment_amount'),
        'remaining_per_installment_amount': _n('remaining_per_installment_amount'),
        'buy_date': ymd(_buyDate),
        if (_start != null) 'installment_start': ymd(_start!),
      };
      final code = await widget.repo.createProject(project, sel);
      if (!mounted) return;
      toast(context, bn('প্রজেক্ট $code তৈরি হয়েছে'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(String k, String label, {TextInputType? type, int lines = 1, String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[k],
          keyboardType: type,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final buy = _n('buy_amount'), sell = _n('sell_amount');
    final cands = _candidates;
    final allocMap = {for (final r in _preview?.rows ?? const <AllocRow>[]) r.uid: r.amount};
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন প্রজেক্ট')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const SectionTitle('গ্রাহক'),
          _f('customer_name', 'গ্রাহকের নাম *'),
          _f('customer_mobile', 'মোবাইল', type: TextInputType.phone),
          _f('customer_nid', 'NID', type: TextInputType.number),
          _f('customer_address', 'ঠিকানা', lines: 2),
          _f('guarantor_name', 'জামিনদারের নাম'),
          _f('guarantor_mobile', 'জামিনদারের মোবাইল', type: TextInputType.phone),
          const SectionTitle('পণ্য ও দাম'),
          _f('product_type', 'পণ্য *', help: 'যেমন: ফ্রিজ, মোটরসাইকেল'),
          Row(
            children: [
              Expanded(child: _f('buy_amount', 'কেনা দাম (৳) *', type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _f('sell_amount', 'বিক্রয়মূল্য (৳) *', type: TextInputType.number)),
            ],
          ),
          if (buy > 0 && sell > buy)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'লাভ ${taka(sell - buy)} → সদস্যরা ${taka((sell - buy) * 0.9)}, সমিতি ${taka((sell - buy) * 0.1)} (কিস্তি আদায়ের সাথে সাথে)',
                style: const TextStyle(color: AppColors.credit, fontSize: 13),
              ),
            ),
          DateField(label: 'কেনার তারিখ', value: _buyDate, onChanged: (d) => setState(() => _buyDate = d)),
          const SizedBox(height: 12),
          const SectionTitle('কিস্তি'),
          Panel(
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _start ?? DateTime(now.year, now.month + 1, 10),
                firstDate: DateTime(2015),
                lastDate: DateTime(now.year + 5),
                helpText: 'প্রথম কিস্তির তারিখ',
              );
              if (d != null) setState(() => _start = d);
            },
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(_start == null ? 'প্রথম কিস্তির তারিখ (ঐচ্ছিক)' : 'কিস্তি শুরু ${dateBn(ymd(_start!))}')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _f('first_installment_amount', 'প্রথম কিস্তি (৳)', type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _f('count', 'মোট কিস্তি (সংখ্যা)', type: TextInputType.number)),
            ],
          ),
          _f('remaining_per_installment_amount', 'পরের প্রতি কিস্তি (৳)', type: TextInputType.number, help: 'মোট কিস্তির সংখ্যা দিলে নিজে হিসাব হয়।'),
          _f('note', 'নোট', lines: 2),
          const SectionTitle('কারা বিনিয়োগ করবেন'),
          const Text(
            'কেনা দাম বাছাই করা সদস্যদের বর্তমান ব্যালেন্স থেকে কাটা হয় — "কম ব্যালেন্স আগে, সমান ভাগ" নিয়মে।',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 8),
          if (cands == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.brand)))
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final c in cands)
                    CheckboxListTile(
                      value: c.selected,
                      activeColor: AppColors.brand,
                      onChanged: c.m.current <= 0
                          ? null
                          : (v) {
                              setState(() => c.selected = v == true);
                              _schedulePreview();
                            },
                      title: Text(c.m.name),
                      subtitle: Text(
                        bn('${c.m.uid} · ব্যালেন্স ${taka(c.m.current)}${c.irregular ? ' · অনিয়মিত' : ''}'),
                        style: TextStyle(color: c.irregular ? AppColors.danger : AppColors.muted, fontSize: 12.5),
                      ),
                      secondary: allocMap[c.m.uid] != null && allocMap[c.m.uid]! > 0
                          ? Text(taka(allocMap[c.m.uid]), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand))
                          : null,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (_previewBusy)
            const LinearProgressIndicator(color: AppColors.brand)
          else if (_preview != null)
            Text(
              _preview!.ok ? bn('বাছাই করা সদস্যদের মোট ব্যালেন্স ${taka(_preview!.available)} — ভাগ পাশে দেখানো হলো।') : _preview!.error,
              style: TextStyle(color: _preview!.ok ? AppColors.brand : AppColors.danger, fontSize: 13),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'তৈরি হচ্ছে…' : 'প্রজেক্ট তৈরি করুন')),
        ],
      ),
    );
  }
}
