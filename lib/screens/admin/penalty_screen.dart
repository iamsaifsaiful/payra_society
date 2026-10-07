import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'pickers.dart';

/// সঞ্চয় জরিমানা: switch it on/off, set the rate, see and waive charges.
class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({super.key, required this.repo});
  final AdminRepo repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সঞ্চয় জরিমানা')),
      body: Loader<PenaltyBook>(
        load: repo.penalties,
        builder: (context, book, reload) => _PenaltyBody(repo: repo, book: book, reload: reload),
      ),
    );
  }
}

String rateText(double r) => bn(r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), ''));

class _PenaltyBody extends StatefulWidget {
  const _PenaltyBody({required this.repo, required this.book, required this.reload});
  final AdminRepo repo;
  final PenaltyBook book;
  final Future<void> Function() reload;
  @override
  State<_PenaltyBody> createState() => _PenaltyBodyState();
}

class _PenaltyBodyState extends State<_PenaltyBody> {
  late final _rate = TextEditingController(text: widget.book.rate.toStringAsFixed(widget.book.rate == widget.book.rate.roundToDouble() ? 0 : 2));
  late bool _skipAdvance = widget.book.skipAdvance;
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double get _rateValue => parseAmount(_rate.text).clamp(0, 100).toDouble();

  Future<void> _save({required bool enabled}) async {
    final b = widget.book;
    if (enabled && !b.enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('জরিমানা চালু করবেন?'),
          content: Text(
            'এই মাস থেকে কার্যকর হবে। যে সদস্য পুরো মাসে সঞ্চয় দেবেন না, মাস শেষে তাঁর লভ্যাংশ থেকে ${rateText(_rateValue)}% কেটে প্রশাসনিক তহবিলে যাবে। লভ্যাংশ না থাকলে কিছু কাটবে না, সঞ্চয় থেকে কখনো না।\n\nচালু করলেই সব সক্রিয় সদস্য নোটিফিকেশন পাবেন।',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('চালু করুন')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!enabled && b.enabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('জরিমানা বন্ধ করবেন?'),
          content: const Text('আগে কাটা জরিমানা থেকে যাবে। বন্ধ থাকা মাসগুলোর জন্য পরে আর জরিমানা হবে না।', style: TextStyle(height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('বন্ধ করুন')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.savePenaltySettings(enabled: enabled, rate: _rateValue, skipAdvance: _skipAdvance);
      if (mounted) toast(context, enabled && !b.enabled ? 'চালু হয়েছে — সদস্যদের জানানো হয়েছে' : 'সংরক্ষণ হয়েছে');
      await widget.reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Penalty p) async {
    if (p.waived) {
      try {
        await widget.repo.restorePenalty(p.id);
        if (mounted) toast(context, 'জরিমানা আবার চালু হয়েছে');
        await widget.reload();
      } on ApiException catch (e) {
        if (mounted) toast(context, e.message);
      }
      return;
    }
    final text = await showDialog<String>(context: context, builder: (_) => _WaiveDialog(p: p));
    if (text == null) return;
    try {
      await widget.repo.waivePenalty(p.id, text);
      if (mounted) toast(context, 'মওকুফ হয়েছে');
      await widget.reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final byMonth = <String, List<Penalty>>{};
    for (final p in b.items) {
      byMonth.putIfAbsent(p.month, () => []).add(p);
    }
    return RefreshIndicator(
      onRefresh: widget.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            color: b.enabled ? AppColors.brandSoft : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.enabled ? 'জরিমানা চালু আছে' : 'জরিমানা বন্ধ আছে', style: head(16, weight: FontWeight.w600)),
                  subtitle: Text(
                    b.enabled ? bn('${monthBn(b.since)} থেকে কার্যকর · পরের হিসাব ${dateBn(b.nextRun)}') : 'চালু করলে এই মাস থেকে কার্যকর হবে',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: b.enabled,
                  activeTrackColor: AppColors.brand,
                  onChanged: _busy ? null : (v) => _save(enabled: v),
                ),
                const SizedBox(height: 6),
                Text(
                  'নিয়ম: কোনো মাসে পুরো মাসের মধ্যে সঞ্চয় জমা না হলে পরের মাসের ১ তারিখে লভ্যাংশের ${rateText(_rateValue)}% কেটে প্রশাসনিক তহবিলে যোগ হয়। লভ্যাংশ না থাকলে কিছু কাটে না। সঞ্চয় থেকে কখনো কাটে না। যোগদানের মাস শেষ তারিখের পরে হলে সেই মাস ধরা হয় না।',
                  style: const TextStyle(fontSize: 13, height: 1.55),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'জরিমানার হার (%)', helperText: 'লভ্যাংশের কত শতাংশ কাটা হবে'),
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('অগ্রিম সঞ্চয় দেওয়া থাকলে জরিমানা নয়'),
                  subtitle: const Text('যোগদান থেকে ওই মাস পর্যন্ত সব কিস্তি জমা থাকলে সেই মাসে না দিলেও কাটবে না', style: TextStyle(fontSize: 12.5)),
                  value: _skipAdvance,
                  activeTrackColor: AppColors.brand,
                  onChanged: (v) => setState(() => _skipAdvance = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(onPressed: _busy ? null : () => _save(enabled: b.enabled), child: const Text('হার ও নিয়ম সংরক্ষণ')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat(label: 'মোট জরিমানা (প্রশাসনে)', value: taka(b.totalAll))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'মওকুফ', value: taka(b.waived))),
            ],
          ),
          if (b.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('এখনো কোনো জরিমানা হয়নি', style: TextStyle(color: AppColors.muted))),
            ),
          for (final e in byMonth.entries) ...[
            SectionTitle(bn('${monthBn(e.key)} · ${e.value.where((p) => !p.waived).length} জন')),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final p in e.value)
                    ListTile(
                      title: Text(p.name.isEmpty ? p.uid : p.name, style: TextStyle(decoration: p.waived ? TextDecoration.lineThrough : null)),
                      subtitle: Text(
                        bn('${p.uid} · লভ্যাংশ ${taka(p.base)}-এর ${rateText(p.rate)}%') + (p.waived ? '\nমওকুফ${p.note.isEmpty ? '' : ' · ${p.note}'}' : ''),
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Amount(taka(-p.amount), positive: false),
                          PopupMenuButton<String>(
                            onSelected: (_) => _toggle(p),
                            itemBuilder: (_) => [PopupMenuItem(value: 'x', child: Text(p.waived ? 'আবার চালু করুন' : 'মওকুফ করুন'))],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(value, style: head(17)),
          ],
        ),
      );
}

/// Owns its text controller, so it lives exactly as long as the dialog.
class _WaiveDialog extends StatefulWidget {
  const _WaiveDialog({required this.p});
  final Penalty p;
  @override
  State<_WaiveDialog> createState() => _WaiveDialogState();
}

class _WaiveDialogState extends State<_WaiveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return AlertDialog(
      title: const Text('জরিমানা মওকুফ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bn('${p.name} · ${monthBn(p.month)} · ${taka(p.amount)}'), style: const TextStyle(height: 1.5)),
          const SizedBox(height: 4),
          const Text('টাকা সদস্যের লভ্যাংশে ফেরত যাবে, সদস্য নোটিফিকেশন পাবেন।', style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'কারণ (ঐচ্ছিক)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
        FilledButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('মওকুফ করুন')),
      ],
    );
  }
}
