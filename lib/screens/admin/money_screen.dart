import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'pickers.dart';

/// অন্যান্য আয় ও ব্যয়. Income splits 80% administration / 20% welfare;
/// an expense comes out of the fund it is booked to.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key, required this.repo});
  final AdminRepo repo;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('অন্যান্য আয়-ব্যয়'),
          bottom: const TabBar(
            labelColor: AppColors.brand,
            indicatorColor: AppColors.brand,
            labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [Tab(text: 'আয়'), Tab(text: 'ব্যয়')],
          ),
        ),
        body: TabBarView(children: [_MoneyList(repo: repo, income: true), _MoneyList(repo: repo, income: false)]),
      ),
    );
  }
}

const _incomeSources = {'members': 'সদস্যদের কাছ থেকে', 'customers': 'গ্রাহকদের কাছ থেকে'};
const _expenseSources = {'administration': 'প্রশাসনিক তহবিল থেকে', 'member_welfare': 'সদস্য কল্যাণ তহবিল থেকে'};

class _MoneyList extends StatefulWidget {
  const _MoneyList({required this.repo, required this.income});
  final AdminRepo repo;
  final bool income;
  @override
  State<_MoneyList> createState() => _MoneyListState();
}

class _MoneyListState extends State<_MoneyList> with AutomaticKeepAliveClientMixin {
  final _loader = GlobalKey<LoaderState<List<MoneyRow>>>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _add() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.bg,
      builder: (_) => _AddMoney(repo: widget.repo, income: widget.income),
    );
    if (ok == true) _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sources = widget.income ? _incomeSources : _expenseSources;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: widget.income ? 'add-income' : 'add-expense',
        backgroundColor: widget.income ? AppColors.brand : AppColors.danger,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.income ? 'আয় যোগ' : 'ব্যয় যোগ'),
      ),
      body: Loader<List<MoneyRow>>(
        key: _loader,
        load: () => widget.repo.moneyRows(income: widget.income),
        builder: (context, items, _) {
          final total = items.fold<double>(0, (a, r) => a + r.amount);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.income ? 'তালিকার মোট আয় (৮০% প্রশাসন, ২০% কল্যাণ)' : 'তালিকার মোট ব্যয়',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Text(taka(total), style: head(18, color: widget.income ? AppColors.brand : AppColors.danger)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('কিছু নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
              for (final r in items) ...[
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.details.isEmpty ? (sources[r.source] ?? r.source) : r.details, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              [dateBn(r.date), sources[r.source] ?? r.source, methodBn(r.method)].where((x) => x.isNotEmpty).join(' · '),
                              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                            ),
                            if (r.note.isNotEmpty) Text(r.note, style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Amount(widget.income ? taka(r.amount, sign: true) : taka(-r.amount), positive: widget.income),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddMoney extends StatefulWidget {
  const _AddMoney({required this.repo, required this.income});
  final AdminRepo repo;
  final bool income;
  @override
  State<_AddMoney> createState() => _AddMoneyState();
}

class _AddMoneyState extends State<_AddMoney> {
  final _details = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _source = widget.income ? 'members' : 'administration';
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'টাকার অঙ্ক দিন।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.addMoney(
        income: widget.income,
        source: _source,
        details: _details.text.trim(),
        date: ymd(_date),
        amount: amount,
        method: _method,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.income ? _incomeSources : _expenseSources;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.income ? 'অন্যান্য আয় যোগ' : 'ব্যয় যোগ', style: head(20)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in sources.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _source == e.key,
                    showCheckmark: false,
                    selectedColor: AppColors.brand,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(color: _source == e.key ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _source = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _details, decoration: InputDecoration(labelText: widget.income ? 'কিসের আয় (যেমন: ভর্তি ফি)' : 'কিসের খরচ (যেমন: খাতা-কলম)')),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: head(22),
              decoration: const InputDecoration(labelText: 'টাকার অঙ্ক', prefixText: '৳ '),
            ),
            const SizedBox(height: 10),
            DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 10),
            MethodChips(value: _method, onChanged: (m) => setState(() => _method = m)),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন')),
          ],
        ),
      ),
    );
  }
}
