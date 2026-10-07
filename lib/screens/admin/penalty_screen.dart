import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/wa_list.dart';
import 'pickers.dart';

/// সঞ্চয় জরিমানা: switch it on/off, set the rate and base, see and waive charges.
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

class _PenaltyBody extends StatefulWidget {
  const _PenaltyBody({required this.repo, required this.book, required this.reload});
  final AdminRepo repo;
  final PenaltyBook book;
  final Future<void> Function() reload;
  @override
  State<_PenaltyBody> createState() => _PenaltyBodyState();
}

class _PenaltyBodyState extends State<_PenaltyBody> {
  late final _rate = TextEditingController(text: rateText(widget.book.rate));
  late String _base = widget.book.base;
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double get _rateValue => parseAmount(_rate.text).clamp(0, 100).toDouble();

  String get _rule =>
      'কোনো মাসে পুরো মাসের মধ্যে সঞ্চয় জমা না হলে পরের মাসের ১ তারিখে ${penaltyBaseOf(_base)} ${bn(rateText(_rateValue))}% জরিমানা হয়। '
      'টাকাটা সদস্যের লভ্যাংশ থেকে কেটে প্রশাসনিক তহবিলে যায়। লভ্যাংশ কম থাকলে যতটুকু আছে ততটুকু, না থাকলে কিছুই কাটে না। '
      'সঞ্চয় থেকে কখনো কাটে না। অগ্রিম সঞ্চয় দেওয়া থাকলে জরিমানা নেই।';

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body, style: const TextStyle(height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
          ],
        ),
      ) ==
      true;

  Future<void> _save({required bool enabled}) async {
    final b = widget.book;
    if (enabled && !b.enabled && !await _confirm('জরিমানা চালু করবেন?', 'এই মাস থেকে কার্যকর হবে।\n\n$_rule\n\nচালু করলেই সব সক্রিয় সদস্য নোটিফিকেশন পাবেন।', 'চালু করুন')) return;
    if (!enabled && b.enabled && !await _confirm('জরিমানা বন্ধ করবেন?', 'আগে কাটা জরিমানা যেমন আছে তেমনই থাকবে, হিসাবে কোনো গরমিল হবে না। বন্ধ থাকা মাসগুলোর জন্য পরে আর জরিমানা হবে না।', 'বন্ধ করুন')) return;
    setState(() => _busy = true);
    try {
      await widget.repo.savePenaltySettings(enabled: enabled, rate: _rateValue, base: _base);
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
      final wa = await widget.repo.waivePenalty(p.id, text);
      if (!mounted) return;
      toast(context, 'মওকুফ হয়েছে');
      await widget.reload();
      if (mounted && wa.isNotEmpty) await showWaSheet(context, widget.repo.session.prefs, wa, title: 'সদস্যকে জানান');
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
                Text(_rule, style: const TextStyle(fontSize: 13, height: 1.55)),
                const SizedBox(height: 12),
                const Text('জরিমানা কিসের উপর', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', label: Text('মাসিক কিস্তি')),
                    ButtonSegment(value: 'savings', label: Text('মোট সঞ্চয়')),
                  ],
                  selected: {_base},
                  onSelectionChanged: (v) => setState(() => _base = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'জরিমানার হার (%)', helperText: 'নতুন হার শুধু পরের মাসগুলোতে খাটে; আগের জরিমানা বদলায় না'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(onPressed: _busy ? null : () => _save(enabled: b.enabled), child: const Text('হার ও ভিত্তি সংরক্ষণ')),
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
          if (b.history.isNotEmpty) ...[
            const SectionTitle('চালু/বন্ধের ইতিহাস'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final h in b.history.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(h.on ? Icons.toggle_on_rounded : Icons.toggle_off_rounded, color: h.on ? AppColors.brand : AppColors.muted),
                          const SizedBox(width: 8),
                          Expanded(child: Text(h.on ? 'চালু${h.rate > 0 ? bn(' · ${rateText(h.rate)}%') : ''}' : 'বন্ধ')),
                          Text(bn('${dateBn(h.at)}${h.by.isEmpty ? '' : ' · ${h.by}'}'), style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
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
                        bn('${p.uid} · ${p.basis}') + (p.full > p.amount + 0.004 ? '\nলভ্যাংশে যতটুকু ছিল ততটুকু কাটা হয়েছে' : '') + (p.waived ? '\nমওকুফ${p.note.isEmpty ? '' : ' · ${p.note}'}' : ''),
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
