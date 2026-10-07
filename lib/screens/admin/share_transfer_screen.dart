import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/wa_list.dart';
import 'pickers.dart';

/// শেয়ার ট্রান্সফার: a member leaves (or sells) their share in running projects.
/// Price = original share − capital already returned. The seller keeps past
/// profit; buyers earn from the next installment. Executed by the same code as
/// the web admin; needs the admin PIN.
class ShareTransferScreen extends StatelessWidget {
  const ShareTransferScreen({super.key, required this.repo});
  final AdminRepo repo;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('শেয়ার ট্রান্সফার'),
          bottom: const TabBar(
            labelColor: AppColors.brand,
            indicatorColor: AppColors.brand,
            labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [Tab(text: 'নতুন ট্রান্সফার'), Tab(text: 'আগের ট্রান্সফার')],
          ),
        ),
        body: TabBarView(children: [_NewTransfer(repo: repo), _History(repo: repo)]),
      ),
    );
  }
}

class _Buyer {
  final AdminMember m;
  final double balance;
  final TextEditingController amount = TextEditingController();
  _Buyer(this.m, this.balance);
}

class _NewTransfer extends StatefulWidget {
  const _NewTransfer({required this.repo});
  final AdminRepo repo;
  @override
  State<_NewTransfer> createState() => _NewTransferState();
}

class _NewTransferState extends State<_NewTransfer> with AutomaticKeepAliveClientMixin {
  AdminMember? _seller;
  List<SharePlanProject>? _plan;
  final _buyers = <int, List<_Buyer>>{};
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final l in _buyers.values) {
      for (final b in l) {
        b.amount.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickSeller() async {
    final m = await pickMember(context, widget.repo);
    if (m == null) return;
    setState(() {
      _seller = m;
      _plan = null;
      _buyers.clear();
      _error = null;
      _loading = true;
    });
    try {
      final plan = await widget.repo.sharePlan(m.uid);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        for (final p in plan) {
          _buyers[p.projectId] = [];
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// What a buyer can still spend after their amounts in other projects.
  double _left(String uid, double balance, {int? exceptProject}) {
    var used = 0.0;
    _buyers.forEach((pid, list) {
      if (pid == exceptProject) return;
      for (final b in list) {
        if (b.m.uid == uid) used += parseAmount(b.amount.text);
      }
    });
    return balance - used;
  }

  Future<void> _addBuyer(SharePlanProject p) async {
    final m = await pickMember(context, widget.repo);
    if (m == null || !mounted) return;
    if (m.uid == _seller?.uid) {
      toast(context, 'বিক্রেতা নিজে ক্রেতা হতে পারবেন না।');
      return;
    }
    if (_buyers[p.projectId]!.any((b) => b.m.uid == m.uid)) return;
    try {
      final bal = await widget.repo.balanceByUid(m.uid);
      if (!mounted) return;
      setState(() => _buyers[p.projectId]!.add(_Buyer(m, bal.current)));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  void _lowestFirst(SharePlanProject p) {
    final list = _buyers[p.projectId]!;
    if (list.isEmpty) {
      toast(context, 'আগে ক্রেতা যোগ করুন।');
      return;
    }
    final caps = {for (final b in list) b.m.uid: _left(b.m.uid, b.balance, exceptProject: p.projectId)};
    final out = lowestFirst(p.transferAmount, caps);
    setState(() {
      for (final b in list) {
        final v = out[b.m.uid] ?? 0;
        b.amount.text = v <= 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
      }
    });
    final total = out.values.fold<double>(0, (a, v) => a + v);
    if (total + 0.005 < p.transferAmount) toast(context, 'ক্রেতাদের ব্যালেন্সে পুরো দাম হচ্ছে না — আরও ক্রেতা যোগ করুন।');
  }

  String? _validate() {
    final plan = _plan ?? const [];
    var any = false;
    for (final p in plan) {
      final list = _buyers[p.projectId]!;
      final sum = list.fold<double>(0, (a, b) => a + parseAmount(b.amount.text));
      if (sum <= 0) continue;
      any = true;
      if ((sum - p.transferAmount).abs() > 0.009) {
        return '${p.code}: ক্রেতাদের মোট ${taka(sum)}, কিন্তু দাম ${taka(p.transferAmount)} — সমান হতে হবে।';
      }
    }
    if (!any) return 'অন্তত একটি প্রজেক্টে ক্রেতা ও টাকার অঙ্ক দিন।';
    final seen = <String>{};
    for (final list in _buyers.values) {
      for (final b in list) {
        if (!seen.add(b.m.uid)) continue;
        if (_left(b.m.uid, b.balance) < -0.009) return '${b.m.name}-এর ব্যালেন্স ${taka(b.balance)} — এর বেশি কেনা যাবে না।';
      }
    }
    return null;
  }

  Future<void> _execute() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final alloc = <int, Map<String, double>>{};
    final lines = <String>[];
    for (final p in _plan!) {
      final m = <String, double>{};
      for (final b in _buyers[p.projectId]!) {
        final v = parseAmount(b.amount.text);
        if (v > 0) {
          m[b.m.uid] = v;
          lines.add('${p.code}: ${b.m.name} ${taka(v)}');
        }
      }
      if (m.isNotEmpty) alloc[p.projectId] = m;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('শেয়ার ট্রান্সফার নিশ্চিত করুন'),
        content: Text(
          bn('বিক্রেতা: ${_seller!.name} (${_seller!.uid})\n${lines.join('\n')}\n\n'
              'বিক্রেতার আগের লাভ তাঁরই থাকবে; ক্রেতারা পরের কিস্তি থেকে লাভ পাবেন।'),
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('আবার দেখি')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('এগিয়ে যান'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pin = await askPin(context);
    if (pin == null || pin.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wa = await widget.repo.executeTransfer(_seller!.uid, alloc, pin);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 44),
          title: const Text('ট্রান্সফার সম্পন্ন'),
          content: const Text('সংশ্লিষ্ট সদস্যদের অ্যাপে নোটিফিকেশন গেছে। ভুল হলে "আগের ট্রান্সফার" থেকে ফেরত নেওয়া যাবে (পরে কোনো কিস্তি না এলে)।'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ঠিক আছে'))],
        ),
      );
      if (!mounted) return;
      if (wa.isNotEmpty) await showWaSheet(context, widget.repo.session.prefs, wa, title: 'ক্রেতা-বিক্রেতাকে WhatsApp-এ জানান');
      if (!mounted) return;
      setState(() {
        _seller = null;
        _plan = null;
        _buyers.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final plan = _plan;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        const Text(
          'দাম = মূল শেয়ার − কিস্তিতে ফেরত আসা মূলধন। বিক্রেতার আগের লাভ তাঁরই থাকে, ক্রেতা পরের কিস্তি থেকে লাভ পান। ট্রান্সফারের আগের তারিখে পরে কিস্তি দেওয়া যাবে না।',
          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.55),
        ),
        const SizedBox(height: 12),
        if (_seller == null)
          OutlinedButton.icon(onPressed: _pickSeller, icon: const Icon(Icons.person_search_rounded), label: const Text('কে শেয়ার বিক্রি করবেন?'))
        else
          PickedTile(
            leading: Avatar(text: initials(_seller!.name), size: 42),
            title: _seller!.name,
            subtitle: bn('বিক্রেতা · ${_seller!.uid}'),
            onTap: _pickSeller,
          ),
        if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.brand))),
        if (plan != null && plan.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('এই সদস্যের কোনো চলমান প্রজেক্টে বিক্রিযোগ্য শেয়ার নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ),
        if (plan != null)
          for (final p in plan) ...[
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${p.code} · ${p.customer}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))),
                      Text(taka(p.transferAmount), style: head(18, color: AppColors.brand)),
                    ],
                  ),
                  Text(
                    bn('মূল শেয়ার ${taka(p.invested)} − ফেরত ${taka(p.capitalReturned)} · প্রজেক্টে বাকি কিস্তি ${taka(p.installmentsDue)}'),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  for (final b in _buyers[p.projectId]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(bn('ব্যালেন্স ${taka(b.balance)}'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: b.amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(prefixText: '৳ ', isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'বাদ দিন',
                            onPressed: () => setState(() {
                              _buyers[p.projectId]!.remove(b);
                              b.amount.dispose();
                            }),
                            icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(onPressed: () => _addBuyer(p), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('ক্রেতা যোগ')),
                      TextButton.icon(onPressed: () => _lowestFirst(p), icon: const Icon(Icons.balance_rounded), label: const Text('কম ব্যালেন্স আগে ভাগ')),
                    ],
                  ),
                  Builder(builder: (context) {
                    final sum = _buyers[p.projectId]!.fold<double>(0, (a, b) => a + parseAmount(b.amount.text));
                    if (sum <= 0) return const SizedBox.shrink();
                    final okSum = (sum - p.transferAmount).abs() <= 0.009;
                    return Text(
                      okSum ? 'মোট ${taka(sum)} ✓' : 'মোট ${taka(sum)} — দাম ${taka(p.transferAmount)} হতে হবে',
                      style: TextStyle(color: okSum ? AppColors.brand : AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
                    );
                  }),
                ],
              ),
            ),
          ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
        ],
        if (plan != null && plan.isNotEmpty) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _execute,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(_busy ? 'হচ্ছে…' : 'ট্রান্সফার করুন'),
          ),
          const SizedBox(height: 6),
          const Text('যে প্রজেক্টে ক্রেতা দেবেন না, সেখানে বিক্রেতার শেয়ার আগের মতোই থাকবে।', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ],
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.repo});
  final AdminRepo repo;
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  final _loader = GlobalKey<LoaderState<List<TransferBatch>>>();

  Future<void> _undo(TransferBatch b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ট্রান্সফার ফেরত নেবেন?'),
        content: Text(bn('${b.name} (${b.fromUid}) · ${dateBn(b.time)}\n${b.projects.join('\n')}\n\nশেয়ার আগের মালিকের কাছে ফিরবে, ক্রেতাদের টাকা ফেরত যাবে।'),
            style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ফেরত নিন'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pin = await askPin(context);
    if (pin == null || pin.isEmpty || !mounted) return;
    try {
      await widget.repo.undoTransfer(b, pin);
      if (!mounted) return;
      toast(context, 'ট্রান্সফার ফেরত নেওয়া হয়েছে');
      _loader.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, bnError(e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<TransferBatch>>(
      key: _loader,
      load: widget.repo.transferHistory,
      builder: (context, items, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'এখানে শুধু সেই ট্রান্সফারগুলো দেখা যায় যেগুলো এখনো নিরাপদে ফেরত নেওয়া যায় — অর্থাৎ ট্রান্সফারের পরে ওই প্রজেক্টে নতুন কিস্তি আসেনি।',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.55),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('ফেরতযোগ্য কোনো ট্রান্সফার নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
          for (final b in items) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${b.name} · ${b.fromUid}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(taka(b.total), style: head(16)),
                    ],
                  ),
                  Text(bn('${dateBn(b.time)} · ${b.projects.join(', ')}'), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _undo(b),
                      icon: const Icon(Icons.undo_rounded, color: AppColors.danger),
                      label: const Text('ফেরত নিন', style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
