import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_nav.dart';
import '../../widgets/member_widgets.dart';

class _SavingsData {
  final List<StatementRow> rows;
  final Arrears arrears;
  const _SavingsData(this.rows, this.arrears);
}

/// সঞ্চয়: next saving due, month-by-month status and deposit history.
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key, required this.repo, required this.goTab});
  final MemberRepo repo;
  final void Function(int tab) goTab;

  Future<_SavingsData> _load() async {
    final r = await Future.wait([repo.statement(), repo.arrears()]);
    return _SavingsData(r[0] as List<StatementRow>, r[1] as Arrears);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = SessionScope.of(context).config;
    return Scaffold(
      appBar: AppBar(leading: shellBack(context), title: const Text('সঞ্চয়')),
      body: Loader<_SavingsData>(
        load: _load,
        builder: (context, d, _) {
          final savings = d.rows.where((r) => r.type == 'saving').toList().reversed.toList();
          final total = savings.fold<double>(0, (a, r) => a + r.credit);
          final year = DateTime.now().year;
          final thisYear = savings.where((r) => parseDate(r.date)?.year == year).fold<double>(0, (a, r) => a + r.credit);
          final withdrawn = d.rows.where((r) => r.type == 'withdrawal' && r.withdrawType != 'profits').fold<double>(0, (a, r) => a + r.debit);
          final a = d.arrears;
          final now = DateTime.now();
          final dueDay = cfg?.dueDay ?? 10;
          final nextMonth = now.day > dueDay ? DateTime(now.year, now.month + 1) : DateTime(now.year, now.month);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (a.configured)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn('পরের সঞ্চয় · $dueDay ${monthsFull[nextMonth.month - 1]}-এর মধ্যে'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(taka(a.monthlyAmount + a.amountDue), style: head(32, color: Colors.white)),
                      if (a.amountDue > 0)
                        Text(
                          'মাসিক ${taka(a.monthlyAmount)} + বকেয়া ${taka(a.amountDue)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'টাকা জমা দেওয়ার পর অ্যাডমিন এন্ট্রি দিলেই সঞ্চয়ে যোগ হবে আর রসিদ পাবেন।',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              if (a.configured && a.months.isNotEmpty) ...[
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('শেষ ৬ মাস', style: head(15, weight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final m in a.months)
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    height: 10,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: m.paid ? AppColors.brand : (m.due ? AppColors.danger : AppColors.line),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    monthsShort[(int.tryParse(m.month.split('-').last) ?? 1) - 1],
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 14,
                        children: [
                          _Legend(color: AppColors.brand, text: 'জমা'),
                          _Legend(color: AppColors.danger, text: 'বকেয়া'),
                          _Legend(color: AppColors.line, text: 'সময় আছে'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'মোট জমা সঞ্চয়', value: taka(total), sub: bn('${savings.length}টি জমা'))),
                  const SizedBox(width: 12),
                  Expanded(child: StatTile(label: bn('$year সালে'), value: taka(thisYear))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'সঞ্চয় থেকে উত্তোলন', value: taka(withdrawn))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'বকেয়া',
                      value: a.configured ? (a.monthsDue > 0 ? bn('${a.monthsDue} মাস') : 'নেই') : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SectionTitle('জমার ইতিহাস', action: 'সব লেনদেন', onAction: () => goTab(3)),
              Panel(
                padding: EdgeInsets.zero,
                child: savings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('এখনো কোনো সঞ্চয় জমা নেই।', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < savings.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 66, color: AppColors.line),
                            LedgerTile(row: savings[i]),
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      );
}
