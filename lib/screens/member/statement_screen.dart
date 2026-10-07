import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_nav.dart';
import '../../widgets/statement_export.dart';
import '../../widgets/member_widgets.dart';
import 'receipts_screen.dart';

enum LedgerFilter { all, saving, profit, withdrawal, investment }

extension on LedgerFilter {
  String get label => switch (this) {
        LedgerFilter.all => 'সব',
        LedgerFilter.saving => 'সঞ্চয়',
        LedgerFilter.profit => 'লাভ ও ফেরত',
        LedgerFilter.withdrawal => 'উত্তোলন',
        LedgerFilter.investment => 'বিনিয়োগ',
      };

  bool keeps(StatementRow r) => switch (this) {
        LedgerFilter.all => true,
        LedgerFilter.saving => r.type == 'saving',
        LedgerFilter.profit => r.type == 'distribution' || r.type == 'share_sale',
        LedgerFilter.withdrawal => r.type == 'withdrawal' || r.type == 'penalty',
        LedgerFilter.investment => r.type == 'investment',
      };
}

/// "লেনদেন": the whole ledger with filters, a date range and running balance.
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key, required this.repo});
  final MemberRepo repo;
  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  LedgerFilter _filter = LedgerFilter.all;
  DateTimeRange? _range;
  final _loader = GlobalKey<LoaderState<_Data>>();

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<_Data> _load() async {
    final rows = await widget.repo.statement(
      from: _range == null ? null : _ymd(_range!.start),
      to: _range == null ? null : _ymd(_range!.end),
    );
    List<Receipt> receipts = const [];
    try {
      receipts = await widget.repo.receipts();
    } catch (_) {}
    return _Data(rows, receipts);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'সময়সীমা বাছুন',
      saveText: 'ঠিক আছে',
    );
    if (r == null) return;
    setState(() => _range = r);
    _loader.currentState?.reload();
  }

  void _clearRange() {
    setState(() => _range = null);
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final offline = SessionScope.of(context).offline;
    return Scaffold(
      appBar: AppBar(
        leading: shellBack(context),
        title: const Text('লেনদেন'),
        actions: [
          IconButton(
            tooltip: 'স্টেটমেন্ট PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () {
              final s = SessionScope.read(context);
              showMemberStatementSheet(
                context,
                session: s,
                build: (from, to) => StatementRequest.mine(s.user?.memberId ?? 'me', from, to),
              );
            },
          ),
          IconButton(
            tooltip: 'রসিদ',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptsScreen(repo: widget.repo))),
          ),
        ],
      ),
      body: Column(
        children: [
          if (offline) const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), alignment: Alignment.centerLeft),
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 20),
                    label: Text(
                      _range == null ? 'শুরু থেকে আজ পর্যন্ত' : '${dateBn(_ymd(_range!.start))} – ${dateBn(_ymd(_range!.end))}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_range != null)
                  IconButton(tooltip: 'সময়সীমা মুছুন', onPressed: _clearRange, icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in LedgerFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: _filter == f ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      showCheckmark: false,
                      side: const BorderSide(color: AppColors.line),
                      backgroundColor: AppColors.card,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Loader<_Data>(
              key: _loader,
              load: _load,
              builder: (context, d, _) => _List(data: d, filter: _filter),
            ),
          ),
        ],
      ),
    );
  }
}

class _Data {
  final List<StatementRow> rows;
  final List<Receipt> receipts;
  const _Data(this.rows, this.receipts);
}

class _List extends StatelessWidget {
  const _List({required this.data, required this.filter});
  final _Data data;
  final LedgerFilter filter;

  Receipt? _receiptFor(StatementRow r) {
    final type = switch (r.type) {
      'saving' => 'saving',
      'withdrawal' => 'withdrawal',
      _ => '',
    };
    if (type.isEmpty) return null;
    for (final x in data.receipts) {
      if (x.type == type && x.refId == r.ref) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final opening = data.rows.where((r) => r.isOpening).toList();
    final movement = data.rows.where((r) => !r.isOpening).toList();
    final shown = movement.where(filter.keeps).toList().reversed.toList();
    final t = LedgerTotals.of(movement);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _Sum(label: 'সঞ্চয় জমা', value: taka(t.saved, sign: true), positive: true)),
                  Expanded(child: _Sum(label: 'লাভ আয়', value: taka(t.profit, sign: true), positive: true)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Sum(label: 'মূলধন ফেরত', value: taka(t.capitalBack, sign: true), positive: true)),
                  Expanded(child: _Sum(label: 'উত্তোলন', value: taka(-t.withdrawn), positive: false)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Sum(label: 'প্রজেক্টে বিনিয়োগ', value: taka(-t.invested), positive: false)),
                  Expanded(child: _Sum(label: 'নিট পরিবর্তন', value: taka(t.net, sign: true), positive: t.net >= 0)),
                ],
              ),
              if (t.penalty > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _Sum(label: 'সঞ্চয় জরিমানা (লভ্যাংশ থেকে)', value: taka(-t.penalty), positive: false)),
                  ],
                ),
              ],
              if (data.rows.isNotEmpty) ...[
                const Divider(height: 24, color: AppColors.line),
                Row(
                  children: [
                    const Expanded(child: Text('শেষ ব্যালেন্স', style: TextStyle(color: AppColors.muted))),
                    Text(taka(data.rows.last.balance), style: head(18)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: shown.isEmpty && opening.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('এই সময়ে কোনো লেনদেন নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 66, color: AppColors.line),
                      Builder(builder: (context) {
                        final rc = _receiptFor(shown[i]);
                        return LedgerTile(
                          row: shown[i],
                          showBalance: filter == LedgerFilter.all,
                          onTap: rc == null ? null : () => openReceipt(context, rc),
                        );
                      }),
                    ],
                    if (opening.isNotEmpty && filter == LedgerFilter.all) ...[
                      const Divider(height: 1, color: AppColors.line),
                      LedgerTile(row: opening.first),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 10),
        const Text(
          'রসিদ আছে এমন লাইনে চাপ দিলে রসিদ খুলবে। শেষ ব্যালেন্স = বর্তমান ব্যালেন্স + উত্তোলনযোগ্য লাভ।',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum({required this.label, required this.value, required this.positive});
  final String label, value;
  final bool positive;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Amount(value, positive: positive, size: 16)),
        ],
      );
}
