import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../services/whatsapp.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/wa_list.dart';
import 'pickers.dart';

/// সব এন্ট্রি: every saving, withdrawal, installment, income and expense, newest first.
/// Tap one to correct or cancel it (with the admin PIN).
class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key, required this.repo, this.initial = EntryType.saving, this.uid = ''});
  final AdminRepo repo;
  final EntryType initial;

  /// Show only this member's savings/withdrawals.
  final String uid;

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  late EntryType _type = widget.initial;
  String _search = '';
  String _month = '';
  Timer? _debounce;
  final _loader = GlobalKey<LoaderState<EntryPage>>();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() => _loader.currentState?.reload();

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: 'যে মাসের এন্ট্রি দেখবেন (যেকোনো দিন বাছুন)',
    );
    if (d == null) return;
    setState(() => _month = '${d.year}-${d.month.toString().padLeft(2, '0')}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.uid.isEmpty ? EntryType.values : const [EntryType.saving, EntryType.withdrawal];
    return Scaffold(
      appBar: AppBar(title: const Text('সব এন্ট্রি')),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in types)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(color: _type == t ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                      onSelected: (_) {
                        setState(() => _type = t);
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নাম, আইডি, প্রজেক্ট, নোট'),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _search = v.trim();
                        _reload();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _month.isEmpty
                    ? IconButton.outlined(tooltip: 'মাস বাছুন', onPressed: _pickMonth, icon: const Icon(Icons.calendar_month_rounded))
                    : InputChip(
                        label: Text(monthBn(_month)),
                        onDeleted: () {
                          setState(() => _month = '');
                          _reload();
                        },
                      ),
              ],
            ),
          ),
          Expanded(
            child: Loader<EntryPage>(
              key: _loader,
              load: () => widget.repo.entries(_type, search: _search, month: _month, uid: widget.uid),
              builder: (context, page, reload) => RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        bn('${page.total}টি এন্ট্রি · মোট ${taka(page.sum)}${page.items.length < page.total ? ' · সর্বশেষ ${page.items.length}টি দেখানো হচ্ছে' : ''}'),
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    if (page.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('কোনো এন্ট্রি নেই', style: TextStyle(color: AppColors.muted))),
                      )
                    else
                      Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < page.items.length; i++) ...[
                              if (i > 0) const Divider(height: 1, color: AppColors.line),
                              ListTile(
                                title: Text(page.items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(bn(page.items[i].subtitle), style: const TextStyle(fontSize: 12.5)),
                                trailing: Amount(
                                  page.items[i].type.outgoing ? taka(-page.items[i].amount) : taka(page.items[i].amount, sign: true),
                                  positive: !page.items[i].type.outgoing,
                                ),
                                onTap: () async {
                                  final changed = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(builder: (_) => EntryEditScreen(repo: widget.repo, entry: page.items[i])),
                                  );
                                  if (changed == true) reload();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Correct or cancel one entry. Runs the web admin's own update/delete, so profit
/// shares are recalculated exactly as on the website. Needs the admin PIN.
class EntryEditScreen extends StatefulWidget {
  const EntryEditScreen({super.key, required this.repo, required this.entry});
  final AdminRepo repo;
  final Entry entry;
  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  Entry get e => widget.entry;
  late final _amount = TextEditingController(text: e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : e.amount.toStringAsFixed(2));
  late final _note = TextEditingController(text: e.note);
  late final _details = TextEditingController(text: e.details);
  late DateTime _date = parseDate(e.date) ?? DateTime.now();
  late String _method = e.method.isEmpty ? 'cash' : e.method;
  late String _withdrawType = e.withdrawType.isEmpty ? 'current' : e.withdrawType;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _done(List<WaMessage> wa, String msg) async {
    if (!mounted) return;
    toast(context, msg);
    if (wa.isNotEmpty) {
      await showWaSheet(context, widget.repo.session.prefs, wa, title: 'সংশোধনের খবর WhatsApp-এ জানান');
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      toast(context, 'টাকার পরিমাণ দিন');
      return;
    }
    final pin = await askPin(context, reason: 'সংশোধন নিশ্চিত করতে পিন দিন।');
    if (pin == null || pin.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final wa = await widget.repo.updateEntry(e, {
        'amount': amount,
        'date': ymd(_date),
        'method': _method,
        'note': _note.text.trim(),
        if (e.type == EntryType.withdrawal) 'withdrawType': _withdrawType,
        if (e.type == EntryType.income || e.type == EntryType.expense) 'details': _details.text.trim(),
      }, pin);
      await _done(wa, 'সংশোধন হয়েছে');
    } on ApiException catch (x) {
      if (mounted) toast(context, x.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('এন্ট্রি বাতিল করবেন?'),
        content: Text(
          bn('${e.type.label} · ${e.title} · ${taka(e.amount)} · ${dateBn(e.date)}\n\n'
              '${e.type == EntryType.installment ? 'এই কিস্তির লাভ ও মূলধন ফেরত সবার হিসাব থেকে সরে যাবে এবং পরের কিস্তিগুলো নতুন করে মেলানো হবে। ' : ''}এটা ফেরানো যাবে না।'),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(c, true), child: const Text('বাতিল করুন')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pin = await askPin(context, reason: 'বাতিল নিশ্চিত করতে পিন দিন।');
    if (pin == null || pin.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final wa = await widget.repo.deleteEntry(e, pin);
      await _done(wa, 'এন্ট্রি বাতিল হয়েছে');
    } on ApiException catch (x) {
      if (mounted) toast(context, x.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${e.type.label} সংশোধন')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: head(17)),
                const SizedBox(height: 2),
                Text(bn('${e.subtitle} · এন্ট্রি #${e.id}'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 6),
                Text('আগের অঙ্ক: ${taka(e.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'টাকার পরিমাণ', prefixText: '৳ '),
            style: head(20),
          ),
          const SizedBox(height: 12),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 12),
          if (e.type == EntryType.withdrawal) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'current', label: Text('সঞ্চয়')),
                ButtonSegment(value: 'profits', label: Text('লভ্যাংশ')),
                ButtonSegment(value: 'total', label: Text('মোট')),
              ],
              selected: {_withdrawType},
              onSelectionChanged: (v) => setState(() => _withdrawType = v.first),
            ),
            const SizedBox(height: 12),
          ],
          if (e.type == EntryType.income || e.type == EntryType.expense) ...[
            TextField(controller: _details, decoration: const InputDecoration(labelText: 'বিবরণ')),
            const SizedBox(height: 12),
          ],
          const Text('মাধ্যম', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          MethodChips(value: _method, onChanged: (m) => setState(() => _method = m)),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
          const SizedBox(height: 16),
          Panel(
            color: AppColors.brandSoft,
            child: Text(
              e.type == EntryType.installment
                  ? 'কিস্তি বদলালে ওয়েবসাইটের একই নিয়মে সব বিনিয়োগকারীর লাভ ও মূলধন ফেরত নতুন করে হিসাব হবে। সংরক্ষণের জন্য অ্যাডমিন পিন লাগবে।'
                  : 'সংরক্ষণের জন্য অ্যাডমিন পিন লাগবে। এরপর সদস্যকে WhatsApp-এ সংশোধনের খবর পাঠাতে পারবেন।',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'অপেক্ষা করুন…' : 'সংশোধন সংরক্ষণ')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('এন্ট্রি বাতিল করুন'),
          ),
        ],
      ),
    );
  }
}
